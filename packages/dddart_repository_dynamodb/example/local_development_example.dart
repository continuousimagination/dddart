// ignore_for_file: avoid_print

import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

import 'lib/dynamodb_example_tables.dart';
import 'lib/domain/product.dart';

/// Local development example demonstrating DynamoDB Local setup.
///
/// This example shows:
/// - Configuring DynamoDB Local connection
/// - Using the local factory constructor
/// - Creating tables programmatically
/// - Testing with local DynamoDB instance
/// - Benefits of local development workflow
///
/// Prerequisites:
/// - DynamoDB Local running on localhost:8000
///
/// To start DynamoDB Local:
/// ```bash
/// docker run -p 8000:8000 amazon/dynamodb-local
/// ```
Future<void> main() async {
  print('=== Local Development Example ===\n');

  // Step 1: Create connection using local factory
  print('1. Creating DynamoDB Local connection...');
  final connection = DynamoConnection.local();
  print('   ✓ Connected to DynamoDB Local (localhost:8000)\n');

  // Alternative: Custom port
  // final connection = DynamoConnection.local(port: 8001);

  // Alternative: Full configuration for AWS
  // final connection = DynamoConnection(
  //   region: 'us-east-1',
  //   credentials: AwsClientCredentials(
  //     accessKey: 'YOUR_ACCESS_KEY',
  //     secretKey: 'YOUR_SECRET_KEY',
  //   ),
  // );

  try {
    // Step 2: Create repository
    print('2. Creating product repository...');
    final productRepo = ProductDynamoRepository(connection);
    print('   ✓ Repository created\n');

    // Step 3: Create table if it doesn't exist
    print('3. Creating table if needed...');
    await ensureDynamoTable(
      connection: connection,
      tableName: productRepo.tableName,
      createTable: productRepo.createTable,
    );
    print('   ✓ Table ready: ${productRepo.tableName}\n');

    // Step 4: Verify table exists by listing tables
    print('4. Verifying table exists...');
    final listResponse = await connection.client.listTables();
    final tableExists = listResponse.tableNames?.contains('products') ?? false;
    if (tableExists) {
      print('   ✓ Table "products" exists');
      print('   Available tables: ${listResponse.tableNames?.join(", ")}\n');
    } else {
      throw StateError('Table "products" was not created');
    }

    // Step 5: Test CRUD operations
    print('5. Testing CRUD operations...');
    final product = Product(
      name: 'Test Widget',
      description: 'A test product for local development',
      price: 29.99,
      inStock: true,
    );

    await productRepo.save(product);
    print('   ✓ Product saved');

    final retrieved = await productRepo.getById(product.id);
    print('   ✓ Product retrieved: ${retrieved.name}');

    await productRepo.deleteById(product.id);
    print('   ✓ Product deleted\n');

    // Step 6: Show benefits of local development
    print('6. Benefits of DynamoDB Local:');
    print('   • No AWS account required');
    print('   • No costs for development');
    print('   • Fast iteration cycle');
    print('   • Offline development');
    print('   • Easy table creation/deletion');
    print('   • Consistent test environment\n');

    // Step 7: Show table creation utilities
    print('7. Table creation utilities:');
    print('   • createTable() - Programmatic creation');
    print('   • getCreateTableCommand() - Get AWS CLI command');
    print('   • getCloudFormationTemplate() - Get CloudFormation YAML\n');

    print('=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  } finally {
    // Step 8: Clean up connection
    print('\n8. Disposing connection...');
    connection.dispose();
    print('   ✓ Connection disposed');
  }
}
