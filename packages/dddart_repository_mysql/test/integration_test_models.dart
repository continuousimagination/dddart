/// Domain models for integration testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:mysql1/mysql1.dart' show Blob;

part 'integration_test_models.g.dart';

// ============================================================================
// Simple Product - Basic CRUD Testing
// ============================================================================

/// Simple product aggregate for basic CRUD testing.
@Serializable()
@GenerateMysqlRepository()
class SimpleProduct extends AggregateRoot {
  SimpleProduct({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final double price;
}

// ============================================================================
// Order with Items - Entity Collection Testing
// ============================================================================

/// Order aggregate with entity collection for testing object graphs.
@Serializable()
@GenerateMysqlRepository(tableName: 'orders')
class Order extends AggregateRoot {
  Order({
    required this.customerName,
    required this.items,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String customerName;
  final List<OrderItem> items;
}

/// Order item entity for testing entity relationships.
@Serializable()
class OrderItem extends Entity {
  OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
}

// ============================================================================
// Customer with Address - Value Object Testing
// ============================================================================

/// Customer aggregate for testing value object embedding.
@Serializable()
@GenerateMysqlRepository()
class Customer extends AggregateRoot {
  Customer({
    required this.name,
    required this.email,
    required this.shippingAddress,
    this.billingAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final Email email;
  final Address shippingAddress;
  final Address? billingAddress;
}

/// Email value object.
@Serializable()
class Email extends Value {
  const Email({required this.value});

  final String value;

  @override
  List<Object?> get props => [value];
}

/// Address value object for testing embedding.
@Serializable()
class Address extends Value {
  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  final String street;
  final String city;
  final String state;
  final String zipCode;

  @override
  List<Object?> get props => [street, city, state, zipCode];
}

// ============================================================================
// Product with Custom Repository - Custom Methods Testing
// ============================================================================

/// Product aggregate for custom repository testing.
@Serializable()
@GenerateMysqlRepository(implements: CustomProductRepository)
class Product extends AggregateRoot {
  Product({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final double price;
}

/// Custom repository interface for testing custom methods.
abstract class CustomProductRepository implements Repository<Product> {
  Future<List<Product>> findByMinPrice(double minPrice);
  Future<int> countProducts();
}

/// Implementation of custom repository.
class CustomProductRepositoryImpl extends ProductMysqlRepositoryBase
    implements CustomProductRepository {
  CustomProductRepositoryImpl(super.connection);

  @override
  Future<List<Product>> findByMinPrice(double minPrice) async {
    final rows = await _connection.query(
      'SELECT BIN_TO_UUID(id) as id, name, price, createdAt, updatedAt '
      'FROM product WHERE price >= ?',
      [minPrice],
    );

    return rows.map((row) {
      final json = _rowToJson(row);
      return _serializer.fromJson(json);
    }).toList();
  }

  @override
  Future<int> countProducts() async {
    final result = await _connection.query(
      'SELECT COUNT(*) as count FROM product',
    );

    return result.first['count']! as int;
  }
}
