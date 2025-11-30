// ignore_for_file: avoid_print

import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

import 'lib/domain/product.dart';
import 'lib/domain/user.dart';

/// Table creation example demonstrating table creation utilities.
///
/// This example shows:
/// - Creating tables programmatically
/// - Getting AWS CLI commands for table creation
/// - Getting CloudFormation templates
/// - Getting CreateTableInput definitions
/// - Best practices for table management
///
/// Prerequisites:
/// - DynamoDB Local running on localhost:8000
/// - Or AWS credentials configured for production
Future<void> main() async {
  print('=== Table Creation Example ===\n');

  // Step 1: Create connection
  print('1. Creating DynamoDB connection...');
  final connection = DynamoConnection.local();
  print('   ✓ Connection created\n');

  try {
    // Step 2: Show table configuration
    print('2. Table configuration:');
    print('   Table Name: users');
    print('   Partition Key: id (String)');
    print('   Billing Mode: PAY_PER_REQUEST\n');

    // Step 3: Show AWS CLI command
    print('3. AWS CLI command for table creation:');
    final cliCommand = UserDynamoRepository.getCreateTableCommand('users');
    print('   $cliCommand\n');

    // Step 4: Show CloudFormation template
    print('4. CloudFormation template:');
    final cfTemplate = UserDynamoRepository.getCloudFormationTemplate('users');
    print(cfTemplate);
    print('');

    // Step 5: Create tables programmatically
    print('5. Creating tables programmatically...');
    final userRepo = UserDynamoRepository(connection);
    final productRepo = ProductDynamoRepository(connection);

    try {
      await userRepo.createTable();
      print('   ✓ Created table: users');
    } catch (e) {
      if (e.toString().contains('ResourceInUseException') ||
          e.toString().contains('Table already exists')) {
        print('   ✓ Table already exists: users');
      } else {
        rethrow;
      }
    }

    try {
      await productRepo.createTable();
      print('   ✓ Created table: products');
    } catch (e) {
      if (e.toString().contains('ResourceInUseException') ||
          e.toString().contains('Table already exists')) {
        print('   ✓ Table already exists: products');
      } else {
        rethrow;
      }
    }
    print('');

    // Step 6: List all tables
    print('6. Listing all tables...');
    final listResponse = await connection.client.listTables();
    print('   Available tables:');
    for (final tableName in listResponse.tableNames ?? []) {
      print('     - $tableName');
    }
    print('');

    // Step 7: Show best practices
    print('7. Table creation best practices:');
    print('   • Use createTable() for local development');
    print('   • Use CloudFormation templates for production');
    print('   • Use AWS CLI commands for manual setup');
    print('   • Always use PAY_PER_REQUEST billing mode initially');
    print('   • Create tables before running application');
    print('   • Use table name conventions (snake_case)');
    print('   • Consider using separate tables per environment\n');

    // Step 8: Show table deletion (commented out for safety)
    print('8. Table deletion (for reference):');
    print('   // await connection.client.deleteTable(tableName: "users");');
    print('   Note: Be careful with table deletion in production!\n');

    print('=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Step 9: Clean up connection
    print('\n9. Disposing connection...');
    connection.dispose();
    print('   ✓ Connection disposed');
  }
}
