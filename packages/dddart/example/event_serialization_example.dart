import 'dart:convert';
import 'package:dddart/dddart.dart';

/// Example demonstrating event serialization for persistence or message queues.
///
/// This shows how to manually serialize domain events when you need to:
/// - Store events in an event store
/// - Send events to a message queue (RabbitMQ, AWS SQS, etc.)
/// - Transmit events over HTTP/WebSocket
/// - Implement event sourcing
///
/// Run with: dart run example/event_serialization_example.dart
void main() {
  print('🔄 Domain Event Serialization Example\n');

  _basicSerialization();
  _eventStoreSimulation();
  _messageQueueSimulation();

  print('\n✅ All serialization examples completed!');
}

/// Demonstrate basic event serialization
void _basicSerialization() {
  print('📝 Basic Event Serialization');
  print('=' * 40);

  // Create an event
  final event = UserRegisteredEvent(
    userId: UuidValue.generate(),
    email: 'john.doe@example.com',
    fullName: 'John Doe',
    organizationId: 'org-123',
  );

  print('Original event:');
  print('  Event ID: ${event.eventId.uuid}');
  print('  Aggregate ID: ${event.aggregateId.uuid}');
  print('  Email: ${event.email}');
  print('  Occurred at: ${event.occurredAt}');

  // Serialize to JSON
  final json = event.toJson();
  final jsonString = jsonEncode(json);

  print('\nSerialized JSON:');
  print(JsonEncoder.withIndent('  ').convert(json));

  // Deserialize back
  final restoredEvent = UserRegisteredEvent.fromJson(
    jsonDecode(jsonString) as Map<String, dynamic>,
  );

  print('\nRestored event:');
  print('  Event ID: ${restoredEvent.eventId.uuid}');
  print('  Aggregate ID: ${restoredEvent.aggregateId.uuid}');
  print('  Email: ${restoredEvent.email}');
  print('  Occurred at: ${restoredEvent.occurredAt}');

  // Verify round-trip
  assert(restoredEvent.eventId.uuid == event.eventId.uuid);
  assert(restoredEvent.aggregateId.uuid == event.aggregateId.uuid);
  assert(restoredEvent.email == event.email);

  print('\n✅ Round-trip serialization successful!\n');
}

/// Simulate storing events in an event store
void _eventStoreSimulation() {
  print('💾 Event Store Simulation');
  print('=' * 40);

  // Simulate an event store
  final eventStore = <String, List<Map<String, dynamic>>>{};

  // Create some events
  final userId = UuidValue.generate();
  final events = [
    UserRegisteredEvent(
      userId: userId,
      email: 'alice@example.com',
      fullName: 'Alice Smith',
      organizationId: 'org-456',
    ),
    UserEmailVerifiedEvent(
      userId: userId,
      email: 'alice@example.com',
    ),
    UserProfileUpdatedEvent(
      userId: userId,
      fullName: 'Alice Johnson',
    ),
  ];

  print('Storing ${events.length} events for user ${userId.uuid}...');

  // Store events (serialize to JSON)
  final streamId = 'user-${userId.uuid}';
  eventStore[streamId] = events.map((e) {
    // Cast to specific event type to access toJson()
    if (e is UserRegisteredEvent) return e.toJson();
    if (e is UserEmailVerifiedEvent) return e.toJson();
    if (e is UserProfileUpdatedEvent) return e.toJson();
    throw Exception('Unknown event type: ${e.runtimeType}');
  }).toList();

  print('✅ Events stored in stream: $streamId');

  // Retrieve events (deserialize from JSON)
  print('\nRetrieving events from store...');
  final storedEvents = eventStore[streamId]!;

  for (var i = 0; i < storedEvents.length; i++) {
    final json = storedEvents[i];
    final eventType = json['eventType'] as String;

    print('  Event ${i + 1}: $eventType');
    print('    Occurred at: ${json['occurredAt']}');
    print('    Aggregate ID: ${json['aggregateId']}');
  }

  print('\n✅ Event store simulation complete!\n');
}

/// Simulate sending events to a message queue
void _messageQueueSimulation() {
  print('📨 Message Queue Simulation');
  print('=' * 40);

  // Simulate a message queue
  final messageQueue = <String>[];

  // Create events
  final orderId = UuidValue.generate();
  final events = [
    OrderPlacedEvent(
      orderId: orderId,
      customerId: 'customer-123',
      totalAmount: 299.99,
      currency: 'USD',
      itemCount: 3,
    ),
    OrderShippedEvent(
      orderId: orderId,
      trackingNumber: '1Z999AA10123456784',
      carrier: 'UPS',
      estimatedDelivery: DateTime.now().add(Duration(days: 3)),
    ),
  ];

  print('Publishing ${events.length} events to message queue...');

  // Publish events (serialize to JSON strings)
  for (final event in events) {
    Map<String, dynamic> json;
    if (event is OrderPlacedEvent) {
      json = event.toJson();
    } else if (event is OrderShippedEvent) {
      json = event.toJson();
    } else {
      throw Exception('Unknown event type: ${event.runtimeType}');
    }
    final message = jsonEncode(json);
    messageQueue.add(message);
    print('  ✓ Published: ${event.runtimeType}');
  }

  print('\nMessage queue contains ${messageQueue.length} messages');

  // Consume events (deserialize from JSON strings)
  print('\nConsuming messages from queue...');

  for (var i = 0; i < messageQueue.length; i++) {
    final message = messageQueue[i];
    final json = jsonDecode(message) as Map<String, dynamic>;
    final eventType = json['eventType'] as String;

    print('  Message ${i + 1}: $eventType');
    print('    Aggregate ID: ${json['aggregateId']}');

    // In a real system, you'd route to appropriate handlers based on eventType
    switch (eventType) {
      case 'OrderPlacedEvent':
        print('    → Routing to inventory service');
        print('    → Routing to payment service');
        break;
      case 'OrderShippedEvent':
        print('    → Routing to notification service');
        print('    → Routing to tracking service');
        break;
    }
  }

  print('\n✅ Message queue simulation complete!\n');
}

// Example serializable events

class UserRegisteredEvent extends DomainEvent {
  final String email;
  final String fullName;
  final String organizationId;

  UserRegisteredEvent({
    required UuidValue userId,
    required this.email,
    required this.fullName,
    required this.organizationId,
  }) : super(
          aggregateId: userId,
          context: {
            'organizationId': organizationId,
            'email': email,
          },
        );

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'eventType': 'UserRegisteredEvent',
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'email': email,
        'fullName': fullName,
        'organizationId': organizationId,
        'context': context,
      };

  /// Deserialize from JSON
  factory UserRegisteredEvent.fromJson(Map<String, dynamic> json) {
    return UserRegisteredEvent(
      userId: UuidValue.fromString(json['aggregateId'] as String),
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      organizationId: json['organizationId'] as String,
    );
  }
}

class UserEmailVerifiedEvent extends DomainEvent {
  final String email;

  UserEmailVerifiedEvent({
    required UuidValue userId,
    required this.email,
  }) : super(aggregateId: userId);

  Map<String, dynamic> toJson() => {
        'eventType': 'UserEmailVerifiedEvent',
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'email': email,
      };

  factory UserEmailVerifiedEvent.fromJson(Map<String, dynamic> json) {
    return UserEmailVerifiedEvent(
      userId: UuidValue.fromString(json['aggregateId'] as String),
      email: json['email'] as String,
    );
  }
}

class UserProfileUpdatedEvent extends DomainEvent {
  final String fullName;

  UserProfileUpdatedEvent({
    required UuidValue userId,
    required this.fullName,
  }) : super(aggregateId: userId);

  Map<String, dynamic> toJson() => {
        'eventType': 'UserProfileUpdatedEvent',
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'fullName': fullName,
      };

  factory UserProfileUpdatedEvent.fromJson(Map<String, dynamic> json) {
    return UserProfileUpdatedEvent(
      userId: UuidValue.fromString(json['aggregateId'] as String),
      fullName: json['fullName'] as String,
    );
  }
}

class OrderPlacedEvent extends DomainEvent {
  final String customerId;
  final double totalAmount;
  final String currency;
  final int itemCount;

  OrderPlacedEvent({
    required UuidValue orderId,
    required this.customerId,
    required this.totalAmount,
    required this.currency,
    required this.itemCount,
  }) : super(
          aggregateId: orderId,
          context: {
            'customerId': customerId,
            'totalAmount': totalAmount,
            'currency': currency,
          },
        );

  Map<String, dynamic> toJson() => {
        'eventType': 'OrderPlacedEvent',
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'customerId': customerId,
        'totalAmount': totalAmount,
        'currency': currency,
        'itemCount': itemCount,
        'context': context,
      };

  factory OrderPlacedEvent.fromJson(Map<String, dynamic> json) {
    return OrderPlacedEvent(
      orderId: UuidValue.fromString(json['aggregateId'] as String),
      customerId: json['customerId'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      itemCount: json['itemCount'] as int,
    );
  }
}

class OrderShippedEvent extends DomainEvent {
  final String trackingNumber;
  final String carrier;
  final DateTime estimatedDelivery;

  OrderShippedEvent({
    required UuidValue orderId,
    required this.trackingNumber,
    required this.carrier,
    required this.estimatedDelivery,
  }) : super(
          aggregateId: orderId,
          context: {
            'trackingNumber': trackingNumber,
            'carrier': carrier,
          },
        );

  Map<String, dynamic> toJson() => {
        'eventType': 'OrderShippedEvent',
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'trackingNumber': trackingNumber,
        'carrier': carrier,
        'estimatedDelivery': estimatedDelivery.toIso8601String(),
        'context': context,
      };

  factory OrderShippedEvent.fromJson(Map<String, dynamic> json) {
    return OrderShippedEvent(
      orderId: UuidValue.fromString(json['aggregateId'] as String),
      trackingNumber: json['trackingNumber'] as String,
      carrier: json['carrier'] as String,
      estimatedDelivery: DateTime.parse(json['estimatedDelivery'] as String),
    );
  }
}
