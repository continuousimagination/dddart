/// Complex order aggregate with nested entities and value objects.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'complex_order.g.dart';

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
class OrderItem {
  /// Creates an order item entity.
  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  /// The product ID.
  final UuidValue productId;

  /// The product name.
  final String productName;

  /// Quantity ordered.
  final int quantity;

  /// Price per item (embedded value object).
  final Money unitPrice;
}

/// Aggregate root representing an order with nested entities and value objects.
@Serializable()
@GenerateSqliteRepository(tableName: 'orders')
class Order extends AggregateRoot {
  /// Creates an order aggregate.
  Order({
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    required this.shippingAddress,
    required this.billingAddress,
    required this.items,
    required this.status,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Customer ID (reference to another aggregate).
  final UuidValue customerId;

  /// Customer name for display.
  final String customerName;

  /// Total order amount (embedded value object).
  final Money totalAmount;

  /// Shipping address (embedded value object).
  final Address shippingAddress;

  /// Billing address (embedded value object).
  final Address billingAddress;

  /// Order items (nested entities in separate table).
  final List<OrderItem> items;

  /// Order status.
  final String status;
}
