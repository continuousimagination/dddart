// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'lib/domain/address.dart';
import 'lib/domain/money.dart';
import 'lib/domain/order.dart';
import 'lib/domain/order_item.dart';

/// Error handling example demonstrating proper exception handling patterns.
///
/// This example shows:
/// - Handling RepositoryException.notFound
/// - Handling connection errors
/// - Proper try-catch patterns
/// - Error type checking and recovery
///
/// Prerequisites:
/// - MySQL running on localhost:3306 for successful connection test
/// - MySQL NOT running on localhost:3307 for connection error test
/// - Database 'dddart_example' created
Future<void> main() async {
  print('=== Error Handling Example ===\n');

  await _demonstrateNotFoundError();
  print('');

  await _demonstrateConnectionError();
  print('');

  await _demonstrateProperErrorHandling();
  print('');

  print('=== Example completed successfully ===');
}

/// Demonstrates handling of RepositoryException.notFound.
Future<void> _demonstrateNotFoundError() async {
  print('1. Demonstrating NOT FOUND error handling...');

  final connection = MysqlConnection(
    host: 'localhost',
    port: 3306,
    database: 'dddart_example',
    user: 'root',
    password: 'password',
  );

  try {
    await connection.open();
    final orderRepo = OrderMysqlRepository(connection);
    await orderRepo.createTables();

    // Try to get a non-existent order
    final nonExistentId = UuidValue.generate();
    print('   Attempting to retrieve non-existent order: $nonExistentId');

    try {
      await orderRepo.getById(nonExistentId);
      print('   ✗ Should have thrown RepositoryException.notFound');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Caught RepositoryException.notFound');
        print('   Message: ${e.message}');
      } else {
        print('   ✗ Unexpected exception type: ${e.type}');
      }
    }

    // Try to delete a non-existent order
    print('\n   Attempting to delete non-existent order: $nonExistentId');
    try {
      await orderRepo.deleteById(nonExistentId);
      print('   ✗ Should have thrown RepositoryException.notFound');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Caught RepositoryException.notFound');
        print('   Message: ${e.message}');
      } else {
        print('   ✗ Unexpected exception type: ${e.type}');
      }
    }
  } finally {
    await connection.close();
  }
}

/// Demonstrates handling of connection errors.
Future<void> _demonstrateConnectionError() async {
  print('2. Demonstrating CONNECTION error handling...');

  // Try to connect to a non-existent MySQL instance
  final connection = MysqlConnection(
    host: 'localhost',
    port: 3307, // Wrong port - MySQL not running here
    database: 'dddart_example',
    user: 'root',
    password: 'password',
  );

  print('   Attempting to connect to localhost:3307 (should fail)...');
  try {
    await connection.open();
    print('   ✗ Connection should have failed');
    await connection.close();
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.connection) {
      print('   ✓ Caught RepositoryException.connection');
      print('   Message: ${e.message}');
    } else {
      print('   ✗ Unexpected exception type: ${e.type}');
    }
  } catch (e) {
    print('   ✓ Caught connection error');
    print('   Error type: ${e.runtimeType}');
    print('   Message: ${e.toString().split('\n').first}');
  }
}

/// Demonstrates proper error handling patterns with recovery.
Future<void> _demonstrateProperErrorHandling() async {
  print('3. Demonstrating proper error handling with recovery...');

  final connection = MysqlConnection(
    host: 'localhost',
    port: 3306,
    database: 'dddart_example',
    user: 'root',
    password: 'password',
  );

  try {
    await connection.open();
    final orderRepo = OrderMysqlRepository(connection);
    await orderRepo.createTables();

    // Create a test order
    final order = Order(
      customerName: 'Test Customer',
      shippingAddress: const Address(
        street: '123 Test St',
        city: 'Test City',
        state: 'TS',
        postalCode: '12345',
        country: 'USA',
      ),
      items: [
        OrderItem(
          productName: 'Test Product',
          quantity: 1,
          unitPrice: const Money(amount: 10, currency: 'USD'),
        ),
      ],
    );
    await orderRepo.save(order);
    print('   ✓ Created test order: ${order.id}');

    // Pattern 1: Try to get order, handle not found gracefully
    print('\n   Pattern 1: Graceful handling with default value');
    final orderId = UuidValue.generate(); // Non-existent ID
    Order? retrievedOrder;
    try {
      retrievedOrder = await orderRepo.getById(orderId);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Order not found, using default');
        retrievedOrder = null;
      } else {
        print('   ✗ Unexpected error: ${e.message}');
        rethrow;
      }
    }
    print('   Result: ${retrievedOrder?.customerName ?? 'No order'}');

    // Pattern 2: Try operation, log error, continue
    print('\n   Pattern 2: Log and continue');
    try {
      await orderRepo.deleteById(UuidValue.generate());
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Delete failed (not found), continuing...');
      } else {
        print('   ✗ Unexpected error: ${e.message}');
      }
    }

    // Pattern 3: Specific error type handling
    print('\n   Pattern 3: Specific error type handling');
    try {
      await orderRepo.getById(UuidValue.generate());
    } on RepositoryException catch (e) {
      switch (e.type) {
        case RepositoryExceptionType.notFound:
          print('   ✓ Handled: Resource not found');
        case RepositoryExceptionType.connection:
          print('   ✓ Handled: Connection issue');
        case RepositoryExceptionType.timeout:
          print('   ✓ Handled: Operation timed out');
        case RepositoryExceptionType.duplicate:
          print('   ✓ Handled: Duplicate key');
        case RepositoryExceptionType.constraint:
          print('   ✓ Handled: Constraint violation');
        case RepositoryExceptionType.unknown:
          print('   ✓ Handled: Unknown error');
      }
    }

    // Clean up
    await orderRepo.deleteById(order.id);
    print('\n   ✓ Cleaned up test data');
  } finally {
    await connection.close();
  }
}
