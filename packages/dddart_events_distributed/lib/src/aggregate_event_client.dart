import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/aggregate_event_repository.dart';
import 'package:dddart_events_distributed/src/aggregate_event_service.dart';
import 'package:dddart_events_distributed/src/aggregate_event_transport.dart';
import 'package:dddart_events_distributed/src/aggregate_reference.dart';
import 'package:dddart_events_distributed/src/event_registry.dart';
import 'package:dddart_events_distributed/src/retrying_event_publisher.dart';

/// One reference-counted interest, with stable streams across channel rotation.
class AggregateEventWatch {
  AggregateEventWatch._(this._client, this._state) {
    _state.leases.add(this);
  }
  final AggregateEventClient _client;
  final _WatchState _state;
  final _events = StreamController<DomainEvent<Identity>>.broadcast();
  final _signals = StreamController<EventWatchStatus>.broadcast();
  bool _closed = false;

  /// Events from this logical aggregate only, including retained recovery.
  Stream<DomainEvent<Identity>> get events => _events.stream;

  /// Access revocation, explicit resync requirements and lifecycle transitions.
  Stream<EventWatchStatus> get signals => _signals.stream;

  /// Current state also covers a lease added to an already established watch.
  EventWatchStatus get status =>
      _closed ? EventWatchStatus.closed : _state.status;

  /// Completes after initial resolution/recovery, including an explicit denial.
  Future<void> get ready => _state.ready.future;

  /// Save this opaque token to resume this particular logical aggregate later.
  String? get checkpoint => _state.checkpoint;

  /// Releases this lease; other leases/watches continue independently.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _state.leases.remove(this);
    await _client._release(_state);
    await _events.close();
    await _signals.close();
  }
}

/// Shared polling/live SDK with bounded overlap deduplication and batched reads.
class AggregateEventClient {
  /// AppSync transports use a slower reconciliation interval, HTTP uses polling.
  AggregateEventClient({
    required this.transport,
    required this.registry,
    required String Function(DomainEvent<Identity>) aggregateKind,
    Duration? interval,
    this.maxWatches = 100,
    this.maxSeenPerWatch = 4096,
    this.maxPagesPerSync = 10,
    this.localEventBus,
    EventRetryPolicy? retryPolicy,
    Logger? logger,
  })  : interval = interval ??
            (transport is LiveAggregateEventTransport
                ? const Duration(minutes: 1)
                : const Duration(seconds: 5)),
        logger = logger ?? Logger('dddart.events.watches') {
    if (this.interval <= Duration.zero ||
        maxWatches < 1 ||
        maxSeenPerWatch < 1 ||
        maxPagesPerSync < 1) {
      throw ArgumentError('Invalid watch limits');
    }
    publisher = EnvelopeEventPublisher(
      registry: registry,
      aggregateKind: aggregateKind,
      send: transport.publish,
      policy: retryPolicy,
      logger: this.logger,
    );
  }

  /// HTTP or live transport, owned by this client for lifecycle cleanup.
  final AggregateEventTransport transport;

  /// Explicit event/identity codecs.
  final EventRegistry registry;

  /// One timer for the complete active watch set; also reconciles missed hints.
  final Duration interval;

  /// Bounded aggregate interest count.
  final int maxWatches;

  /// Bounded deduplication window; duplicate delivery remains generally possible.
  final int maxSeenPerWatch;

  /// Prevents an unbounded recovery loop in one synchronization operation.
  final int maxPagesPerSync;

  /// Optional application bus receiving deliveries without echo.
  final EventBus? localEventBus;

  /// Named SDK logger.
  final Logger logger;

  /// Same repository publisher API for clients and servers.
  late final EventPublisher publisher;
  final Map<String, _WatchState> _watches = {};
  Timer? _timer;
  Future<void>? _syncing;
  bool _again = false;
  bool _paused = false;
  bool _closed = false;
  int _generation = 0;

  /// Starts an explicit logical watch, sharing transport work with other leases.
  AggregateEventWatch watch(
    AggregateReference<Identity> aggregate, {
    String? checkpoint,
  }) {
    if (_closed) throw StateError('Event client closed');
    final key = aggregate.toKey(registry.identityCodecs);
    var state = _watches[key];
    if (state == null) {
      if (_watches.length >= maxWatches) {
        throw StateError('Watch limit exceeded');
      }
      state = _WatchState(aggregate, checkpoint);
      _watches[key] = state;
    } else if (checkpoint != null && checkpoint != state.checkpoint) {
      throw ArgumentError('Conflicting checkpoint for an existing watch');
    }
    final lease = AggregateEventWatch._(this, state);
    _startTimer();
    unawaited(synchronize());
    return lease;
  }

  void _startTimer() {
    if (!_closed && !_paused && _watches.isNotEmpty) {
      _timer ??= Timer.periodic(interval, (_) => unawaited(synchronize()));
    }
  }

  bool _current(_WatchState state, int generation) =>
      !_closed &&
      !_paused &&
      _generation == generation &&
      state.leases.isNotEmpty &&
      _watches[state.aggregate.toKey(registry.identityCodecs)] == state;

  void _status(_WatchState state, EventWatchStatus status) {
    state.status = status;
    for (final lease in state.leases) {
      if (!lease._closed) lease._signals.add(status);
    }
    if ((status == EventWatchStatus.revoked ||
            status == EventWatchStatus.resyncRequired) &&
        !state.ready.isCompleted) {
      state.ready.complete();
    }
  }

  /// Performs one single-flight batched resolve/catch-up operation.
  Future<void> synchronize() {
    if (_closed || _paused) return Future.value();
    final current = _syncing;
    if (current != null) {
      _again = true;
      return current;
    }
    final completer = Completer<void>();
    _syncing = completer.future;
    unawaited(() async {
      try {
        do {
          _again = false;
          await _synchronize(_generation);
        } while (_again && !_closed && !_paused);
      } catch (error, stack) {
        for (final state in _watches.values.toList()) {
          if (_current(state, _generation) &&
              state.status != EventWatchStatus.revoked &&
              state.status != EventWatchStatus.resyncRequired) {
            _status(state, EventWatchStatus.connecting);
          }
        }
        logger.warning(
          'Watch synchronization failed; retrying on next interval',
          error,
          stack,
        );
      } finally {
        _syncing = null;
        completer.complete();
      }
    }());
    return completer.future;
  }

  Future<void> _synchronize(int generation) async {
    final states = _watches.values
        .where(
          (state) =>
              state.leases.isNotEmpty &&
              state.status != EventWatchStatus.revoked &&
              state.status != EventWatchStatus.resyncRequired,
        )
        .toList();
    if (states.isEmpty) return;
    final results = await transport.resolve(
      states
          .map(
            (state) => EventWatchRequest(
              state.aggregate,
              checkpoint: state.checkpoint,
            ),
          )
          .toList(),
    );
    final byKey = {
      for (final state in states)
        state.aggregate.toKey(registry.identityCodecs): state,
    };
    for (final result in results) {
      final state = byKey[result.aggregate.toKey(registry.identityCodecs)];
      if (state == null || !_current(state, generation)) continue;
      if (result.status != EventWatchStatus.active) {
        await _stop(state, result.status);
        continue;
      }
      final channel = result.channel;
      if (channel == null || result.checkpoint == null) {
        throw const FormatException('Incomplete watch resolution');
      }
      state.checkpoint ??= result.checkpoint;
      if (transport is LiveAggregateEventTransport &&
          (state.subscription == null || state.channel?.id != channel.id)) {
        await state.subscription?.cancel();
        state.subscription = null;
        if (!_current(state, generation)) continue;
        state.channel = channel;
        final subscription =
            await (transport as LiveAggregateEventTransport).subscribe(
          channel,
          onEvent: (record) {
            if (_current(state, generation)) _deliver(state, record);
          },
          onRefresh: () {
            if (_current(state, generation)) unawaited(synchronize());
          },
          onDisconnect: () {
            if (_current(state, generation)) {
              state.subscription = null;
              _status(state, EventWatchStatus.connecting);
              unawaited(synchronize());
            }
          },
        );
        if (!_current(state, generation)) {
          await subscription.cancel();
          continue;
        }
        state.subscription = subscription;
      }
      if (_current(state, generation)) _status(state, EventWatchStatus.active);
    }
    // Subscribe before recovery: events between head resolution and join are
    // recovered; live/history overlap is deduplicated without assuming ordering.
    var pending = states
        .where(
          (state) =>
              _current(state, generation) &&
              state.status == EventWatchStatus.active,
        )
        .toList();
    for (var page = 0; pending.isNotEmpty && page < maxPagesPerSync; page++) {
      final batch = await transport.read(
        pending
            .map(
              (state) => EventWatchRequest(
                state.aggregate,
                checkpoint: state.checkpoint,
              ),
            )
            .toList(),
      );
      final more = <_WatchState>[];
      for (final result in batch) {
        final state = byKey[result.aggregate.toKey(registry.identityCodecs)];
        if (state == null || !_current(state, generation)) continue;
        if (result.status != EventWatchStatus.active) {
          await _stop(state, result.status);
          continue;
        }
        for (final event in result.events) {
          _deliver(state, event);
        }
        if (result.checkpoint == null) {
          throw const FormatException('Missing history checkpoint');
        }
        state.checkpoint = result.checkpoint;
        if (result.hasMore) {
          if (result.events.isEmpty) {
            more.insert(0, state);
          } else {
            more.add(state);
          }
        }
      }
      pending = more;
    }
    for (final state in states) {
      if (_current(state, generation) &&
          state.status == EventWatchStatus.active &&
          !state.ready.isCompleted) {
        state.ready.complete();
      }
    }
  }

  void _deliver(_WatchState state, RecordedEvent record) {
    if (record.envelope.aggregate != state.aggregate) {
      logger.severe('Ignored event for a different logical watch');
      return;
    }
    final id = record.envelope.id;
    if (!state.seen.add(id)) return;
    while (state.seen.length > maxSeenPerWatch) {
      state.seen.remove(state.seen.first);
    }
    final stored = record.envelope.event;
    if (!registry.containsKey(stored.eventType)) {
      logger.warning('Unknown event type ${stored.eventType}; skipped $id');
      return;
    }
    try {
      final event = stored.restore(registry);
      localEventBus?.deliver(event);
      for (final lease in state.leases) {
        if (!lease._closed) lease._events.add(event);
      }
    } catch (error, stack) {
      logger.severe(
        'Malformed event ${stored.eventType}; skipped $id',
        error,
        stack,
      );
    }
  }

  Future<void> _stop(_WatchState state, EventWatchStatus status) async {
    await state.subscription?.cancel();
    state.subscription = null;
    _status(state, status);
  }

  Future<void> _release(_WatchState state) async {
    if (state.leases.isNotEmpty) return;
    _watches.remove(state.aggregate.toKey(registry.identityCodecs));
    await state.subscription?.cancel();
    if (!state.ready.isCompleted) state.ready.complete();
    if (_watches.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// App lifecycle hook: stop subscriptions and periodic requests in background.
  Future<void> pause() async {
    if (_closed || _paused) return;
    _paused = true;
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (transport is SuspendableEventTransport) {
      await (transport as SuspendableEventTransport).suspend();
    }
    for (final state in _watches.values.toList()) {
      await state.subscription?.cancel();
      state.subscription = null;
      if (state.status != EventWatchStatus.revoked &&
          state.status != EventWatchStatus.resyncRequired) {
        _status(state, EventWatchStatus.paused);
      }
    }
  }

  /// Reauthorize/resubscribe and recover from per-watch progress on foreground.
  Future<void> resume() async {
    if (_closed) throw StateError('Event client closed');
    if (!_paused) {
      await synchronize();
      return;
    }
    // Let cancelled work settle while still paused, then start a fresh generation.
    await _syncing;
    _paused = false;
    _generation++;
    for (final state in _watches.values) {
      if (state.status == EventWatchStatus.paused) {
        state.status = EventWatchStatus.connecting;
      }
    }
    _startTimer();
    await synchronize();
  }

  /// Cancels all leases, timers, live subscriptions and owned transport resources.
  Future<void> close() async {
    if (_closed) return;
    await pause();
    _closed = true;
    for (final state in _watches.values.toList()) {
      for (final lease in state.leases.toList()) {
        await lease.close();
      }
    }
    await transport.close();
  }
}

class _WatchState {
  _WatchState(this.aggregate, this.checkpoint);
  final AggregateReference<Identity> aggregate;
  String? checkpoint;
  EventChannel? channel;
  EventLiveSubscription? subscription;
  EventWatchStatus status = EventWatchStatus.connecting;
  final ready = Completer<void>();
  final Set<AggregateEventWatch> leases = {};
  final seen = <UuidValue>{};
}
