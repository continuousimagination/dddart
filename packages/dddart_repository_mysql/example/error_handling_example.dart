// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql_example/domain/address.dart';
import 'package:dddart_repository_mysql_example/domain/money.dart';
import 'package:dddart_repository_mysql_example/domain/order.dart';
import 'package:dddart_repository_mysql_example/domain/order_item.dart';
import 'package:dddart_repository_mysql_example/mysql_example_connection.dart';

/// Error handling example demonstrating proper exception handling patterns.
///
/// This example shows:
/// - Handling RepositoryException.notFound
/// - Handling connection errors
/// - Proper try-catch patterns
/// - Error type checking and recovery
///
/// Prerequisites:
/// - MySQL configured through MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE,
///   MYSQL_USER, and MYSQL_PASSWORD
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

  final connection = createMysqlExampleConnection();

  try {
    await connection.open();
    final orderRepo = OrderMysqlRepository(connection);
    await orderRepo.createTables();

    // Try to get a non-existent order
    final nonExistentId = UuidValue.generate();
    print('   Attempting to retrieve non-existent order: $nonExistentId');

    try {
      await orderRepo.getById(nonExistentId);
      throw StateError('Expected RepositoryException.notFound');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Caught RepositoryException.notFound');
        print('   Message: ${e.message}');
      } else {
        rethrow;
      }
    }

    // Try to delete a non-existent order
    print('\n   Attempting to delete non-existent order: $nonExistentId');
    try {
      await orderRepo.deleteById(nonExistentId);
      throw StateError('Expected RepositoryException.notFound');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Caught RepositoryException.notFound');
        print('   Message: ${e.message}');
      } else {
        rethrow;
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
  final unavailablePort = mysqlExamplePort + 10000;
  final connection = createMysqlExampleConnection(
    port: unavailablePort,
  );

  print(
    '   Attempting to connect to $mysqlExampleHost:$unavailablePort '
    '(should fail)...',
  );
  try {
    await connection.open();
    await connection.close();
    throw StateError(
      'Connection unexpectedly succeeded on '
      '$mysqlExampleHost:$unavailablePort',
    );
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.connection) {
      print('   ✓ Caught RepositoryException.connection');
      print('   Message: ${e.message}');
    } else {
      rethrow;
    }
  } catch (e) {
    if (e is StateError) rethrow;
    print('   ✓ Caught connection error');
    print('   Error type: ${e.runtimeType}');
    print('   Message: ${e.toString().split('\n').first}');
  }
}

/// Demonstrates proper error handling patterns with recovery.
Future<void> _demonstrateProperErrorHandling() async {
  print('3. Demonstrating proper error handling with recovery...');

  final connection = createMysqlExampleConnection();

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
        rethrow;
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
        case RepositoryExceptionType.unauthorized:
          print('   ✓ Handled: Unauthorized access');
        case RepositoryExceptionType.forbidden:
          print('   ✓ Handled: Forbidden operation');
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
