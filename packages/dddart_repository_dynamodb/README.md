# dddart_repository_dynamodb

DynamoDB repository implementation for DDDart aggregate roots with code generation support.

## Features

- 🚀 **Code Generation**: Automatically generate DynamoDB repository implementations from annotated aggregate roots
- 🔄 **JSON Serialization**: Reuse existing `dddart_json` serializers with automatic AttributeValue conversion
- 🎯 **Type Safety**: Full type safety with compile-time code generation
- 🔌 **Extensibility**: Support for custom repository interfaces with domain-specific query methods
- 🌍 **AWS Integration**: Built on official AWS SDK for Dart with proper credential management
- 🧪 **Local Development**: Support for DynamoDB Local and LocalStack
- 📦 **Consistent API**: Mirrors `dddart_repository_mongodb` patterns for easy implementation swapping

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart: ^1.0.0
  dddart_json: ^1.0.0
  dddart_repository_dynamodb: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Quick Start

### 1. Annotate Your Aggregate Root

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

part 'user.g.dart';
part 'user.dynamo_repository.g.dart';

@Serializable()
@GenerateDynamoRepository(tableName: 'users')
class User extends AggregateRoot {
  User({
    required UuidValue id,
    required this.email,
    required this.firstName,
    required this.lastName,
  }) : super(id);

  final String email;
  final String firstName;
  final String lastName;
}
```

### 2. Generate Repository Code

```bash
dart run build_runner build
```

### 3. Use the Generated Repository

```dart
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

void main() async {
  // Configure connection
  final connection = DynamoConnection(
    region: 'us-east-1',
    // Credentials will use AWS default credential chain
  );

  // Create repository instance
  final userRepo = UserDynamoRepository(connection);

  // Create table (one-time setup)
  await userRepo.createTable();

  // Use repository
  final user = User(
    id: UuidValue.generate(),
    email: 'john@example.com',
    firstName: 'John',
    lastName: 'Doe',
  );

  await userRepo.save(user);
  final retrieved = await userRepo.getById(user.id);
  await userRepo.deleteById(user.id);

  // Clean up
  connection.dispose();
}
```

## Configuration

### AWS Credentials

The package uses the AWS SDK's default credential provider chain:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. IAM role (when running on EC2, ECS, Lambda, etc.)

You can also provide credentials explicitly:

```dart
final connection = DynamoConnection(
  region: 'us-east-1',
  credentials: AwsClientCredentials(
    accessKey: 'YOUR_ACCESS_KEY',
    secretKey: 'YOUR_SECRET_KEY',
  ),
);
```

### DynamoDB Local

For local development:

```dart
final connection = DynamoConnection.local(port: 8000);
```

Start DynamoDB Local with Docker:

```bash
docker run -p 8000:8000 amazon/dynamodb-local
```

## Custom Repository Interfaces

Define domain-specific query methods:

```dart
abstract class UserRepository extends Repository<User> {
  Future<User?> findByEmail(String email);
  Future<List<User>> findByLastName(String lastName);
}

@Serializable()
@GenerateDynamoRepository(
  tableName: 'users',
  implements: UserRepository,
)
class User extends AggregateRoot {
  // ... fields
}
```

The generator creates an abstract base class that you extend:

```dart
class UserDynamoRepositoryImpl extends UserDynamoRepositoryBase {
  UserDynamoRepositoryImpl(super.connection);

  @override
  Future<User?> findByEmail(String email) async {
    // Implement custom query using _connection, tableName, _serializer
    final result = await _connection.client.query(
      tableName: tableName,
      indexName: 'email-index',
      keyConditionExpression: 'email = :email',
      expressionAttributeValues: {':email': AttributeValue(s: email)},
    );
    // ... parse and return result
  }

  @override
  Future<List<User>> findByLastName(String lastName) async {
    // Implement custom query
  }
}
```

## Table Creation

### Programmatic Creation

```dart
await userRepo.createTable();
```

### AWS CLI

```dart
final command = UserDynamoRepository.getCreateTableCommand('users');
print(command);
// Run the printed command in your terminal
```

### CloudFormation

```dart
final template = UserDynamoRepository.getCloudFormationTemplate('users');
print(template);
// Add to your CloudFormation template
```

## Error Handling

All DynamoDB errors are mapped to standard `RepositoryException` types:

```dart
try {
  final user = await userRepo.getById(userId);
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      print('User not found');
      break;
    case RepositoryExceptionType.connection:
      print('Connection error: ${e.message}');
      break;
    case RepositoryExceptionType.timeout:
      print('Operation timed out');
      break;
    default:
      print('Unknown error: ${e.message}');
  }
}
```

## API Documentation

### Annotations

#### `@GenerateDynamoRepository`

Marks an aggregate root for repository generation.

**Parameters:**
- `tableName` (String?, optional): Custom table name. Defaults to snake_case of class name.
- `implements` (Type?, optional): Custom repository interface to implement.

**Example:**
```dart
@GenerateDynamoRepository(tableName: 'users')
class User extends AggregateRoot { }

@GenerateDynamoRepository(
  tableName: 'orders',
  implements: OrderRepository,
)
class Order extends AggregateRoot { }
```

### Classes

#### `DynamoConnection`

Manages DynamoDB client lifecycle and configuration.

**Constructors:**
- `DynamoConnection({required String region, AwsClientCredentials? credentials, String? endpoint})`
  - `region`: AWS region (e.g., 'us-east-1', 'eu-west-1')
  - `credentials`: Optional AWS credentials (uses default chain if not provided)
  - `endpoint`: Optional custom endpoint for DynamoDB Local/LocalStack
- `DynamoConnection.local({int port = 8000})`: Factory for DynamoDB Local

**Properties:**
- `client`: DynamoDB client instance (lazy initialized)
- `region`: AWS region string
- `credentials`: AWS credentials (if provided)
- `endpoint`: Custom endpoint URL (if provided)

**Methods:**
- `dispose()`: Clean up resources and close client connection

**Example:**
```dart
// Production with default credentials
final connection = DynamoConnection(region: 'us-east-1');

// Production with explicit credentials
final connection = DynamoConnection(
  region: 'us-east-1',
  credentials: AwsClientCredentials(
    accessKey: 'YOUR_KEY',
    secretKey: 'YOUR_SECRET',
  ),
);

// Local development
final connection = DynamoConnection.local();

// Always dispose when done
connection.dispose();
```

#### `AttributeValueConverter`

Utilities for converting between JSON and DynamoDB AttributeValue format.

**Static Methods:**
- `jsonToAttributeValue(dynamic value)`: Convert JSON value to AttributeValue
- `attributeValueToJson(AttributeValue attr)`: Convert AttributeValue to JSON
- `jsonMapToAttributeMap(Map<String, dynamic> json)`: Convert JSON map to AttributeValue map
- `attributeMapToJsonMap(Map<String, AttributeValue> attrs)`: Convert AttributeValue map to JSON map

**Conversion Rules:**
| JSON Type | AttributeValue Type | Example |
|-----------|-------------------|---------|
| null | NULL | `{nullValue: true}` |
| bool | BOOL | `{boolValue: true}` |
| String | S | `{s: "value"}` |
| num | N | `{n: "123.45"}` |
| List | L | `{l: [AttributeValue, ...]}` |
| Map | M | `{m: {key: AttributeValue}}` |

### Generated Repository Classes

#### Concrete Repository (No Custom Interface)

Generated when no custom interface is specified or interface has only base methods.

**Constructor:**
- `{ClassName}DynamoRepository(DynamoConnection connection)`

**Methods:**
- `Future<T> getById(UuidValue id)`: Retrieve aggregate by ID
- `Future<void> save(T aggregate)`: Save or update aggregate
- `Future<void> deleteById(UuidValue id)`: Delete aggregate by ID
- `Future<void> createTable()`: Create DynamoDB table

**Static Methods:**
- `CreateTableInput createTableDefinition(String tableName)`: Get table definition
- `String getCreateTableCommand(String tableName)`: Get AWS CLI command
- `String getCloudFormationTemplate(String tableName)`: Get CloudFormation YAML

**Properties:**
- `tableName`: The DynamoDB table name

#### Abstract Base Repository (Custom Interface)

Generated when custom interface has additional methods beyond base Repository.

**Constructor:**
- `{ClassName}DynamoRepositoryBase(DynamoConnection connection)`

**Concrete Methods:**
- Same as concrete repository (getById, save, deleteById, createTable, etc.)

**Abstract Methods:**
- Custom methods from the interface (must be implemented by subclass)

**Protected Members:**
- `_connection`: DynamoConnection instance
- `tableName`: Table name string
- `_serializer`: JsonSerializer instance
- `_mapException(dynamic e)`: Exception mapping helper

**Example:**
```dart
class UserDynamoRepository extends UserDynamoRepositoryBase {
  UserDynamoRepository(super.connection);

  @override
  Future<User?> findByEmail(String email) async {
    // Use protected members: _connection, tableName, _serializer
    final result = await _connection.client.query(
      tableName: tableName,
      indexName: 'email-index',
      keyConditionExpression: 'email = :email',
      expressionAttributeValues: {
        ':email': AttributeValue(s: email),
      },
    );
    
    if (result.items == null || result.items!.isEmpty) {
      return null;
    }
    
    final json = AttributeValueConverter.attributeMapToJsonMap(
      result.items!.first,
    );
    return _serializer.fromJson(json);
  }
}
```

## Best Practices

### Connection Lifecycle Management

**Create one connection per application, not per request:**

```dart
// ✅ Good: Application-level singleton
class AppConfig {
  static final dynamoConnection = DynamoConnection(region: 'us-east-1');
}

// Use throughout application
final userRepo = UserDynamoRepository(AppConfig.dynamoConnection);
final orderRepo = OrderDynamoRepository(AppConfig.dynamoConnection);

// ❌ Bad: Creating connection per request
Future<void> handleRequest() async {
  final connection = DynamoConnection(region: 'us-east-1'); // Don't do this!
  final repo = UserDynamoRepository(connection);
  // ...
}
```

**Dispose connections on application shutdown:**

```dart
void main() async {
  final connection = DynamoConnection(region: 'us-east-1');
  
  try {
    // Application logic
    await runApplication(connection);
  } finally {
    // Clean up on shutdown
    connection.dispose();
  }
}
```

**Use connection pooling for high-throughput applications:**

The AWS SDK manages HTTP connection pooling internally. Reusing a single `DynamoConnection` instance ensures efficient connection reuse.

### Table Naming

**Use explicit table names in production:**

```dart
// ✅ Good: Explicit table names
@GenerateDynamoRepository(tableName: 'prod_users')
class User extends AggregateRoot { }

@GenerateDynamoRepository(tableName: 'staging_users')
class User extends AggregateRoot { }

// ⚠️ Acceptable for development: Auto-generated names
@GenerateDynamoRepository() // Generates 'user' table name
class User extends AggregateRoot { }
```

**Use environment-specific prefixes:**

```dart
final env = Platform.environment['ENV'] ?? 'dev';

@GenerateDynamoRepository(tableName: '${env}_users')
class User extends AggregateRoot { }
```

### Error Handling Patterns

**Always handle RepositoryException types:**

```dart
try {
  await userRepo.save(user);
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      // Handle not found
      break;
    case RepositoryExceptionType.connection:
      // Retry or fail gracefully
      break;
    case RepositoryExceptionType.timeout:
      // Retry with backoff
      break;
    default:
      // Log and rethrow
      logger.error('Unexpected error: ${e.message}', e.cause);
      rethrow;
  }
}
```

**Implement retry logic for transient errors:**

```dart
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  
  while (true) {
    try {
      return await operation();
    } on RepositoryException catch (e) {
      attempt++;
      
      // Only retry transient errors
      if (e.type != RepositoryExceptionType.connection &&
          e.type != RepositoryExceptionType.timeout) {
        rethrow;
      }
      
      if (attempt >= maxAttempts) {
        rethrow;
      }
      
      // Exponential backoff
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}

// Usage
final user = await withRetry(() => userRepo.getById(userId));
```

**Handle not found gracefully:**

```dart
Future<User?> findUserSafely(UuidValue id) async {
  try {
    return await userRepo.getById(id);
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      return null;
    }
    rethrow;
  }
}
```

### Security Best Practices

**Never hardcode credentials:**

```dart
// ❌ Bad: Hardcoded credentials
final connection = DynamoConnection(
  region: 'us-east-1',
  credentials: AwsClientCredentials(
    accessKey: 'AKIAIOSFODNN7EXAMPLE', // Don't do this!
    secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  ),
);

// ✅ Good: Use environment variables
final connection = DynamoConnection(
  region: Platform.environment['AWS_REGION'] ?? 'us-east-1',
  credentials: Platform.environment.containsKey('AWS_ACCESS_KEY_ID')
      ? AwsClientCredentials(
          accessKey: Platform.environment['AWS_ACCESS_KEY_ID']!,
          secretKey: Platform.environment['AWS_SECRET_ACCESS_KEY']!,
        )
      : null, // Use default credential chain
);

// ✅ Best: Use IAM roles (no credentials needed)
final connection = DynamoConnection(region: 'us-east-1');
```

**Use least privilege IAM policies:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/users"
    }
  ]
}
```

**Enable encryption at rest:**

Enable encryption when creating tables in production:

```dart
// Via AWS Console, CLI, or CloudFormation
// Encryption cannot be configured via the SDK's CreateTable API
```

### Performance Optimization

**Use consistent reads only when necessary:**

```dart
// Eventually consistent (faster, cheaper)
final result = await connection.client.getItem(
  tableName: tableName,
  key: {'id': AttributeValue(s: id.value)},
  consistentRead: false, // Default
);

// Strongly consistent (slower, more expensive)
final result = await connection.client.getItem(
  tableName: tableName,
  key: {'id': AttributeValue(s: id.value)},
  consistentRead: true, // Use only when needed
);
```

**Implement pagination for large result sets:**

```dart
Future<List<User>> scanAllUsers() async {
  final users = <User>[];
  Map<String, AttributeValue>? lastEvaluatedKey;
  
  do {
    final result = await connection.client.scan(
      tableName: tableName,
      exclusiveStartKey: lastEvaluatedKey,
      limit: 100, // Page size
    );
    
    if (result.items != null) {
      for (final item in result.items!) {
        final json = AttributeValueConverter.attributeMapToJsonMap(item);
        users.add(serializer.fromJson(json));
      }
    }
    
    lastEvaluatedKey = result.lastEvaluatedKey;
  } while (lastEvaluatedKey != null);
  
  return users;
}
```

**Use projection expressions to reduce data transfer:**

```dart
// Only retrieve specific attributes
final result = await connection.client.getItem(
  tableName: tableName,
  key: {'id': AttributeValue(s: id.value)},
  projectionExpression: 'id, email, firstName, lastName',
);
```

### Testing Best Practices

**Use DynamoDB Local for integration tests:**

```dart
@Tags(['integration'])
void main() {
  late DynamoConnection connection;
  late UserDynamoRepository userRepo;
  
  setUp(() async {
    connection = DynamoConnection.local();
    userRepo = UserDynamoRepository(connection);
    await userRepo.createTable();
  });
  
  tearDown(() async {
    // Clean up table
    await connection.client.deleteTable(tableName: userRepo.tableName);
    connection.dispose();
  });
  
  test('should save and retrieve user', () async {
    final user = User(
      id: UuidValue.generate(),
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
    );
    
    await userRepo.save(user);
    final retrieved = await userRepo.getById(user.id);
    
    expect(retrieved.email, equals(user.email));
  });
}
```

**Use in-memory repositories for unit tests:**

```dart
// Test business logic without DynamoDB
final userRepo = InMemoryRepository<User>();
final service = UserService(userRepo);

test('should create user', () async {
  await service.createUser('test@example.com', 'Test', 'User');
  
  final users = await userRepo.getAll();
  expect(users, hasLength(1));
});
```

## Extensibility Patterns

### Custom Query Methods

Extend the generated base repository to add domain-specific queries:

```dart
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
  Future<List<User>> findByLastName(String lastName);
  Future<List<User>> findActiveUsers();
}

@Serializable()
@GenerateDynamoRepository(
  tableName: 'users',
  implements: UserRepository,
)
class User extends AggregateRoot {
  User({
    required UuidValue id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isActive,
  }) : super(id);

  final String email;
  final String firstName;
  final String lastName;
  final bool isActive;
}

part 'user.g.dart';
part 'user.dynamo_repository.g.dart';

class UserDynamoRepository extends UserDynamoRepositoryBase {
  UserDynamoRepository(super.connection);

  @override
  Future<User?> findByEmail(String email) async {
    try {
      // Requires Global Secondary Index on email
      final result = await _connection.client.query(
        tableName: tableName,
        indexName: 'email-index',
        keyConditionExpression: 'email = :email',
        expressionAttributeValues: {
          ':email': AttributeValue(s: email),
        },
      );

      if (result.items == null || result.items!.isEmpty) {
        return null;
      }

      final json = AttributeValueConverter.attributeMapToJsonMap(
        result.items!.first,
      );
      return _serializer.fromJson(json);
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<List<User>> findByLastName(String lastName) async {
    try {
      final result = await _connection.client.scan(
        tableName: tableName,
        filterExpression: 'lastName = :lastName',
        expressionAttributeValues: {
          ':lastName': AttributeValue(s: lastName),
        },
      );

      if (result.items == null || result.items!.isEmpty) {
        return [];
      }

      return result.items!.map((item) {
        final json = AttributeValueConverter.attributeMapToJsonMap(item);
        return _serializer.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<List<User>> findActiveUsers() async {
    try {
      final result = await _connection.client.scan(
        tableName: tableName,
        filterExpression: 'isActive = :active',
        expressionAttributeValues: {
          ':active': AttributeValue(boolValue: true),
        },
      );

      if (result.items == null || result.items!.isEmpty) {
        return [];
      }

      return result.items!.map((item) {
        final json = AttributeValueConverter.attributeMapToJsonMap(item);
        return _serializer.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }
}
```

### Global Secondary Indexes (GSI)

For efficient queries on non-key attributes, create GSIs:

```dart
// Create GSI via AWS CLI
aws dynamodb update-table \
  --table-name users \
  --attribute-definitions AttributeName=email,AttributeType=S \
  --global-secondary-index-updates \
    "[{\"Create\":{\"IndexName\":\"email-index\",\"KeySchema\":[{\"AttributeName\":\"email\",\"KeyType\":\"HASH\"}],\"Projection\":{\"ProjectionType\":\"ALL\"},\"ProvisionedThroughput\":{\"ReadCapacityUnits\":5,\"WriteCapacityUnits\":5}}}]"

// Or via CloudFormation
Resources:
  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: users
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
        - AttributeName: email
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: email-index
          KeySchema:
            - AttributeName: email
              KeyType: HASH
          Projection:
            ProjectionType: ALL
          ProvisionedThroughput:
            ReadCapacityUnits: 5
            WriteCapacityUnits: 5
      BillingMode: PAY_PER_REQUEST
```

### Batch Operations

Implement batch operations for better performance:

```dart
class UserDynamoRepository extends UserDynamoRepositoryBase {
  UserDynamoRepository(super.connection);

  Future<void> saveAll(List<User> users) async {
    // DynamoDB BatchWriteItem supports up to 25 items
    const batchSize = 25;
    
    for (var i = 0; i < users.length; i += batchSize) {
      final batch = users.skip(i).take(batchSize).toList();
      
      final requests = batch.map((user) {
        final json = _serializer.toJson(user);
        final item = AttributeValueConverter.jsonMapToAttributeMap(json);
        
        return WriteRequest(
          putRequest: PutRequest(item: item),
        );
      }).toList();
      
      try {
        await _connection.client.batchWriteItem(
          requestItems: {tableName: requests},
        );
      } catch (e) {
        throw _mapException(e);
      }
    }
  }

  Future<List<User>> getByIds(List<UuidValue> ids) async {
    const batchSize = 100; // BatchGetItem supports up to 100 items
    final users = <User>[];
    
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      
      final keys = batch.map((id) => {
        'id': AttributeValue(s: id.value),
      }).toList();
      
      try {
        final result = await _connection.client.batchGetItem(
          requestItems: {
            tableName: KeysAndAttributes(keys: keys),
          },
        );
        
        final items = result.responses?[tableName] ?? [];
        for (final item in items) {
          final json = AttributeValueConverter.attributeMapToJsonMap(item);
          users.add(_serializer.fromJson(json));
        }
      } catch (e) {
        throw _mapException(e);
      }
    }
    
    return users;
  }
}
```

### Conditional Writes

Implement optimistic locking with conditional writes:

```dart
class UserDynamoRepository extends UserDynamoRepositoryBase {
  UserDynamoRepository(super.connection);

  Future<void> saveWithVersion(User user, int expectedVersion) async {
    try {
      final json = _serializer.toJson(user);
      json['version'] = expectedVersion + 1; // Increment version
      
      final item = AttributeValueConverter.jsonMapToAttributeMap(json);
      
      await _connection.client.putItem(
        tableName: tableName,
        item: item,
        conditionExpression: 'version = :expectedVersion OR attribute_not_exists(version)',
        expressionAttributeValues: {
          ':expectedVersion': AttributeValue(n: expectedVersion.toString()),
        },
      );
    } catch (e) {
      throw _mapException(e);
    }
  }
}
```

### Repository Composition

Compose multiple repositories for complex operations:

```dart
class OrderService {
  OrderService(this.orderRepo, this.userRepo, this.productRepo);

  final OrderRepository orderRepo;
  final UserRepository userRepo;
  final ProductRepository productRepo;

  Future<Order> createOrder(
    UuidValue userId,
    List<UuidValue> productIds,
  ) async {
    // Validate user exists
    final user = await userRepo.getById(userId);
    
    // Validate products exist
    final products = await Future.wait(
      productIds.map((id) => productRepo.getById(id)),
    );
    
    // Create and save order
    final order = Order(
      id: UuidValue.generate(),
      userId: userId,
      productIds: productIds,
      total: products.fold(0.0, (sum, p) => sum + p.price),
    );
    
    await orderRepo.save(order);
    return order;
  }
}
```

## Troubleshooting

### Table Does Not Exist

**Problem:** `ResourceNotFoundException: Requested resource not found: Table: users not found`

**Solution:** Ensure tables are created before use:

```dart
// Option 1: Programmatic creation
await userRepo.createTable();

// Option 2: AWS CLI
aws dynamodb create-table \
  --table-name users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

// Option 3: AWS Console
// Navigate to DynamoDB → Tables → Create table

// Option 4: Infrastructure as Code (Terraform, CloudFormation, etc.)
```

### Credential Errors

**Problem:** `Unable to locate credentials` or `The security token included in the request is invalid`

**Solution:** Verify AWS credentials are configured:

```bash
# Option 1: AWS CLI configuration
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_REGION=us-east-1

# Option 3: Shared credentials file
# Create ~/.aws/credentials with:
[default]
aws_access_key_id = your_key
aws_secret_access_key = your_secret

# Option 4: IAM role (when running on AWS)
# No configuration needed - automatically uses instance/task role
```

**Verify credentials:**
```bash
aws sts get-caller-identity
```

### Code Generation Issues

**Problem:** Generated files not updating or build errors

**Solution:** Clean and rebuild:

```bash
# Clean generated files
dart run build_runner clean

# Rebuild with conflict resolution
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs
```

**Common issues:**
- Missing `part` directive: Add `part 'filename.dynamo_repository.g.dart';`
- Missing `@Serializable()`: Add to aggregate root class
- Class doesn't extend `AggregateRoot`: Ensure proper inheritance

### Connection Timeout

**Problem:** Operations timing out or taking too long

**Solution:**

```dart
// 1. Check network connectivity to DynamoDB
// 2. Verify region is correct
// 3. Check for VPC/security group restrictions
// 4. Implement retry logic with exponential backoff

Future<User> getUserWithRetry(UuidValue id) async {
  var attempts = 0;
  const maxAttempts = 3;
  var delay = Duration(seconds: 1);
  
  while (attempts < maxAttempts) {
    try {
      return await userRepo.getById(id);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.timeout) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      } else {
        rethrow;
      }
    }
  }
  throw StateError('Should not reach here');
}
```

### DynamoDB Local Connection Issues

**Problem:** Cannot connect to DynamoDB Local

**Solution:**

```bash
# 1. Verify DynamoDB Local is running
docker ps | grep dynamodb-local

# 2. Start DynamoDB Local if not running
docker run -p 8000:8000 amazon/dynamodb-local

# 3. Test connection
curl http://localhost:8000

# 4. Verify port in code matches
final connection = DynamoConnection.local(port: 8000);
```

### Serialization Errors

**Problem:** `Unsupported type for DynamoDB conversion` or deserialization failures

**Solution:**

```dart
// 1. Ensure all fields are JSON-serializable
// 2. Use @Serializable() annotation
// 3. Run code generation
dart run build_runner build

// 4. Check for unsupported types (functions, symbols, etc.)
// 5. Implement custom serialization for complex types

@Serializable()
class User extends AggregateRoot {
  User({
    required UuidValue id,
    required this.email,
    required this.createdAt, // DateTime is supported
  }) : super(id);

  final String email;
  final DateTime createdAt;
  
  // ❌ Don't use unsupported types
  // final Function callback; // Not serializable
  // final Symbol symbol; // Not serializable
}
```

### Performance Issues

**Problem:** Slow queries or high costs

**Solution:**

```dart
// 1. Use Query instead of Scan when possible
// Query requires partition key or GSI
final result = await connection.client.query(
  tableName: tableName,
  keyConditionExpression: 'id = :id',
  expressionAttributeValues: {':id': AttributeValue(s: id.value)},
);

// 2. Create Global Secondary Indexes for common queries
// 3. Use projection expressions to reduce data transfer
// 4. Implement pagination for large result sets
// 5. Use batch operations for multiple items
// 6. Enable DynamoDB Auto Scaling or use On-Demand billing
// 7. Monitor with CloudWatch metrics
```

### Version Conflicts

**Problem:** Multiple generated file versions or conflicts

**Solution:**

```bash
# 1. Ensure consistent package versions
dart pub upgrade

# 2. Clean all generated files
find . -name "*.g.dart" -delete
find . -name "*.dynamo_repository.g.dart" -delete

# 3. Regenerate
dart run build_runner build --delete-conflicting-outputs

# 4. Check pubspec.yaml for version constraints
dependencies:
  dddart: ^1.0.0
  dddart_json: ^1.0.0
  dddart_repository_dynamodb: ^0.1.0
```

## AWS DocumentDB Compatibility

**Note:** This package is designed specifically for **Amazon DynamoDB** and is **not compatible** with Amazon DocumentDB.

### Key Differences

| Feature | DynamoDB | DocumentDB |
|---------|----------|------------|
| Type | NoSQL Key-Value/Document Store | MongoDB-compatible Document Database |
| API | AWS DynamoDB API | MongoDB Wire Protocol |
| Query Language | DynamoDB expressions | MongoDB Query Language (MQL) |
| Data Model | Items with AttributeValues | BSON documents |
| SDK | `aws_dynamodb_api` | `mongo_dart` |

### For DocumentDB Support

If you need MongoDB/DocumentDB support, use the `dddart_repository_mongodb` package instead:

```yaml
dependencies:
  dddart_repository_mongodb: ^0.1.0
```

```dart
@Serializable()
@GenerateMongoRepository(collectionName: 'users')
class User extends AggregateRoot {
  // Same aggregate definition
}

// Use MongoDB connection
final db = await Db.create('mongodb://localhost:27017/mydb');
await db.open();

final userRepo = UserMongoRepository(db);
```

Both packages follow the same patterns, making it easy to switch between DynamoDB and MongoDB/DocumentDB implementations.

## Examples

See the `example/` directory for complete examples:

- `basic_crud_example.dart`: Simple CRUD operations
- `custom_interface_example.dart`: Custom repository methods
- `local_development_example.dart`: DynamoDB Local setup
- `table_creation_example.dart`: Table creation utilities
- `error_handling_example.dart`: Error handling patterns

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.
