/// Complex aggregate example demonstrating multi-table persistence.
///
/// This example shows:
/// - Aggregate with nested entities (OrderItem)
/// - Multiple embedded value objects (Money, Address)
/// - Value object embedding with prefixed columns
/// - Multi-table persistence with foreign keys
/// - Cascade delete behavior
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import 'lib/complex_order.dart';

Future<void> main() async {
  final connection = SqliteConnection.memory();

  try {
    await connection.open();
    print('✓ Database connection opened');

    final repository = OrderSqliteRepository(connection);

    await repository.createTables();
    print('✓ Database tables created');
    print('  - orders table (with embedded value objects)');
    print('  - order_items table (nested entities)');

    // Create a complex order with nested entities and value objects
    final order = Order(
      customerId: UuidValue.generate(),
      customerName: 'John Doe',
      totalAmount: const Money(amount: 299.97, currency: 'USD'),
      shippingAddress: const Address(
        street: '123 Main St',
        city: 'San Francisco',
        country: 'USA',
      ),
      billingAddress: const Address(
        street: '456 Oak Ave',
        city: 'San Francisco',
        country: 'USA',
      ),
      items: [
        OrderItem(
          productId: UuidValue.generate(),
          productName: 'Laptop',
          quantity: 1,
          unitPrice: const Money(amount: 199.99, currency: 'USD'),
        ),
        OrderItem(
          productId: UuidValue.generate(),
          productName: 'Mouse',
          quantity: 2,
          unitPrice: const Money(amount: 49.99, currency: 'USD'),
        ),
      ],
      status: 'pending',
    );

    print('\n--- Creating Complex Order ---');
    print('Order ID: ${order.id}');
    print('Customer: ${order.customerName}');
    print('Total: \$${order.totalAmount.amount} ${order.totalAmount.currency}');
    print('Shipping: ${order.shippingAddress.street}, '
        '${order.shippingAddress.city}, ${order.shippingAddress.country}');
    print('Billing: ${order.billingAddress.street}, '
        '${order.billingAddress.city}, ${order.billingAddress.country}');
    print('Items: ${order.items.length}');
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      print('  ${i + 1}. ${item.productName} x${item.quantity} '
          '@ \$${item.unitPrice.amount} ${item.unitPrice.currency}');
    }

    // Save the order (multi-table transaction)
    await repository.save(order);
    print('✓ Order saved to database (multi-table transaction)');

    // Retrieve the order (with JOINs)
    print('\n--- Retrieving Order ---');
    final retrievedOrder = await repository.getById(order.id);
    print('Order ID: ${retrievedOrder.id}');
    print('Customer: ${retrievedOrder.customerName}');
    print('Status: ${retrievedOrder.status}');
    print('Total: \$${retrievedOrder.totalAmount.amount} '
        '${retrievedOrder.totalAmount.currency}');
    print('Items retrieved: ${retrievedOrder.items.length}');
    for (var i = 0; i < retrievedOrder.items.length; i++) {
      final item = retrievedOrder.items[i];
      print('  ${i + 1}. ${item.productName} x${item.quantity} '
          '@ \$${item.unitPrice.amount} ${item.unitPrice.currency}');
    }

    // Demonstrate value object embedding
    print('\n--- Value Object Embedding ---');
    print('Value objects are embedded as prefixed columns:');
    print('  totalAmount_amount: ${retrievedOrder.totalAmount.amount}');
    print('  totalAmount_currency: ${retrievedOrder.totalAmount.currency}');
    print('  shippingAddress_street: ${retrievedOrder.shippingAddress.street}');
    print('  shippingAddress_city: ${retrievedOrder.shippingAddress.city}');
    print(
        '  shippingAddress_country: ${retrievedOrder.shippingAddress.country}');
    print('  billingAddress_street: ${retrievedOrder.billingAddress.street}');
    print('  billingAddress_city: ${retrievedOrder.billingAddress.city}');
    print('  billingAddress_country: ${retrievedOrder.billingAddress.country}');

    // Update the order
    print('\n--- Updating Order ---');
    final updatedOrder = Order(
      id: retrievedOrder.id,
      customerId: retrievedOrder.customerId,
      customerName: retrievedOrder.customerName,
      totalAmount: retrievedOrder.totalAmount,
      shippingAddress: retrievedOrder.shippingAddress,
      billingAddress: retrievedOrder.billingAddress,
      items: [
        ...retrievedOrder.items,
        OrderItem(
          productId: UuidValue.generate(),
          productName: 'Keyboard',
          quantity: 1,
          unitPrice: const Money(amount: 79.99, currency: 'USD'),
        ),
      ],
      status: 'confirmed', // Updated status
      createdAt: retrievedOrder.createdAt,
      updatedAt: DateTime.now(),
    );
    await repository.save(updatedOrder);
    print('✓ Order updated (added item, changed status)');

    final verifyOrder = await repository.getById(order.id);
    print('Items after update: ${verifyOrder.items.length}');
    print('Status after update: ${verifyOrder.status}');

    // Demonstrate cascade delete
    print('\n--- Cascade Delete ---');
    print('Deleting order will cascade to order items...');
    await repository.deleteById(order.id);
    print('✓ Order deleted (cascade deleted ${order.items.length} items)');

    // Verify deletion
    try {
      await repository.getById(order.id);
      print('✗ ERROR: Order should not exist!');
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.notFound) {
        print('✓ Order not found (as expected)');
      }
    }

    print('\n✓ Complex aggregate example completed successfully!');
  } catch (e, stackTrace) {
    print('✗ Error: $e');
    print(stackTrace);
  } finally {
    await connection.close();
    print('\n✓ Database connection closed');
  }
}
