/// Test models for SQLite repository property-based testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';

/// Value object representing money with amount and currency.
@Serializable()
class Money extends Value {
  /// Creates a money value object.
  const Money({
    required this.amount,
    required this.currency,
  });

  /// The monetary amount.
  final double amount;

  /// The currency code (e.g., 'USD', 'EUR').
  final String currency;

  @override
  List<Object?> get props => [amount, currency];
}

/// Value object representing an address.
@Serializable()
class Address extends Value {
  /// Creates an address value object.
  const Address({
    required this.street,
    required this.city,
    required this.country,
  });

  /// Street address.
  final String street;

  /// City name.
  final String city;

  /// Country name.
  final String country;

  @override
  List<Object?> get props => [street, city, country];
}

/// Entity representing an order item within an order aggregate.
@Serializable()
class OrderItem extends Entity {
  /// Creates an order item entity.
  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// The product ID.
  final UuidValue productId;

  /// Quantity ordered.
  final int quantity;

  /// Price per item.
  final Money price;
}

/// Aggregate root representing an order with nested entities and value objects.
@Serializable()
@GenerateSqliteRepository(tableName: 'orders')
class Order extends AggregateRoot {
  /// Creates an order aggregate.
  Order({
    required this.customerId,
    required this.totalAmount,
    required this.shippingAddress,
    required this.items,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Customer ID (reference to another aggregate).
  final UuidValue customerId;

  /// Total order amount (embedded value object).
  final Money totalAmount;

  /// Shipping address (embedded value object).
  final Address shippingAddress;

  /// Order items (nested entities).
  final List<OrderItem> items;
}

/// Simple aggregate for basic testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_users')
class TestUser extends AggregateRoot {
  /// Creates a test user.
  TestUser({
    required this.name,
    required this.email,
    required this.isActive,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's name.
  final String name;

  /// User's email address.
  final String email;

  /// Whether the user is active.
  final bool isActive;
}

/// Aggregate with nullable value object for testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_products')
class TestProduct extends AggregateRoot {
  /// Creates a test product.
  TestProduct({
    required this.name,
    required this.price,
    this.discount,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Product name.
  final String name;

  /// Product price (embedded value object).
  final Money price;

  /// Optional discount (nullable embedded value object).
  final Money? discount;
}
