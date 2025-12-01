// ignore_for_file: avoid_print

import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'lib/domain/address.dart';
import 'lib/domain/money.dart';
import 'lib/domain/order.dart';
import 'lib/domain/order_item.dart';

/// Connection management example demonstrating connection lifecycle.
///
/// This example shows:
/// - Creating a connection with custom parameters
/// - Opening and closing connections
/// - Connection state checking
/// - Connection pooling configuration
/// - Transaction management
/// - Proper resource cleanup
///
/// Prerequisites:
/// - MySQL running on localhost:3306
/// - Database 'dddart_example' created
/// - User 'root' with password 'password' (or update connection parameters)
Future<void> main() async {
  print('=== Connection Management Example ===\n');

  await _demonstrateBasicConnectionLifecycle();
  print('');

  await _demonstrateConnectionPooling();
  print('');

  await _demonstrateTransactionManagement();
  print('');

  print('=== Example completed successfully ===');
}

/// Demonstrates basic connection lifecycle management.
Future<void> _demonstrateBasicConnectionLifecycle() async {
  print('1. Demonstrating basic connection lifecycle...');

  // Create connection with custom parameters
  print('   Creating connection...');
  final connection = MysqlConnection(
    host: 'localhost',
    port: 3306,
    database: 'dddart_example',
    user: 'root',
    password: 'password',
  );
  print('   ✓ Connection created (not yet open)');
  print('   Is open: ${connection.isOpen}');

  // Open the connection
  print('\n   Opening connection...');
  await connection.open();
  print('   ✓ Connection opened');
  print('   Is open: ${connection.isOpen}');

  // Use the connection
  print('\n   Using connection...');
  final orderRepo = OrderMysqlRepository(connection);
  await orderRepo.createTables();
  print('   ✓ Tables created successfully');

  // Close the connection
  print('\n   Closing connection...');
  await connection.close();
  print('   ✓ Connection closed');
  print('   Is open: ${connection.isOpen}');

  // Try to use closed connection (should fail)
  print('\n   Attempting to use closed connection...');
  try {
    await connection.execute('SELECT 1');
    print('   ✗ Should have thrown StateError');
  } catch (e) {
    if (e is StateError) {
      print('   ✓ Caught StateError: ${e.message}');
    } else {
      rethrow;
    }
  }
}

/// Demonstrates connection pooling configuration.
Future<void> _demonstrateConnectionPooling() async {
  print('2. Demonstrating connection pooling...');

  // Create connection with larger pool for high concurrency
  print('   Creating connection with pool size 10...');
  final connection = MysqlConnection(
    host: 'localhost',
    port: 3306,
    database: 'dddart_example',
    user: 'root',
    password: 'password',
    maxConnections: 10, // Larger pool for concurrent operations
  );

  try {
    await connection.open();
    print('   ✓ Connection pool opened');

    final orderRepo = OrderMysqlRepository(connection);
    await orderRepo.createTables();

    // Simulate concurrent operations
    print('\n   Executing concurrent operations...');
    final futures = <Future<void>>[];
    for (var i = 0; i < 5; i++) {
      futures.add(_createAndSaveOrder(orderRepo, i));
    }

    await Future.wait(futures);
    print('   ✓ All concurrent operations completed');

    // Clean up
    print('\n   Cleaning up test data...');
    await connection.execute('DELETE FROM orders');
    await connection.execute('DELETE FROM order_items');
    print('   ✓ Test data cleaned up');
  } finally {
    await connection.close();
    print('\n   ✓ Connection pool closed');
  }
}

/// Helper function to create and save an order.
Future<void> _createAndSaveOrder(
  OrderMysqlRepository repo,
  int index,
) async {
  final order = Order(
    customerName: 'Customer $index',
    shippingAddress: Address(
      street: '$index Main St',
      city: 'City $index',
      state: 'ST',
      postalCode: '${10000 + index}',
      country: 'USA',
    ),
    items: [
      OrderItem(
        productName: 'Product $index',
        quantity: index + 1,
        unitPrice: Money(amount: 10.0 * (index + 1), currency: 'USD'),
      ),
    ],
  );

  await repo.save(order);
  print('     ✓ Saved order $index');
}

/// Demonstrates transaction management.
Future<void> _demonstrateTransactionManagement() async {
  print('3. Demonstrating transaction management...');

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

    // Successful transaction
    print('   Executing successful transaction...');
    await connection.transaction(() async {
      final order1 = Order(
        customerName: 'Transaction Customer 1',
        shippingAddress: const Address(
          street: '123 Transaction St',
          city: 'Transaction City',
          state: 'TC',
          postalCode: '12345',
          country: 'USA',
        ),
        items: [
          OrderItem(
            productName: 'Transaction Product',
            quantity: 1,
            unitPrice: const Money(amount: 50, currency: 'USD'),
          ),
        ],
      );

      await orderRepo.save(order1);
      print('     ✓ Saved order 1 in transaction');

      final order2 = Order(
        customerName: 'Transaction Customer 2',
        shippingAddress: const Address(
          street: '456 Transaction Ave',
          city: 'Transaction City',
          state: 'TC',
          postalCode: '12346',
          country: 'USA',
        ),
        items: [
          OrderItem(
            productName: 'Transaction Product 2',
            quantity: 2,
            unitPrice: const Money(amount: 25, currency: 'USD'),
          ),
        ],
      );

      await orderRepo.save(order2);
      print('     ✓ Saved order 2 in transaction');
    });
    print('   ✓ Transaction committed successfully');

    // Failed transaction (should rollback)
    print('\n   Executing failed transaction (will rollback)...');
    try {
      await connection.transaction(() async {
        final order3 = Order(
          customerName: 'Rollback Customer',
          shippingAddress: const Address(
            street: '789 Rollback Rd',
            city: 'Rollback City',
            state: 'RC',
            postalCode: '12347',
            country: 'USA',
          ),
          items: [
            OrderItem(
              productName: 'Rollback Product',
              quantity: 1,
              unitPrice: const Money(amount: 100, currency: 'USD'),
            ),
          ],
        );

        await orderRepo.save(order3);
        print('     ✓ Saved order 3 in transaction');

        // Simulate an error
        throw Exception('Simulated error - transaction should rollback');
      });
    } catch (e) {
      print('   ✓ Transaction rolled back due to error');
      print('   Error: ${e.toString().split('\n').first}');
    }

    // Verify rollback
    print('\n   Verifying transaction rollback...');
    final rows = await connection.query(
      "SELECT COUNT(*) as count FROM orders WHERE customerName = 'Rollback Customer'",
    );
    final count = rows.first['count']! as int;
    if (count == 0) {
      print('   ✓ Rollback verified - order 3 was not saved');
    } else {
      print('   ✗ Rollback failed - order 3 was saved');
    }

    // Clean up
    print('\n   Cleaning up test data...');
    await connection.execute('DELETE FROM orders');
    await connection.execute('DELETE FROM order_items');
    print('   ✓ Test data cleaned up');
  } finally {
    await connection.close();
    print('\n   ✓ Connection closed');
  }
}
