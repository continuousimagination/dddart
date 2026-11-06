import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/aggregate_event_repository.dart';
import 'package:dddart_events_distributed/src/aggregate_reference.dart';
import 'package:dddart_events_distributed/src/event_envelope.dart';
import 'package:dddart_events_distributed/src/event_registry.dart';
import 'package:dddart_events_distributed/src/retrying_event_publisher.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Verified application identity, supplied by a credential verifier, never JSON.
class EventPrincipal<C> {
  /// Preserves application-specific typed claims.
  EventPrincipal({required this.userId, required this.claims}) {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
  }

  /// Verified subject.
  final String userId;

  /// Verified application claims.
  final C claims;
}

/// Shared request-independent authentication callback for HTTP and Lambda.
typedef EventAuthenticator<C> = Future<EventPrincipal<C>?> Function(
  String token,
);

/// Application-owned authorization, normally reading authoritative membership.
abstract interface class AggregateEventPolicy<C> {
  /// Whether the principal may receive this aggregate's complete event payloads.
  Future<bool> canSubscribe(
    EventPrincipal<C> principal,
    AggregateReference<Identity> aggregate,
  );

  /// Whether the principal may publish this particular event.
  Future<bool> canPublish(EventPrincipal<C> principal, EventEnvelope envelope);
}

/// Current random physical channel for one stable logical aggregate.
class EventChannel {
  /// Creates infrastructure metadata outside aggregate serialization.
  const EventChannel(this.aggregate, this.id);

  /// Logical identity, preserved across rotations.
  final AggregateReference<Identity> aggregate;

  /// Random channel generation, never an incrementing version.
  final UuidValue id;

  /// Canonical AWS-safe path; arbitrary scoped IDs never enter the path.
  String path(String namespace) {
    validateEventNamespace(namespace);
    return '/$namespace/${id.uuid}';
  }
}

/// A durable, idempotent transition between random physical channel IDs.
class EventChannelRotation {
  /// Records the retired and replacement channels.
  const EventChannelRotation(this.previous, this.current);

  /// Channel receiving only a generic refresh hint after this transition.
  final EventChannel previous;

  /// Channel used for subsequent domain publication.
  final EventChannel current;
}

/// Shared channel metadata; production implementations must be process-safe.
abstract interface class EventChannelRepository {
  /// Atomically obtains or creates an aggregate's current random channel.
  Future<EventChannel> resolve(AggregateReference<Identity> aggregate);

  /// Finds only a current channel; stale and unknown IDs return null.
  Future<EventChannel?> find(UuidValue channelId);

  /// Rotates once for an occurrence, rejecting conflicting trigger-ID reuse.
  Future<EventChannelRotation> rotate(
    AggregateReference<Identity> aggregate,
    UuidValue triggerId,
  );
}

/// Instance-local metadata for tests, injected into all local server instances.
class InMemoryEventChannelRepository implements EventChannelRepository {
  /// Uses the same explicit codecs as history and publication.
  InMemoryEventChannelRepository({IdentityCodecRegistry? identityCodecs})
      : identityCodecs = identityCodecs ?? IdentityCodecRegistry();

  /// Explicit scoped identity codecs.
  final IdentityCodecRegistry identityCodecs;
  final Map<String, EventChannel> _channels = {};
  final Map<UuidValue, EventChannelRotation> _rotations = {};

  @override
  Future<EventChannel> resolve(AggregateReference<Identity> aggregate) async =>
      _channels.putIfAbsent(
        aggregate.toKey(identityCodecs),
        () => EventChannel(aggregate, UuidValue.generate()),
      );

  @override
  Future<EventChannel?> find(UuidValue channelId) async {
    for (final channel in _channels.values) {
      if (channel.id == channelId) return channel;
    }
    return null;
  }

  @override
  Future<EventChannelRotation> rotate(
    AggregateReference<Identity> aggregate,
    UuidValue triggerId,
  ) async {
    final previous = _rotations[triggerId];
    if (previous != null) {
      if (previous.current.aggregate != aggregate) {
        throw StateError('Conflicting rotation occurrence');
      }
      return previous;
    }
    // resolve has no asynchronous work, but another rotation may complete while
    // awaiting its Future. Re-read both the trigger and current mapping afterward.
    await resolve(aggregate);
    final raced = _rotations[triggerId];
    if (raced != null) {
      if (raced.current.aggregate != aggregate) {
        throw StateError('Conflicting rotation occurrence');
      }
      return raced;
    }
    final key = aggregate.toKey(identityCodecs);
    final rotation = EventChannelRotation(
      _channels[key]!,
      EventChannel(aggregate, UuidValue.generate()),
    );
    _channels[key] = rotation.current;
    _rotations[triggerId] = rotation;
    return rotation;
  }
}

/// An authorization failure contains no aggregate payload or membership detail.
class EventAccessDenied implements Exception {
  /// Creates a uniform denial.
  const EventAccessDenied();
}

/// Shared authenticated ingestion, history, and channel-resolution operations.
class AggregateEventService<C> {
  /// Injects all state; construction opens no listener and creates no resources.
  AggregateEventService({
    required this.history,
    required this.channels,
    required this.registry,
    required this.policy,
    this.localEventBus,
    this.onEvent,
    this.broadcast,
    this.refresh,
    this.rotatesAccess,
    Logger? logger,
  }) : logger = logger ?? Logger('dddart.events.service');

  /// Durable server history or explicit local test implementation.
  final AggregateEventRepository history;

  /// Shared current-channel mappings.
  final EventChannelRepository channels;

  /// Explicit stable event and identity codecs.
  final EventRegistry registry;

  /// Shared application authorization.
  final AggregateEventPolicy<C> policy;

  /// Optional in-invocation domain delivery, without publication echo.
  final EventBus? localEventBus;

  /// Application processing awaited within the invocation; handlers tolerate duplicates.
  final Future<void> Function(DomainEvent<Identity>)? onEvent;

  /// Optional live transport; must complete before the invocation returns.
  final Future<void> Function(EventChannel, RecordedEvent)? broadcast;

  /// Best-effort generic refresh control hint to a retired channel.
  final Future<void> Function(EventChannel)? refresh;

  /// Explicit registration of access-changing event kinds; no field fingerprint.
  final bool Function(DomainEvent<Identity>)? rotatesAccess;

  /// Operational logger.
  final Logger logger;

  /// Resolves only after checking current application membership.
  Future<EventChannel> resolve(
    EventPrincipal<C> principal,
    AggregateReference<Identity> aggregate,
  ) async {
    if (!await policy.canSubscribe(principal, aggregate)) {
      throw const EventAccessDenied();
    }
    return channels.resolve(aggregate);
  }

  /// Authorizes every history read independently of the supplied checkpoint.
  Future<EventPage> read(
    EventPrincipal<C> principal,
    AggregateReference<Identity> aggregate,
    EventCheckpoint after, {
    int limit = 100,
  }) async {
    await resolve(principal, aggregate);
    return history.read(aggregate, after: after, limit: limit);
  }

  /// Authorizes, validates, durably accepts, rotates and delivers one occurrence.
  ///
  /// Native AppSync handlers use broadcastLive=false because their response is
  /// the broadcast. Trusted backends use the same policy with their own principal.
  Future<RecordedEvent> accept(
    EventPrincipal<C> principal,
    EventEnvelope envelope, {
    UuidValue? expectedChannel,
    bool broadcastLive = true,
  }) async {
    if (!await policy.canPublish(principal, envelope)) {
      throw const EventAccessDenied();
    }
    if (utf8.encode(envelope.canonicalJson(registry.identityCodecs)).length >
        230 * 1024) {
      throw const RepositoryException(
        'Event envelope exceeds 230 KiB transport budget',
        type: RepositoryExceptionType.constraint,
      );
    }
    final before = await channels.resolve(envelope.aggregate);
    if (expectedChannel != null && before.id != expectedChannel) {
      throw const EventAccessDenied();
    }
    final event = envelope.event.restore(registry);
    final record = await history.append(envelope);
    if (rotatesAccess?.call(event) ?? false) {
      final rotation = await channels.rotate(envelope.aggregate, envelope.id);
      try {
        await refresh?.call(rotation.previous);
      } catch (error, stack) {
        logger.warning('Refresh hint failed for ${envelope.id}', error, stack);
      }
    }
    await onEvent?.call(event);
    localEventBus?.deliver(event);
    if (broadcastLive) {
      // Always resolve after processing rotation, never reuse a cached target.
      await broadcast?.call(await channels.resolve(envelope.aggregate), record);
    }
    return record;
  }
}

/// Publisher shared by server, polling and AppSync repository implementations.
class EnvelopeEventPublisher implements EventPublisher {
  /// Adapts domain events to a separate explicit publication contract.
  EnvelopeEventPublisher({
    required EventRegistry registry,
    required String Function(DomainEvent<Identity>) aggregateKind,
    required Future<void> Function(EventEnvelope) send,
    EventRetryPolicy? policy,
    Logger? logger,
  }) {
    _publisher = RetryingEventPublisher(
      policy: policy,
      logger: logger,
      send: (event) => send(
        EventEnvelope(
          aggregate: AggregateReference(
            kind: aggregateKind(event),
            id: event.aggregateId,
          ),
          event: StoredEvent<Identity>.fromDomainEvent(
            event,
            registry: registry,
          ),
        ),
      ),
    );
  }
  late final RetryingEventPublisher _publisher;
  @override
  Future<bool> publish(DomainEvent<Identity> event) =>
      _publisher.publish(event);
}

/// Shared explicit wire encoding; checkpoint tokens never confer permission.
class AggregateEventWire {
  /// Creates an encoder using application identity codecs.
  const AggregateEventWire(this.identities);

  /// Explicit identity codecs.
  final IdentityCodecRegistry identities;

  /// Encodes server progress as an opaque transport token.
  String checkpoint(EventCheckpoint value) => base64Url.encode(
        utf8.encode(
          jsonEncode({
            'stream': value.streamKey,
            'position': value.position,
            'at': value.observedAt.toIso8601String(),
          }),
        ),
      );

  /// Restores progress; membership is always checked separately.
  EventCheckpoint parseCheckpoint(String token) {
    if (token.length > 1024 * 1024) {
      throw const FormatException('Checkpoint too large');
    }
    final json = jsonDecode(utf8.decode(base64Url.decode(token)))
        as Map<String, dynamic>;
    return EventCheckpoint(
      streamKey: json['stream'] as String,
      position: json['position'] as int,
      observedAt: DateTime.parse(json['at'] as String),
    );
  }

  /// Encodes a committed history record for HTTP and live transports.
  Map<String, dynamic> record(RecordedEvent value) => {
        'envelope': value.envelope.toJson(identities),
        'position': value.position,
        'ingestedAt': value.ingestedAt.toIso8601String(),
      };

  /// Restores a committed history record without decoding its domain payload.
  RecordedEvent parseRecord(Map<String, dynamic> json) => RecordedEvent(
        envelope: EventEnvelope.fromJson(
          Map<String, dynamic>.from(json['envelope'] as Map),
          identityCodecs: identities,
        ),
        position: json['position'] as int,
        ingestedAt: DateTime.parse(json['ingestedAt'] as String),
      );
}

/// Validates a canonical physical namespace, independent of logical identities.
void validateEventNamespace(String namespace) {
  if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,48}[A-Za-z0-9])?$')
      .hasMatch(namespace)) {
    throw ArgumentError.value(namespace, 'namespace');
  }
}

/// Parses only a single exact UUID channel; wildcard subscriptions are denied.
UuidValue parseEventChannel(String path, String namespace) {
  validateEventNamespace(namespace);
  final prefix = '/$namespace/';
  if (!path.startsWith(prefix)) throw const EventAccessDenied();
  final id = path.substring(prefix.length);
  if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
      .hasMatch(id)) {
    throw const EventAccessDenied();
  }
  return UuidValue.fromString(id);
}
