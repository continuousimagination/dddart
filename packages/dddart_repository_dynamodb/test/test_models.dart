/// Test models and utilities for DynamoDB repository testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';
part 'test_models_impl.dart';

/// Simple test aggregate for basic CRUD testing.
@Serializable()
@GenerateDynamoRepository(tableName: 'test_users')
class TestUser extends AggregateRoot {
  /// Creates a test user.
  TestUser({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's name.
  final String name;

  /// User's email address.
  final String email;
}

/// Test aggregate with custom table name.
@Serializable()
@GenerateDynamoRepository(tableName: 'custom_products')
class TestProduct extends AggregateRoot {
  /// Creates a test product.
  TestProduct({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Product name.
  final String name;

  /// Product price.
  final double price;
}

/// Custom repository interface for testing abstract base class generation.
abstract interface class TestOrderRepository implements Repository<TestOrder> {
  /// Finds orders by customer ID.
  Future<List<TestOrder>> findByCustomerId(String customerId);

  /// Finds an order by order number.
  Future<TestOrder?> findByOrderNumber(String orderNumber);
}

/// Test aggregate with custom repository interface.
@Serializable()
@GenerateDynamoRepository(
  tableName: 'test_orders',
  implements: TestOrderRepository,
)
class TestOrder extends AggregateRoot {
  /// Creates a test order.
  TestOrder({
    required this.orderNumber,
    required this.customerId,
    required this.total,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Order number.
  final String orderNumber;

  /// Customer ID.
  final String customerId;

  /// Order total.
  final double total;
}

/// Test aggregate for additional testing scenarios.
@Serializable()
@GenerateDynamoRepository(tableName: 'test_accounts')
class TestAccount extends AggregateRoot {
  /// Creates a test account.
  TestAccount({
    required this.accountName,
    required this.accountType,
    required this.balance,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Account name.
  final String accountName;

  /// Account type.
  final String accountType;

  /// Account balance.
  final double balance;
}
