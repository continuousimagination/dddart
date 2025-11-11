import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

// Test domain events for serialization testing
class UserRegisteredEvent extends DomainEvent {
  UserRegisteredEvent({
    required UuidValue userId,
    required this.email,
    required this.organizationId,
    required this.fullName,
    super.eventId,
    super.occurredAt,
  }) : super(
          aggregateId: userId,
          context: {
            'organizationId': organizationId,
            'email': email,
          },
        );

  factory UserRegisteredEvent.fromJson(Map<String, dynamic> json) {
    return UserRegisteredEvent(
      userId: UuidValue.fromString(json['aggregateId'] as String),
      email: json['email'] as String,
      organizationId: json['organizationId'] as String,
      fullName: json['fullName'] as String,
      eventId: json['eventId'] != null
          ? UuidValue.fromString(json['eventId'] as String)
          : null,
      occurredAt: json['occurredAt'] != null
          ? DateTime.parse(json['occurredAt'] as String)
          : null,
    );
  }
  final String email;
  final String organizationId;
  final String fullName;

  // Manual serialization methods for testing
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId.uuid,
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.uuid,
      'context': context,
      'email': email,
      'organizationId': organizationId,
      'fullName': fullName,
    };
  }
}

class OrderPlacedEvent extends DomainEvent {
  OrderPlacedEvent({
    required UuidValue orderId,
    required this.customerId,
    required this.totalAmount,
    required this.currency,
    required this.itemCount,
    super.eventId,
    super.occurredAt,
  }) : super(
          aggregateId: orderId,
          context: {
            'customerId': customerId,
            'totalAmount': totalAmount,
            'currency': currency,
            'itemCount': itemCount,
          },
        );

  factory OrderPlacedEvent.fromJson(Map<String, dynamic> json) {
    return OrderPlacedEvent(
      orderId: UuidValue.fromString(json['aggregateId'] as String),
      customerId: json['customerId'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      itemCount: json['itemCount'] as int,
      eventId: json['eventId'] != null
          ? UuidValue.fromString(json['eventId'] as String)
          : null,
      occurredAt: json['occurredAt'] != null
          ? DateTime.parse(json['occurredAt'] as String)
          : null,
    );
  }
  final String customerId;
  final double totalAmount;
  final String currency;
  final int itemCount;

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId.uuid,
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.uuid,
      'context': context,
      'customerId': customerId,
      'totalAmount': totalAmount,
      'currency': currency,
      'itemCount': itemCount,
    };
  }
}

void main() {
  group('Event Serialization', () {
    group('DomainEvent base metadata serialization', () {
      test('event metadata can be serialized to JSON', () {
        final event = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
          eventId: UuidValue.fromString('11111111-2222-3333-4444-555555555555'),
          occurredAt: DateTime(2023, 6, 15, 10, 30),
        );

        final json = event.toJson();

        expect(json['eventId'], equals('event-789'));
        expect(json['aggregateId'], equals('user-123'));
        expect(json['occurredAt'], equals('2023-06-15T10:30:00.000'));
        expect(json['context'], isA<Map<String, dynamic>>());
      });

      test('event can be deserialized from JSON', () {
        final json = {
          'eventId': 'event-789',
          'occurredAt': '2023-06-15T10:30:00.000',
          'aggregateId': 'user-123',
          'context': {
            'organizationId': 'org-456',
            'email': 'test@example.com',
          },
          'email': 'test@example.com',
          'organizationId': 'org-456',
          'fullName': 'Test User',
        };

        final event = UserRegisteredEvent.fromJson(json);

        expect(event.eventId, equals('event-789'));
        expect(event.aggregateId, equals('user-123'));
        expect(event.occurredAt, equals(DateTime(2023, 6, 15, 10, 30)));
        expect(event.email, equals('test@example.com'));
        expect(event.organizationId, equals('org-456'));
        expect(event.fullName, equals('Test User'));
      });

      test('event context map is preserved during serialization', () {
        final event = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
        );

        final json = event.toJson();
        final deserialized = UserRegisteredEvent.fromJson(json);

        expect(deserialized.context['organizationId'], equals('org-456'));
        expect(deserialized.context['email'], equals('test@example.com'));
      });
    });

    group('complete event serialization round-trip', () {
      test('UserRegisteredEvent survives JSON round-trip', () {
        final original = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
          eventId: UuidValue.fromString('11111111-2222-3333-4444-555555555555'),
          occurredAt: DateTime(2023, 6, 15, 10, 30),
        );

        final json = original.toJson();
        final jsonString = jsonEncode(json);
        final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final deserialized = UserRegisteredEvent.fromJson(decodedJson);

        expect(deserialized.eventId, equals(original.eventId));
        expect(deserialized.aggregateId, equals(original.aggregateId));
        expect(deserialized.occurredAt, equals(original.occurredAt));
        expect(deserialized.email, equals(original.email));
        expect(deserialized.organizationId, equals(original.organizationId));
        expect(deserialized.fullName, equals(original.fullName));
      });

      test('OrderPlacedEvent survives JSON round-trip', () {
        final original = OrderPlacedEvent(
          orderId: UuidValue.fromString('87654321-4321-4321-4321-cba987654321'),
          customerId: 'customer-456',
          totalAmount: 99.99,
          currency: 'USD',
          itemCount: 3,
          eventId: UuidValue.fromString('11111111-2222-3333-4444-555555555555'),
          occurredAt: DateTime(2023, 6, 15, 10, 30),
        );

        final json = original.toJson();
        final jsonString = jsonEncode(json);
        final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final deserialized = OrderPlacedEvent.fromJson(decodedJson);

        expect(deserialized.eventId, equals(original.eventId));
        expect(deserialized.aggregateId, equals(original.aggregateId));
        expect(deserialized.occurredAt, equals(original.occurredAt));
        expect(deserialized.customerId, equals(original.customerId));
        expect(deserialized.totalAmount, equals(original.totalAmount));
        expect(deserialized.currency, equals(original.currency));
        expect(deserialized.itemCount, equals(original.itemCount));
      });
    });

    group('event serialization with auto-generated fields', () {
      test('auto-generated eventId is preserved during serialization', () {
        final original = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
        );

        final json = original.toJson();
        final deserialized = UserRegisteredEvent.fromJson(json);

        expect(deserialized.eventId, equals(original.eventId));
        expect(deserialized.eventId, isNotEmpty);
      });

      test('auto-generated occurredAt is preserved during serialization', () {
        final original = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
        );

        final json = original.toJson();
        final deserialized = UserRegisteredEvent.fromJson(json);

        expect(deserialized.occurredAt, equals(original.occurredAt));
      });
    });

    group('event serialization with complex context', () {
      test('complex context data is preserved during serialization', () {
        final event = OrderPlacedEvent(
          orderId: UuidValue.fromString('87654321-4321-4321-4321-cba987654321'),
          customerId: 'customer-456',
          totalAmount: 99.99,
          currency: 'USD',
          itemCount: 3,
        );

        final json = event.toJson();
        final deserialized = OrderPlacedEvent.fromJson(json);

        expect(deserialized.context['customerId'], equals('customer-456'));
        expect(deserialized.context['totalAmount'], equals(99.99));
        expect(deserialized.context['currency'], equals('USD'));
        expect(deserialized.context['itemCount'], equals(3));
      });
    });

    group('serialization compatibility with EventBus', () {
      test('serialized events can be published and received through EventBus',
          () async {
        final eventBus = EventBus();
        final receivedEvents = <UserRegisteredEvent>[];

        eventBus.on<UserRegisteredEvent>().listen(receivedEvents.add);

        // Create event, serialize, deserialize, then publish
        final original = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
        );

        final json = original.toJson();
        final jsonString = jsonEncode(json);
        final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final deserialized = UserRegisteredEvent.fromJson(decodedJson);

        eventBus.publish(deserialized);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(receivedEvents, hasLength(1));
        expect(receivedEvents.first.eventId, equals(original.eventId));
        expect(receivedEvents.first.email, equals(original.email));

        await eventBus.close();
      });

      test('multiple serialized event types can be published to same EventBus',
          () async {
        final eventBus = EventBus();
        final userEvents = <UserRegisteredEvent>[];
        final orderEvents = <OrderPlacedEvent>[];

        eventBus.on<UserRegisteredEvent>().listen(userEvents.add);
        eventBus.on<OrderPlacedEvent>().listen(orderEvents.add);

        // Create, serialize, and deserialize user event
        final userEvent = UserRegisteredEvent(
          userId: UuidValue.fromString('12345678-1234-1234-1234-123456789abc'),
          email: 'test@example.com',
          organizationId: 'org-456',
          fullName: 'Test User',
        );
        final userJson = jsonEncode(userEvent.toJson());
        final deserializedUser = UserRegisteredEvent.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );

        // Create, serialize, and deserialize order event
        final orderEvent = OrderPlacedEvent(
          orderId: UuidValue.fromString('87654321-4321-4321-4321-cba987654321'),
          customerId: 'customer-456',
          totalAmount: 99.99,
          currency: 'USD',
          itemCount: 3,
        );
        final orderJson = jsonEncode(orderEvent.toJson());
        final deserializedOrder = OrderPlacedEvent.fromJson(
          jsonDecode(orderJson) as Map<String, dynamic>,
        );

        eventBus.publish(deserializedUser);
        eventBus.publish(deserializedOrder);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(userEvents, hasLength(1));
        expect(orderEvents, hasLength(1));
        expect(userEvents.first.email, equals('test@example.com'));
        expect(orderEvents.first.totalAmount, equals(99.99));

        await eventBus.close();
      });
    });

    group('serialization with AggregateRoot integration', () {
      test('events raised by aggregate can be serialized', () {
        // Create a test aggregate
        final aggregate = TestAggregate();

        // Raise an event
        aggregate.registerUser(
          'test@example.com',
          'org-456',
          'Test User',
        );

        // Get uncommitted events
        final events = aggregate.getUncommittedEvents();
        expect(events, hasLength(1));

        final event = events.first as UserRegisteredEvent;

        // Serialize the event
        final json = event.toJson();
        final jsonString = jsonEncode(json);

        // Deserialize the event
        final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final deserialized = UserRegisteredEvent.fromJson(decodedJson);

        expect(deserialized.eventId, equals(event.eventId));
        expect(deserialized.email, equals('test@example.com'));
        expect(deserialized.organizationId, equals('org-456'));
        expect(deserialized.fullName, equals('Test User'));
      });
    });
  });
}

// Test aggregate for integration testing
class TestAggregate extends AggregateRoot {
  TestAggregate({super.id});

  void registerUser(String email, String organizationId, String fullName) {
    raiseEvent(
      UserRegisteredEvent(
        userId: id,
        email: email,
        organizationId: organizationId,
        fullName: fullName,
      ),
    );
    touch();
  }
}
