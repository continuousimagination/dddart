/// Custom repository example for dddart_repository_rest.
///
/// This example demonstrates:
/// - Defining a custom repository interface
/// - Extending the generated base class
/// - Implementing domain-specific query methods
/// - Using protected members (_connection, _serializer, _resourcePath)
/// - Handling errors in custom methods
///
/// To run this example, you need a REST API server running at
/// http://localhost:8080 with a /products endpoint that supports
/// query parameters for filtering.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';

import 'lib/product.dart';

// The ProductRestRepository implementation is now in lib/product.dart
// This allows it to access the protected members from the generated base class

Future<void> main() async {
  print('=== Custom Repository Example ===\n');

  // Create a REST connection
  final connection = RestConnection(
    baseUrl: 'http://localhost:8080',
  );

  // Create an instance of our custom repository
  final productRepository = ProductRestRepository(connection);

  try {
    // First, create some sample products
    print('1. Creating sample products...');

    final products = [
      Product(
        name: 'Laptop',
        description: 'High-performance laptop',
        price: 1299.99,
        category: 'Electronics',
      ),
      Product(
        name: 'Mouse',
        description: 'Wireless mouse',
        price: 29.99,
        category: 'Electronics',
      ),
      Product(
        name: 'Desk Chair',
        description: 'Ergonomic office chair',
        price: 299.99,
        category: 'Furniture',
      ),
      Product(
        name: 'Desk Lamp',
        description: 'LED desk lamp',
        price: 49.99,
        category: 'Furniture',
      ),
      Product(
        name: 'Keyboard',
        description: 'Mechanical keyboard',
        price: 149.99,
        category: 'Electronics',
      ),
    ];

    for (final product in products) {
      await productRepository.save(product);
      print('   ✓ Created: ${product.name} (\$${product.price})');
    }
    print('');

    // Use custom query method: findByCategory
    print('2. Finding products by category (Electronics)...');
    final electronics = await productRepository.findByCategory('Electronics');
    print('   Found ${electronics.length} electronics:');
    for (final product in electronics) {
      print('   - ${product.name}: \$${product.price}');
    }
    print('');

    // Use custom query method: findByPriceRange
    print(r'3. Finding products in price range ($50 - $300)...');
    final midRange = await productRepository.findByPriceRange(50, 300);
    print('   Found ${midRange.length} products:');
    for (final product in midRange) {
      print('   - ${product.name}: \$${product.price}');
    }
    print('');

    // Demonstrate standard CRUD operations still work
    print('4. Using standard CRUD operations...');
    final laptop = electronics.firstWhere((p) => p.name == 'Laptop');
    final retrieved = await productRepository.getById(laptop.id);
    print('   ✓ Retrieved: ${retrieved.name}');
    print('   Description: ${retrieved.description}\n');

    // Clean up: delete all products
    print('5. Cleaning up...');
    for (final product in products) {
      await productRepository.deleteById(product.id);
    }
    print('   ✓ All products deleted\n');

    print('=== Example completed successfully! ===');
  } on RepositoryException catch (e) {
    print('\n✗ Repository error: ${e.message}');
    print('  Type: ${e.type}');
    if (e.cause != null) {
      print('  Cause: ${e.cause}');
    }
  } catch (e) {
    print('\n✗ Unexpected error: $e');
  } finally {
    connection.dispose();
    print('\nConnection closed.');
  }

  print('\n=== Key Concepts ===');
  print(
    '1. Custom Interface: ProductRepository defines domain-specific methods',
  );
  print(
    '2. Generated Base: ProductRestRepositoryBase provides CRUD operations',
  );
  print('3. Custom Implementation: ProductRestRepository adds query logic');
  print(
    '4. Protected Members: Access to _connection, _serializer, _resourcePath',
  );
  print('5. Error Handling: Use _mapHttpException for consistent errors');
}
