// ignore_for_file: avoid_print

import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'lib/domain/address.dart';
import 'lib/domain/money.dart';
import 'lib/domain/order_item.dart';
import 'lib/domain/order_with_custom_repo.dart';

/// Custom repository example demonstrating extended repository functionality.
///
/// This example shows:
/// - Defining a custom repository interface with domain-specific methods
/// - Using the generated abstract base class
/// - Implementing custom query methods using MySQL queries
/// - Using both generated CRUD methods and custom query methods
///
/// Prerequisites:
/// - MySQL running on localhost:3306
/// - Database 'dddart_example' created
/// - User 'root' with password 'password' (or update connection parameters)
Future<void> main() async {
  print('=== Custom Repository Example ===\n');

  // Step 1: Create and open connection
  print('1. Connecting to MySQL...');
  final connection = MysqlConnection(
    host: 'localhost',
    port: 3306,
    database: 'dddart_example',
    user: 'root',
    password: 'password',
  );

  try {
    await connection.open();
    print('   ✓ Connected to MySQL\n');

    // Step 2: Create repository with custom implementation
    print('2. Creating custom repository...');
    final orderRepo = OrderWithCustomRepoMysqlRepository(connection);
    print('   ✓ Custom repository created\n');

    // Step 3: Create database tables
    print('3. Creating database tables...');
    await orderRepo.createTables();
    print('   ✓ Tables created\n');

    // Step 4: Create and save multiple orders
    print('4. Creating and saving multiple orders...');
    final orders = [
      OrderWithCustomRepo(
        customerName: 'Alice Johnson',
        shippingAddress: const Address(
          street: '123 Main St',
          city: 'Boston',
          state: 'MA',
          postalCode: '02101',
          country: 'USA',
        ),
        items: [
          OrderItem(
            productName: 'Laptop',
            quantity: 1,
            unitPrice: const Money(amount: 999.99, currency: 'USD'),
          ),
        ],
      ),
      OrderWithCustomRepo(
        customerName: 'Bob Smith',
        shippingAddress: const Address(
          street: '456 Oak Ave',
          city: 'Seattle',
          state: 'WA',
          postalCode: '98101',
          country: 'USA',
        ),
        items: [
          OrderItem(
            productName: 'Mouse',
            quantity: 2,
            unitPrice: const Money(amount: 29.99, currency: 'USD'),
          ),
          OrderItem(
            productName: 'Keyboard',
            quantity: 1,
            unitPrice: const Money(amount: 79.99, currency: 'USD'),
          ),
        ],
      ),
      OrderWithCustomRepo(
        customerName: 'Alice Johnson',
        shippingAddress: const Address(
          street: '789 Pine Rd',
          city: 'Portland',
          state: 'OR',
          postalCode: '97201',
          country: 'USA',
        ),
        items: [
          OrderItem(
            productName: 'Monitor',
            quantity: 1,
            unitPrice: const Money(amount: 299.99, currency: 'USD'),
          ),
        ],
      ),
    ];

    for (final order in orders) {
      await orderRepo.save(order);
      print('   ✓ Saved: ${order.customerName} - '
          '\$${order.totalAmount.amount.toStringAsFixed(2)}');
    }
    print('');

    // Step 5: Use custom query method - findByCustomerName
    print('5. Finding orders by customer name (custom method)...');
    final aliceOrders = await orderRepo.findByCustomerName('Alice Johnson');
    print('   ✓ Found ${aliceOrders.length} orders for Alice Johnson:');
    for (final order in aliceOrders) {
      print('     - Order ${order.id}: '
          '\$${order.totalAmount.amount.toStringAsFixed(2)}');
      print('       Shipping to: ${order.shippingAddress.city}, '
          '${order.shippingAddress.state}');
    }
    print('');

    // Step 6: Use custom query method - findByMinimumAmount
    print('6. Finding orders with minimum amount (custom method)...');
    final highValueOrders = await orderRepo.findByMinimumAmount(200);
    print('   ✓ Found ${highValueOrders.length} orders >= \$200.00:');
    for (final order in highValueOrders) {
      print('     - ${order.customerName}: '
          '\$${order.totalAmount.amount.toStringAsFixed(2)}');
    }
    print('');

    // Step 7: Use generated CRUD method - getById
    print('7. Retrieving order by ID (generated method)...');
    final orderById = await orderRepo.getById(orders[0].id);
    print('   ✓ Retrieved: ${orderById.customerName}');
    print('   Total: \$${orderById.totalAmount.amount.toStringAsFixed(2)}');
    print('');

    // Step 8: Test custom query with no results
    print('8. Testing custom query with no results...');
    final notFound = await orderRepo.findByCustomerName('Nonexistent Customer');
    if (notFound.isEmpty) {
      print('   ✓ Correctly returned empty list for non-existent customer');
    } else {
      print('   ✗ Unexpected result');
    }
    print('');

    // Step 9: Clean up - delete all test orders
    print('9. Cleaning up test data...');
    for (final order in orders) {
      await orderRepo.deleteById(order.id);
    }
    print('   ✓ All test orders deleted');

    print('\n=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Step 10: Close connection
    print('\n10. Closing connection...');
    await connection.close();
    print('   ✓ Connection closed');
  }
}
