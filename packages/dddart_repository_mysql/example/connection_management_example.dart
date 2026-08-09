// ignore_for_file: avoid_print

import 'package:dddart_repository_mysql_example/domain/address.dart';
import 'package:dddart_repository_mysql_example/domain/money.dart';
import 'package:dddart_repository_mysql_example/domain/order.dart';
import 'package:dddart_repository_mysql_example/domain/order_item.dart';
import 'package:dddart_repository_mysql_example/mysql_example_connection.dart';

/// Connection management example demonstrating connection lifecycle.
///
/// This example shows:
/// - Creating a connection with custom parameters
/// - Opening and closing connections
/// - Connection state checking
/// - Reusing one connection for multiple operations
/// - Transaction management
/// - Proper resource cleanup
///
/// Prerequisites:
/// - MySQL configured through MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE,
///   MYSQL_USER, and MYSQL_PASSWORD (documented local defaults are used)
Future<void> main() async {
  print('=== Connection Management Example ===\n');

  await _demonstrateBasicConnectionLifecycle();
  print('');

  await _demonstrateSingleConnectionReuse();
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
  final connection = createMysqlExampleConnection();
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
  Object? closedConnectionError;
  try {
    await connection.execute('SELECT 1');
  } catch (e) {
    closedConnectionError = e;
  }
  if (closedConnectionError case final StateError error) {
    print('   ✓ Caught StateError: ${error.message}');
  } else if (closedConnectionError != null) {
    throw closedConnectionError;
  } else {
    throw StateError('A closed connection unexpectedly executed a query');
  }
}

/// Demonstrates reusing the same connection for multiple operations.
Future<void> _demonstrateSingleConnectionReuse() async {
  print('2. Demonstrating single-connection reuse...');

  print('   Creating one connection...');
  final connection = createMysqlExampleConnection();

  try {
    await connection.open();
    print('   ✓ Connection opened');

    final orderRepo = OrderMysqlRepository(connection);
    await orderRepo.createTables();

    print('\n   Executing operations on the same connection...');
    for (var i = 0; i < 5; i++) {
      await _createAndSaveOrder(orderRepo, i);
    }
    print('   ✓ All operations completed');

    // Clean up
    print('\n   Cleaning up test data...');
    await connection.execute('DELETE FROM orders');
    print('   ✓ Test data cleaned up');
  } finally {
    await connection.close();
    print('\n   ✓ Connection closed');
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

  final connection = createMysqlExampleConnection();

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
      throw StateError('Rollback failed: order 3 was saved');
    }

    // Clean up
    print('\n   Cleaning up test data...');
    await connection.execute('DELETE FROM orders');
    print('   ✓ Test data cleaned up');
  } finally {
    await connection.close();
    print('\n   ✓ Connection closed');
  }
}
