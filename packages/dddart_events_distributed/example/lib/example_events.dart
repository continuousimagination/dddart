/// Example domain events for demonstrating event registry generation.
library;

import 'package:dddart/dddart.dart';

/// Example event: User created.
class UserCreatedEvent extends DomainEvent {
  UserCreatedEvent({
    required super.aggregateId,
    required this.email,
    required this.name,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String email;
  final String name;

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

/// Example event: Order placed.
class OrderPlacedEvent extends DomainEvent {
  OrderPlacedEvent({
    required super.aggregateId,
    required this.amount,
    required this.productId,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final double amount;
  final String productId;

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

/// Example event: Order purchased.
class OrderPurchasedEvent extends DomainEvent {
  OrderPurchasedEvent({
    required super.aggregateId,
    required this.amount,
    required this.productId,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final double amount;
  final String productId;

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

  static OrderPurchasedEvent fromJson(Map<String, dynamic> json) {
    return OrderPurchasedEvent(
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      amount: (json['amount'] as num).toDouble(),
      productId: json['productId'] as String,
      context: json['context'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Example event: Payment processed.
class PaymentProcessedEvent extends DomainEvent {
  PaymentProcessedEvent({
    required super.aggregateId,
    required this.orderId,
    required this.amount,
    required this.status,
    super.eventId,
    super.occurredAt,
    super.context,
  });

  final String orderId;
  final double amount;
  final String status;

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
