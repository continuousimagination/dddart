// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql_example/domain/address.dart';
import 'package:dddart_repository_mysql_example/domain/money.dart';
import 'package:dddart_repository_mysql_example/domain/order.dart';
import 'package:dddart_repository_mysql_example/domain/order_item.dart';
import 'package:dddart_repository_mysql_example/mysql_example_connection.dart';

/// Basic CRUD example demonstrating MySQL repository usage.
///
/// This example shows:
/// - Connection setup and opening
/// - Creating database tables
/// - Creating and saving aggregates with entities and value objects
/// - Retrieving aggregates by ID
/// - Updating aggregates
/// - Deleting aggregates
/// - Connection closing
///
/// Prerequisites:
/// - MySQL configured through MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE,
///   MYSQL_USER, and MYSQL_PASSWORD (documented local defaults are used)
Future<void> main() async {
  print('=== Basic CRUD Example ===\n');

  // Step 1: Create and open connection
  print('1. Connecting to MySQL...');
  final connection = createMysqlExampleConnection();

  try {
    await connection.open();
    print('   ✓ Connected to MySQL\n');

    // Step 2: Create repository
    print('2. Creating repository...');
    final orderRepo = OrderMysqlRepository(connection);
    print('   ✓ Repository created\n');

    // Step 3: Create database tables
    print('3. Creating database tables...');
    await orderRepo.createTables();
    print('   ✓ Tables created\n');

    // Step 4: Create and save a new order
    print('4. Creating and saving a new order...');
    final order = Order(
      customerName: 'John Doe',
      shippingAddress: const Address(
        street: '123 Main St',
        city: 'Springfield',
        state: 'IL',
        postalCode: '62701',
        country: 'USA',
      ),
      billingAddress: const Address(
        street: '456 Oak Ave',
        city: 'Springfield',
        state: 'IL',
        postalCode: '62702',
        country: 'USA',
      ),
      items: [
        OrderItem(
          productName: 'Widget',
          quantity: 2,
          unitPrice: const Money(amount: 19.99, currency: 'USD'),
        ),
        OrderItem(
          productName: 'Gadget',
          quantity: 1,
          unitPrice: const Money(amount: 49.99, currency: 'USD'),
        ),
      ],
    );
    print('   Order ID: ${order.id}');
    print('   Customer: ${order.customerName}');
    print('   Items: ${order.items.length}');
    print('   Total: \$${order.totalAmount.amount.toStringAsFixed(2)}');

    await orderRepo.save(order);
    print('   ✓ Order saved to MySQL\n');

    // Step 5: Retrieve the order by ID
    print('5. Retrieving order by ID...');
    final retrievedOrder = await orderRepo.getById(order.id);
    print('   ✓ Order retrieved');
    print('   Customer: ${retrievedOrder.customerName}');
    print('   Shipping: ${retrievedOrder.shippingAddress.city}, '
        '${retrievedOrder.shippingAddress.state}');
    print('   Items: ${retrievedOrder.items.length}');
    for (var i = 0; i < retrievedOrder.items.length; i++) {
      final item = retrievedOrder.items[i];
      print('     ${i + 1}. ${item.productName} x${item.quantity} '
          '@ \$${item.unitPrice.amount}');
    }
    print(
      '   Total: \$${retrievedOrder.totalAmount.amount.toStringAsFixed(2)}\n',
    );

    // Step 6: Update the order
    print('6. Updating order...');
    final updatedOrder = Order(
      id: order.id,
      customerName: 'John Smith', // Updated name
      shippingAddress: retrievedOrder.shippingAddress,
      billingAddress: retrievedOrder.billingAddress,
      items: [
        ...retrievedOrder.items,
        OrderItem(
          productName: 'Doohickey',
          quantity: 3,
          unitPrice: const Money(amount: 9.99, currency: 'USD'),
        ),
      ],
    );
    await orderRepo.save(updatedOrder);
    print('   ✓ Order updated\n');

    // Step 7: Verify the update
    print('7. Verifying update...');
    final verifiedOrder = await orderRepo.getById(order.id);
    print('   ✓ Update verified');
    print('   Customer: ${verifiedOrder.customerName}');
    print('   Items: ${verifiedOrder.items.length}');
    print(
      '   Total: \$${verifiedOrder.totalAmount.amount.toStringAsFixed(2)}\n',
    );

    // Step 8: Delete the order
    print('8. Deleting order...');
    await orderRepo.deleteById(order.id);
    print('   ✓ Order deleted (including all order items via CASCADE)\n');

    // Step 9: Verify deletion
    print('9. Verifying deletion...');
    try {
      await orderRepo.getById(order.id);
      throw StateError('Order still exists after deletion');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('   ✓ Order not found (expected)');
      } else {
        rethrow;
      }
    }

    print('\n=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  } finally {
    // Step 10: Close connection
    print('\n10. Closing connection...');
    await connection.close();
    print('   ✓ Connection closed');
  }
}
