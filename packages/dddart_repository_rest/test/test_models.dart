/// Test models and utilities for REST repository testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';
part 'test_models_impl.dart';

/// Simple test aggregate for basic CRUD testing.
@Serializable()
@GenerateRestRepository(resourcePath: '/users')
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

/// Test aggregate with custom resource path.
@Serializable()
@GenerateRestRepository(resourcePath: '/products')
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
@GenerateRestRepository(
  resourcePath: '/orders',
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
@GenerateRestRepository(resourcePath: '/accounts')
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
