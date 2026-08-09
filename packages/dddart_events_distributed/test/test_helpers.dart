/// Test helpers for dddart_events_distributed tests.
library;

import 'package:dddart/dddart.dart';

/// Test event representing a newly created user.
class UserCreatedEvent extends DomainEvent {
  /// Creates a user-created event fixture.
  UserCreatedEvent({
    required super.aggregateId,
    required this.email,
    required this.name,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  /// The user's email address.
  final String email;

  /// The user's display name.
  final String name;

  /// Converts this fixture to JSON.
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId.toString(),
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'email': email,
      'name': name,
      'context': context,
    };
  }

  /// Restores a fixture from JSON.
  static UserCreatedEvent fromJson(Map<String, dynamic> json) {
    return UserCreatedEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      email: json['email'] as String,
      name: json['name'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Test event representing a placed order.
class OrderPlacedEvent extends DomainEvent {
  /// Creates an order-placed event fixture.
  OrderPlacedEvent({
    required super.aggregateId,
    required this.amount,
    required this.productId,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  /// The order amount.
  final double amount;

  /// The ordered product identifier.
  final String productId;

  /// Converts this fixture to JSON.
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId.toString(),
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'amount': amount,
      'productId': productId,
      'context': context,
    };
  }

  /// Restores a fixture from JSON.
  static OrderPlacedEvent fromJson(Map<String, dynamic> json) {
    return OrderPlacedEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      amount: (json['amount'] as num).toDouble(),
      productId: json['productId'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Test event representing a processed payment.
class PaymentProcessedEvent extends DomainEvent {
  /// Creates a payment-processed event fixture.
  PaymentProcessedEvent({
    required super.aggregateId,
    required this.orderId,
    required this.amount,
    required this.status,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  /// The associated order identifier.
  final String orderId;

  /// The payment amount.
  final double amount;

  /// The payment status.
  final String status;

  /// Converts this fixture to JSON.
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId.toString(),
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'orderId': orderId,
      'amount': amount,
      'status': status,
      'context': context,
    };
  }

  /// Restores a fixture from JSON.
  static PaymentProcessedEvent fromJson(Map<String, dynamic> json) {
    return PaymentProcessedEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      orderId: json['orderId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}
