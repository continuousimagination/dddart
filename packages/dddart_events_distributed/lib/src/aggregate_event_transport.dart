import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/aggregate_event_repository.dart';
import 'package:dddart_events_distributed/src/aggregate_event_service.dart';
import 'package:dddart_events_distributed/src/aggregate_reference.dart';
import 'package:dddart_events_distributed/src/event_envelope.dart';
import 'package:dddart_events_distributed/src/retrying_event_publisher.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

/// One logical interest with optional previously acknowledged server progress.
class EventWatchRequest {
  /// A null checkpoint means a fresh watch, starting at the server head.
  const EventWatchRequest(this.aggregate, {this.checkpoint});

  /// Logical interest.
  final AggregateReference<Identity> aggregate;

  /// Opaque server progress token, unrelated to authorization.
  final String? checkpoint;
}

/// One independent result in a batched resolution or catch-up response.
class EventWatchResult {
  /// Uses status active, revoked, or resyncRequired.
  const EventWatchResult({
    required this.aggregate,
    required this.status,
    this.channel,
    this.checkpoint,
    this.events = const [],
    this.hasMore = false,
  });

  /// Logical interest.
  final AggregateReference<Identity> aggregate;

  /// Typed protocol state encoded independently per aggregate.
  final EventWatchStatus status;

  /// Current physical channel when authorized.
  final EventChannel? channel;

  /// Last fully considered server progress token.
  final String? checkpoint;

  /// Stored ingestion-ordered catch-up records.
  final List<RecordedEvent> events;

  /// Whether to continue paging this aggregate.
  final bool hasMore;
}

/// Watch states require application action only for revoked/expired watches.
enum EventWatchStatus {
  /// Resolving or recovering the watch.
  connecting,

  /// Authorized and consuming events.
  active,

  /// Membership was denied; other watches continue.
  revoked,

  /// History expired; explicitly reload application state and watch afresh.
  resyncRequired,

  /// Lifecycle pause; no polling or live subscriptions.
  paused,

  /// Released by the application.
  closed,
}

/// Transport-independent batched watches and separate event ingestion.
abstract interface class AggregateEventTransport {
  /// Resolves membership/current channels and establishes fresh heads.
  Future<List<EventWatchResult>> resolve(List<EventWatchRequest> watches);

  /// Reads retained history, authorizing every requested aggregate anew.
  Future<List<EventWatchResult>> read(List<EventWatchRequest> watches);

  /// Completes only after durable acceptance, otherwise throws a classified error.
  Future<void> publish(EventEnvelope envelope);

  /// Releases owned resources.
  Future<void> close();
}

/// Separately authorized routing for a publisher that cannot subscribe.
// ignore: one_member_abstracts
abstract interface class EventPublicationResolver {
  Future<EventChannel> publicationTarget(EventEnvelope envelope);
}

/// Optional lifecycle cancellation without permanently closing a transport.
// ignore: one_member_abstracts
abstract interface class SuspendableEventTransport {
  Future<void> suspend();
}

/// A live subscription with explicit asynchronous cleanup.
// ignore: one_member_abstracts
abstract interface class EventLiveSubscription {
  /// Unsubscribes this watch without closing other watches.
  Future<void> cancel();
}

/// Optional live capability, shared by the AppSync SDK and protocol fakes.
abstract interface class LiveAggregateEventTransport
    implements AggregateEventTransport {
  /// Waits for subscription acknowledgment before completing.
  Future<EventLiveSubscription> subscribe(
    EventChannel channel, {
    required void Function(RecordedEvent) onEvent,
    required void Function() onRefresh,
    required void Function() onDisconnect,
  });
}

/// Application-owned Shelf routes; no socket or persistent worker is started.
class AggregateEventHttpEndpoints<C> {
  /// Injects the same verifier and service used by native invocation handlers.
  AggregateEventHttpEndpoints({
    required this.service,
    required this.authenticate,
    this.maxWatches = 100,
    this.pageSize = 10,
    this.maxEventsPerResponse = 200,
    this.maxResponseBytes = 4 * 1024 * 1024,
  }) {
    if (maxWatches < 1 ||
        pageSize < 1 ||
        pageSize > 1000 ||
        maxEventsPerResponse < 1 ||
        maxResponseBytes < 512 * 1024) {
      throw ArgumentError('Invalid HTTP event budgets');
    }
  }

  /// Shared membership, ingestion and history path.
  final AggregateEventService<C> service;

  /// Request-independent verified identity callback.
  final EventAuthenticator<C> authenticate;

  /// Maximum references accepted per batched request.
  final int maxWatches;

  /// Per-aggregate and global event/byte budgets for one catch-up response.
  final int pageSize;
  final int maxEventsPerResponse;
  final int maxResponseBytes;

  /// POST /events/target; checks publish rights, never substitutes subscribe rights.
  Future<Response> target(Request request) async {
    try {
      final principal = await _principal(request);
      if (principal == null) return _response(401, {'error': 'Unauthorized'});
      final envelope = EventEnvelope.fromJson(
        await _body(request),
        identityCodecs: service.registry.identityCodecs,
      );
      if (!await service.policy.canPublish(principal, envelope)) {
        return _response(403, {'error': 'Forbidden'});
      }
      envelope.event.restore(service.registry);
      final channel = await service.channels.resolve(envelope.aggregate);
      return _response(200, {'channel': channel.id.uuid});
    } catch (error, stack) {
      service.logger
          .warning('Invalid publication target request', error, stack);
      return _response(400, {'error': 'Invalid event request'});
    }
  }

  /// POST /events/resolve; fresh watches establish server heads here.
  Future<Response> resolve(Request request) => _handle(request, false);

  /// POST /events/read; every watch has its own checkpoint.
  Future<Response> read(Request request) => _handle(request, true);

  Future<EventPrincipal<C>?> _principal(Request request) async {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return authenticate(header.substring(7).trim());
  }

  Future<Response> _handle(Request request, bool recover) async {
    try {
      final principal = await _principal(request);
      if (principal == null) return _response(401, {'error': 'Unauthorized'});
      final json = await _body(request);
      final watches = json['watches'] as List;
      if (watches.length > maxWatches) {
        throw const FormatException('Too many watches');
      }
      final wire = AggregateEventWire(service.registry.identityCodecs);
      final results = <Map<String, dynamic>>[];
      var bytesUsed = 2048;
      var eventsRemaining = maxEventsPerResponse;
      for (final value in watches) {
        final watch = Map<String, dynamic>.from(value as Map);
        final aggregate = AggregateReference<Identity>.fromJson(
          Map<String, dynamic>.from(watch['aggregate'] as Map),
          identityCodecs: wire.identities,
        );
        final result = <String, dynamic>{
          'aggregate': aggregate.toJson(wire.identities),
        };
        try {
          final channel = await service.resolve(principal, aggregate);
          final supplied = watch['checkpoint'] as String?;
          if (recover && supplied == null) {
            throw const FormatException('Checkpoint required');
          }
          var checkpoint = supplied == null
              ? await service.history.head(aggregate)
              : wire.parseCheckpoint(supplied);
          if (recover) {
            final limit = min(
              pageSize,
              min(
                eventsRemaining,
                max(
                  0,
                  (maxResponseBytes - bytesUsed - 4096) ~/ (256 * 1024),
                ),
              ),
            );
            if (limit == 0) {
              result['events'] = <Map<String, dynamic>>[];
              result['hasMore'] = true;
            } else {
              final page = await service.read(
                principal,
                aggregate,
                checkpoint,
                limit: limit,
              );
              checkpoint = page.checkpoint;
              result['events'] = page.events.map(wire.record).toList();
              result['hasMore'] = page.hasMore;
              eventsRemaining -= page.events.length;
            }
          } else if (supplied != null) {
            // Validate retained recovery state without advancing it on resolution.
            await service.read(principal, aggregate, checkpoint, limit: 1);
          }
          result.addAll({
            'status': 'active',
            'channel': channel.id.uuid,
            'checkpoint': wire.checkpoint(checkpoint),
          });
        } on EventAccessDenied {
          result['status'] = 'revoked';
        } on EventHistoryExpired {
          result['status'] = 'resyncRequired';
        }
        results.add(result);
        bytesUsed += utf8.encode(jsonEncode(result)).length;
      }
      return _response(200, {'watches': results});
    } on FormatException {
      return _response(400, {'error': 'Invalid event request'});
    } catch (error, stack) {
      if (error is ArgumentError ||
          error is TypeError ||
          error is SerializationException) {
        return _response(400, {'error': 'Invalid event request'});
      }
      service.logger.severe('Event watch request failed', error, stack);
      return _response(500, {'error': 'Event request failed'});
    }
  }

  /// POST /events/publish; public aggregate CRUD does not carry this payload.
  Future<Response> publish(Request request) async {
    try {
      final principal = await _principal(request);
      if (principal == null) return _response(401, {'error': 'Unauthorized'});
      final envelope = EventEnvelope.fromJson(
        await _body(request),
        identityCodecs: service.registry.identityCodecs,
      );
      final record = await service.accept(principal, envelope);
      return _response(
        201,
        AggregateEventWire(service.registry.identityCodecs).record(record),
      );
    } on EventAccessDenied {
      return _response(403, {'error': 'Forbidden'});
    } on RepositoryException catch (error) {
      return _response(
        error.type == RepositoryExceptionType.duplicate
            ? 409
            : error.type == RepositoryExceptionType.constraint
                ? 400
                : 503,
        {'error': 'Event acceptance failed'},
      );
    } on FormatException {
      return _response(400, {'error': 'Invalid event envelope'});
    } on SerializationException {
      return _response(400, {'error': 'Invalid event envelope'});
    } catch (error, stack) {
      if (error is ArgumentError || error is TypeError) {
        return _response(400, {'error': 'Invalid event envelope'});
      }
      service.logger.severe('Event publication failed', error, stack);
      return _response(503, {'error': 'Event acceptance failed'});
    }
  }

  Future<Map<String, dynamic>> _body(Request request) async {
    if (request.method != 'POST') throw const FormatException('POST required');
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException('Request too large');
      }
      bytes.addAll(chunk);
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Response _response(int status, Map<String, dynamic> json) {
    final body = jsonEncode(json);
    if (utf8.encode(body).length > maxResponseBytes) {
      return Response(
        413,
        body: '{"error":"Event response budget exceeded"}',
        headers: {'content-type': 'application/json'},
      );
    }
    return Response(
      status,
      body: body,
      headers: {
        'content-type': 'application/json',
        'cache-control': 'no-store',
      },
    );
  }
}

/// Batched HTTP transport usable without AWS, Flutter, or client-side event DBs.
class HttpAggregateEventTransport
    implements
        AggregateEventTransport,
        EventPublicationResolver,
        SuspendableEventTransport {
  /// Uses refreshed application credentials for every request.
  HttpAggregateEventTransport({
    required this.baseUrl,
    required this.wire,
    required this.tokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    bool? ownsClient,
  })  : _client = client ?? http.Client(),
        _ownsClient = ownsClient ?? client == null;

  /// App-owned endpoint prefix, such as https://example.com/events.
  final Uri baseUrl;

  /// Shared explicit codecs and server-progress encoding.
  final AggregateEventWire wire;

  /// Existing AuthProvider.getIdToken or another current-token callback.
  final Future<String?> Function() tokenProvider;

  /// Bounded HTTP waiting and cancellation budget.
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  final Set<Completer<void>> _requests = {};
  int _lifecycle = 0;
  bool _closed = false;

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (_closed) throw const EventPublicationException('Transport closed');
    final lifecycle = _lifecycle;
    final token = await tokenProvider().timeout(timeout);
    if (_closed || lifecycle != _lifecycle) {
      throw const EventPublicationException('Event request cancelled');
    }
    if (token == null || token.isEmpty) {
      throw const EventPublicationException('Authentication required');
    }
    final abort = Completer<void>();
    _requests.add(abort);
    final timer = Timer(timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final uri = baseUrl.replace(
        path: '${baseUrl.path.replaceFirst(RegExp(r'/$'), '')}/$action',
      );
      final encoded = jsonEncode(payload);
      if (utf8.encode(encoded).length > 1024 * 1024) {
        throw const EventPublicationException(
          'Event request exceeds batch byte budget',
        );
      }
      final request =
          http.AbortableRequest('POST', uri, abortTrigger: abort.future)
            ..headers.addAll({
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            })
            ..body = encoded;
      final response =
          await _boundedResponse(await _client.send(request)).timeout(timeout);
      if (_closed) throw const EventPublicationException('Transport closed');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw EventPublicationException(
          'HTTP event request failed: ${response.statusCode}',
          retryable: response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500,
        );
      }
      if (response.bodyBytes.length > 8 * 1024 * 1024) {
        throw const FormatException('Event response too large');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _requests.remove(abort);
    }
  }

  Future<http.Response> _boundedResponse(http.StreamedResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 8 * 1024 * 1024) {
        throw const FormatException('Event response too large');
      }
      bytes.addAll(chunk);
    }
    return http.Response.bytes(
      bytes,
      response.statusCode,
      headers: response.headers,
    );
  }

  Future<List<EventWatchResult>> _watches(
    String action,
    List<EventWatchRequest> watches,
  ) async {
    final result = await _post(action, {
      'watches': watches
          .map(
            (watch) => {
              'aggregate': watch.aggregate.toJson(wire.identities),
              if (watch.checkpoint != null) 'checkpoint': watch.checkpoint,
            },
          )
          .toList(),
    });
    return (result['watches'] as List).map((value) {
      final json = Map<String, dynamic>.from(value as Map);
      final aggregate = AggregateReference<Identity>.fromJson(
        Map<String, dynamic>.from(json['aggregate'] as Map),
        identityCodecs: wire.identities,
      );
      final status = EventWatchStatus.values.byName(json['status'] as String);
      return EventWatchResult(
        aggregate: aggregate,
        status: status,
        channel: json['channel'] == null
            ? null
            : EventChannel(
                aggregate,
                UuidValue.fromString(json['channel'] as String),
              ),
        checkpoint: json['checkpoint'] as String?,
        events: ((json['events'] as List?) ?? [])
            .map(
              (item) =>
                  wire.parseRecord(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        hasMore: json['hasMore'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<List<EventWatchResult>> resolve(List<EventWatchRequest> watches) =>
      _watches('resolve', watches);
  @override
  Future<List<EventWatchResult>> read(List<EventWatchRequest> watches) =>
      _watches('read', watches);
  @override
  Future<void> publish(EventEnvelope envelope) async {
    await _post('publish', envelope.toJson(wire.identities));
  }

  @override
  Future<EventChannel> publicationTarget(EventEnvelope envelope) async {
    final result = await _post('target', envelope.toJson(wire.identities));
    return EventChannel(
      envelope.aggregate,
      UuidValue.fromString(result['channel'] as String),
    );
  }

  @override
  Future<void> suspend() async {
    _lifecycle++;
    for (final abort in _requests.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final abort in _requests.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsClient) _client.close();
  }
}
