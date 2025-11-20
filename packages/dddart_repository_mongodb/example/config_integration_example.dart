// ignore_for_file: avoid_print

import 'package:dddart_config/dddart_config.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'lib/domain/user.dart';

/// Configuration integration example demonstrating dddart_config usage.
///
/// This example shows:
/// - Loading MongoDB configuration from a YAML file
/// - Creating connection from config values
/// - Using environment variables for sensitive data
/// - Configuration file structure
///
/// Prerequisites:
/// - Create config.yaml file (see example below)
/// - MongoDB running with configured parameters
Future<void> main() async {
  print('=== Configuration Integration Example ===\n');

  try {
    // Step 1: Load configuration from file
    print('1. Loading configuration from config.yaml...');
    final config = await _loadConfiguration();
    print('   ✓ Configuration loaded\n');

    // Step 2: Create connection from config
    print('2. Creating MongoDB connection from config...');
    final connection = _createConnectionFromConfig(config);
    print('   ✓ Connection created');
    print('   Host: ${connection.host}');
    print('   Port: ${connection.port}');
    print('   Database: ${connection.databaseName}\n');

    // Step 3: Open connection
    print('3. Opening connection...');
    await connection.open();
    print('   ✓ Connected to MongoDB\n');

    // Step 4: Use repository
    print('4. Using repository...');
    final userRepo = UserMongoRepository(connection.database);

    final user = User(
      firstName: 'Config',
      lastName: 'User',
      email: 'config.user@example.com',
    );

    await userRepo.save(user);
    print('   ✓ User saved: ${user.fullName}');

    final retrieved = await userRepo.getById(user.id);
    print('   ✓ User retrieved: ${retrieved.fullName}');

    await userRepo.deleteById(user.id);
    print('   ✓ User deleted\n');

    // Step 5: Close connection
    print('5. Closing connection...');
    await connection.close();
    print('   ✓ Connection closed');

    print('\n=== Example completed successfully ===');
  } catch (e, stackTrace) {
    print('\n✗ Error: $e');
    print('Stack trace: $stackTrace');
    print('\nMake sure you have created a config.yaml file.');
    print('See the example configuration below.');
  }
}

/// Loads configuration from file or creates default configuration.
Future<Configuration> _loadConfiguration() async {
  try {
    // Try to load from config.yaml file
    final provider = YamlConfigProvider('config.yaml');
    return Configuration([provider]);
  } catch (e) {
    // If file doesn't exist, use default configuration
    print('   Note: config.yaml not found, using default configuration');
    print('   Create config.yaml for custom configuration\n');

    // Create configuration with environment variables
    // Falls back to defaults if env vars not set
    return Configuration([EnvironmentConfigProvider()]);
  }
}

/// Creates a MongoDB connection from configuration.
MongoConnection _createConnectionFromConfig(Configuration config) {
  // Extract connection parameters with defaults
  final host = config.getString('mongodb.host') ?? 'localhost';
  final portStr = config.getString('mongodb.port') ?? '27017';
  final port = int.parse(portStr);
  final database = config.getString('mongodb.database') ?? 'dddart_example';

  // Optional authentication
  final username = config.getString('mongodb.username');
  final password = config.getString('mongodb.password');

  // Optional TLS settings
  final tlsStr = config.getString('mongodb.tls') ?? 'false';
  final tls = tlsStr.toLowerCase() == 'true';

  final tlsAllowInvalidStr =
      config.getString('mongodb.tlsAllowInvalidCertificates') ?? 'false';
  final tlsAllowInvalidCertificates =
      tlsAllowInvalidStr.toLowerCase() == 'true';

  // Optional auth source
  final authSource = config.getString('mongodb.authSource');

  return MongoConnection(
    host: host,
    port: port,
    databaseName: database,
    username: username,
    password: password,
    tls: tls,
    tlsAllowInvalidCertificates: tlsAllowInvalidCertificates,
    authSource: authSource,
  );
}

/*
Example config.yaml file:

# MongoDB Configuration
mongodb:
  host: localhost
  port: 27017
  database: dddart_example
  
  # Optional authentication
  # username: myuser
  # password: mypassword
  # authSource: admin
  
  # Optional TLS settings (required for AWS DocumentDB)
  # tls: true
  # tlsAllowInvalidCertificates: true

# AWS DocumentDB Example:
# mongodb:
#   host: docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com
#   port: 27017
#   database: myapp
#   username: myuser
#   password: mypassword
#   authSource: admin
#   tls: true
#   tlsAllowInvalidCertificates: true

# Environment Variables Example:
# You can also use environment variables for sensitive data:
# mongodb:
#   host: ${MONGO_HOST}
#   port: ${MONGO_PORT}
#   database: ${MONGO_DATABASE}
#   username: ${MONGO_USERNAME}
#   password: ${MONGO_PASSWORD}
*/
