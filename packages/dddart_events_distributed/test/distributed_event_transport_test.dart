import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:test/test.dart';

void main() {
  group('DistributedEventTransport', () {
    test('remote StoredEvent payloads flow into the local EventBus', () async {
      final localEventBus = EventBus();
      final transport = _InMemoryDistributedEventTransport();
      final received = <_RealtimeTestEvent>[];
      final listener = localEventBus
          .on<_RealtimeTestEvent>()
          .listen(received.add);

      final bridge = DistributedEventBusBridge(
        localEventBus: localEventBus,
        transport: transport,
        storedEventDecoder: _decodeRealtimeTestEvent,
      )..start();

      final remoteEvent = _RealtimeTestEvent(
        aggregateId: UuidValue.generate(),
        eventId: UuidValue.generate(),
        occurredAt: DateTime.utc(2026, 7, 9, 16, 47),
        message: 'remote notification',
        context: const {'tenantId': 'tenant-1'},
      );

      await transport.publish(StoredEvent.fromDomainEvent(remoteEvent));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.eventId, equals(remoteEvent.eventId));
      expect(received.single.aggregateId, equals(remoteEvent.aggregateId));
      expect(received.single.message, equals(remoteEvent.message));
      expect(received.single.context, equals(remoteEvent.context));

      await bridge.close();
      await listener.cancel();
      await transport.close();
      await localEventBus.close();
    });

    test('dedupes duplicate realtime notifications by eventId', () async {
      final localEventBus = EventBus();
      final transport = _InMemoryDistributedEventTransport();
      final received = <_RealtimeTestEvent>[];
      final listener = localEventBus
          .on<_RealtimeTestEvent>()
          .listen(received.add);

      final bridge = DistributedEventBusBridge(
        localEventBus: localEventBus,
        transport: transport,
        storedEventDecoder: _decodeRealtimeTestEvent,
      )..start();

      final storedEvent = StoredEvent.fromDomainEvent(
        _RealtimeTestEvent(
          aggregateId: UuidValue.generate(),
          eventId: UuidValue.generate(),
          occurredAt: DateTime.utc(2026, 7, 9, 16, 47),
          message: 'duplicate notification',
        ),
      );

      await transport.publish(storedEvent);
      await transport.publish(storedEvent);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));

      await bridge.close();
      await listener.cancel();
      await transport.close();
      await localEventBus.close();
    });
  });
}

DomainEvent? _decodeRealtimeTestEvent(StoredEvent storedEvent) {
  if (storedEvent.eventType != '_RealtimeTestEvent') {
    return null;
  }

  final decoded = jsonDecode(storedEvent.eventJson);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('StoredEvent.eventJson must decode to a map');
  }

  return _RealtimeTestEvent.fromJson(decoded);
}

class _InMemoryDistributedEventTransport implements DistributedEventTransport {
  final StreamController<StoredEvent> _events =
      StreamController<StoredEvent>.broadcast();

  @override
  Stream<StoredEvent> subscribe({
    EventSubscriptionOptions options = const EventSubscriptionOptions(),
  }) {
    return _events.stream;
  }

  @override
  Future<void> publish(
    StoredEvent event, {
    EventPublishOptions options = const EventPublishOptions(),
  }) async {
    _events.add(event);
  }

  @override
  Future<void> close() async {
    await _events.close();
  }
}

class _RealtimeTestEvent extends DomainEvent {
  _RealtimeTestEvent({
    required super.aggregateId,
    required this.message,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  factory _RealtimeTestEvent.fromJson(Map<String, dynamic> json) {
    return _RealtimeTestEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      message: json['message'] as String,
      context: Map<String, dynamic>.from(
        json['context'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }

  final String message;

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId.toString(),
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'message': message,
      'context': context,
    };
  }
}
