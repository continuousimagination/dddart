# Design Document

## Overview

The `dddart_repository_dynamodb` package provides code-generated DynamoDB repository implementations for DDDart aggregate roots. It mirrors the architecture of `dddart_repository_mongodb` while adapting to DynamoDB's key-value document model and AWS SDK patterns.

### Key Design Principles

1. **Reuse JSON Serialization**: Leverage existing `dddart_json` serializers with a thin conversion layer to DynamoDB's AttributeValue format
2. **Code Generation**: Automatically generate repository implementations from annotated aggregate roots
3. **Extensibility**: Support custom repository interfaces with domain-specific query methods
4. **Consistency**: Follow the same patterns as `dddart_repository_mongodb` for easy implementation swapping
5. **AWS Best Practices**: Use official AWS SDK for Dart with proper credential management and error handling

### Technology Stack

- **AWS SDK**: `aws_dynamodb_api` package for DynamoDB client functionality
- **Code Generation**: `build_runner`, `source_gen`, and `analyzer` packages
- **Serialization**: Reuse `dddart_json` serializers with JSON-to-AttributeValue conversion
- **Base Framework**: `dddart` for Repository interface and RepositoryException types

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         UserDynamoRepository (Generated)              │  │
│  │  - getById(id) → User                                 │  │
│  │  - save(user) → void                                  │  │
│  │  - deleteById(id) → void                              │  │
│  │  - findByEmail(email) → User? (custom)                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  dddart_repository_dynamodb                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         DynamoRepositoryGenerator                     │  │
│  │  - Validates annotations                              │  │
│  │  - Generates repository implementations               │  │
│  │  - Determines concrete vs abstract base               │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            DynamoConnection                           │  │
│  │  - Manages DynamoDB client lifecycle                  │  │
│  │  - Handles AWS credentials                            │  │
│  │  - Supports custom endpoints (Local/LocalStack)       │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         AttributeValueConverter                       │  │
│  │  - jsonToAttributeValue(json) → AttributeValue        │  │
│  │  - attributeValueToJson(attr) → JSON                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      dddart_json                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         UserJsonSerializer (Generated)                │  │
│  │  - toJson(user) → Map<String, dynamic>                │  │
│  │  - fromJson(json) → User                              │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      AWS DynamoDB                            │
│  - Table: users                                              │
│  - Partition Key: id (String)                                │
│  - Items stored as AttributeValue maps                       │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

#### Save Operation
```
User Aggregate
    ↓ (toJson via dddart_json)
Map<String, dynamic>
    ↓ (jsonToAttributeValue)
Map<String, AttributeValue>
    ↓ (PutItem API call)
DynamoDB Table
```

#### Retrieve Operation
```
DynamoDB Table
    ↓ (GetItem API call)
Map<String, AttributeValue>
    ↓ (attributeValueToJson)
Map<String, dynamic>
    ↓ (fromJson via dddart_json)
User Aggregate
```

## Components and Interfaces

### 1. Annotation: `@GenerateDynamoRepository`

```dart
class GenerateDynamoRepository {
  const GenerateDynamoRepository({
    this.tableName,
    this.implements,
  });
  
  final String? tableName;
  final Type? implements;
}
```

**Purpose**: Marks aggregate roots for DynamoDB repository generation.

**Parameters**:
- `tableName`: Optional custom table name (defaults to snake_case of class name)
- `implements`: Optional custom repository interface for domain-specific methods

### 2. Connection Management: `DynamoConnection`

```dart
class DynamoConnection {
  DynamoConnection({
    required this.region,
    this.credentials,
    this.endpoint,
  });
  
  factory DynamoConnection.local({int port = 8000});
  
  final String region;
  final AwsClientCredentials? credentials;
  final String? endpoint;
  
  DynamoDB get client;
  void dispose();
}
```

**Purpose**: Manages DynamoDB client lifecycle and configuration.

**Key Features**:
- Supports AWS credentials or default credential chain
- Custom endpoint support for DynamoDB Local/LocalStack
- Lazy client initialization
- Resource cleanup via dispose()

### 3. Conversion Utility: `AttributeValueConverter`

```dart
class AttributeValueConverter {
  static AttributeValue jsonToAttributeValue(dynamic value);
  static dynamic attributeValueToJson(AttributeValue attr);
  static Map<String, AttributeValue> jsonMapToAttributeMap(Map<String, dynamic> json);
  static Map<String, dynamic> attributeMapToJsonMap(Map<String, AttributeValue> attrs);
}
```

**Purpose**: Converts between JSON and DynamoDB AttributeValue format.

**Conversion Rules**:
- `null` → `{NULL: true}`
- `bool` → `{BOOL: value}`
- `String` → `{S: value}`
- `num` → `{N: value.toString()}`
- `List` → `{L: [converted items]}`
- `Map` → `{M: {converted entries}}`

### 4. Generated Repository (Concrete)

Generated when no custom interface or interface has only base methods:

```dart
class UserDynamoRepository implements Repository<User> {
  UserDynamoRepository(this._connection);
  
  final DynamoConnection _connection;
  String get tableName => 'users';
  final _serializer = UserJsonSerializer();
  
  @override
  Future<User> getById(UuidValue id);
  
  @override
  Future<void> save(User aggregate);
  
  @override
  Future<void> deleteById(UuidValue id);
  
  // Table creation utilities
  static CreateTableInput createTableDefinition(String tableName);
  Future<void> createTable();
  static String getCreateTableCommand(String tableName);
  static String getCloudFormationTemplate(String tableName);
}
```

### 5. Generated Repository (Abstract Base)

Generated when custom interface has additional methods:

```dart
abstract class UserDynamoRepositoryBase implements UserRepository {
  UserDynamoRepositoryBase(this._connection);
  
  final DynamoConnection _connection;
  String get tableName => 'users';
  final _serializer = UserJsonSerializer();
  
  // Concrete implementations of base methods
  @override
  Future<User> getById(UuidValue id);
  
  @override
  Future<void> save(User aggregate);
  
  @override
  Future<void> deleteById(UuidValue id);
  
  // Abstract declarations for custom methods
  @override
  Future<User?> findByEmail(String email);
  
  // Table creation utilities
  static CreateTableInput createTableDefinition(String tableName);
  Future<void> createTable();
  static String getCreateTableCommand(String tableName);
  static String getCloudFormationTemplate(String tableName);
}
```

### 6. Code Generator: `DynamoRepositoryGenerator`

```dart
class DynamoRepositoryGenerator extends GeneratorForAnnotation<GenerateDynamoRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  );
  
  // Validation methods
  bool _extendsAggregateRoot(ClassElement element);
  bool _hasSerializableAnnotation(ClassElement element);
  
  // Configuration extraction
  String _extractTableName(ConstantReader annotation, String className);
  InterfaceType? _extractImplementsInterface(ConstantReader annotation);
  
  // Generation methods
  String _generateConcreteRepository(...);
  String _generateAbstractBaseRepository(...);
  String _generateGetByIdMethod(String className);
  String _generateSaveMethod(String className);
  String _generateDeleteByIdMethod(String className);
  String _generateTableCreationMethods(String className, String tableName);
  String _generateExceptionMappingMethod();
}
```

## Data Models

### DynamoDB Item Structure

Each aggregate is stored as a DynamoDB item with the following structure:

```json
{
  "id": {"S": "550e8400-e29b-41d4-a716-446655440000"},
  "firstName": {"S": "John"},
  "lastName": {"S": "Doe"},
  "email": {"S": "john@example.com"},
  "createdAt": {"S": "2024-01-15T10:30:00.000Z"},
  "updatedAt": {"S": "2024-01-15T10:30:00.000Z"}
}
```

**Key Attributes**:
- `id`: Partition key (String) - the aggregate's UUID
- All other fields: Serialized from JSON using AttributeValue types

### Table Schema

```
Table Name: users (or custom name from annotation)
Partition Key: id (String)
Sort Key: None
Attributes: Dynamic based on aggregate structure
Billing Mode: On-demand (recommended) or Provisioned
```

### AttributeValue Type Mapping

| JSON Type | AttributeValue Type | Example |
|-----------|-------------------|---------|
| null | NULL | `{NULL: true}` |
| boolean | BOOL | `{BOOL: true}` |
| string | S | `{S: "value"}` |
| number | N | `{N: "123.45"}` |
| array | L | `{L: [{S: "a"}, {S: "b"}]}` |
| object | M | `{M: {key: {S: "value"}}}` |


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Repository round-trip persistence

*For any* valid aggregate instance, saving it to the repository and then retrieving it by ID should return an equivalent aggregate with the same field values.

**Validates: Requirements 2.1, 2.3**

### Property 2: Repository upsert behavior

*For any* aggregate instance, saving it twice (with modifications between saves) should result in only one item in DynamoDB with the updated values, not two separate items.

**Validates: Requirements 2.4**

### Property 3: Repository deletion removes items

*For any* aggregate instance that has been saved, deleting it by ID should result in subsequent getById calls throwing a RepositoryException with type notFound.

**Validates: Requirements 2.5, 2.2, 2.6**

### Property 4: AttributeValue conversion round-trip

*For any* valid JSON object (Map<String, dynamic>), converting it to AttributeValue format and back to JSON should produce an equivalent object.

**Validates: Requirements 3.3, 3.4**

### Property 5: Table name snake_case conversion

*For any* class name in PascalCase, converting it to snake_case should follow the pattern of inserting underscores before capital letters and lowercasing all characters (e.g., UserProfile → user_profile, OrderItem → order_item).

**Validates: Requirements 1.5**

### Property 6: DynamoDB exception mapping

*For any* DynamoDB operation that throws a ResourceNotFoundException, the system should map it to a RepositoryException with type notFound.

**Validates: Requirements 6.1**

### Property 7: Unknown exception handling

*For any* DynamoDB operation that throws an unrecognized exception type, the system should map it to a RepositoryException with type unknown and preserve the original exception as the cause.

**Validates: Requirements 6.5**

## Error Handling

### Exception Mapping Strategy

All DynamoDB exceptions are mapped to `RepositoryException` types from the dddart package:

| DynamoDB Exception | RepositoryExceptionType | Scenario |
|-------------------|------------------------|----------|
| ResourceNotFoundException | notFound | Item or table doesn't exist |
| ConditionalCheckFailedException | duplicate | Conditional write failed |
| Network/connectivity errors | connection | Cannot reach DynamoDB |
| Timeout exceptions | timeout | Operation exceeded time limit |
| All other exceptions | unknown | Unexpected errors |

### Error Handling Patterns

#### Pattern 1: Not Found Handling

```dart
try {
  final user = await userRepo.getById(userId);
  return user;
} on RepositoryException catch (e) {
  if (e.type == RepositoryExceptionType.notFound) {
    return null; // Or handle appropriately
  }
  rethrow;
}
```

#### Pattern 2: Retry Logic for Transient Errors

```dart
Future<User> getUserWithRetry(UuidValue id, {int maxRetries = 3}) async {
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await userRepo.getById(id);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.timeout || 
          e.type == RepositoryExceptionType.connection) {
        if (attempt == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: attempt + 1));
        continue;
      }
      rethrow;
    }
  }
  throw StateError('Should not reach here');
}
```

#### Pattern 3: Table Creation Error Handling

```dart
try {
  await userRepo.createTable();
} on RepositoryException catch (e) {
  if (e.message.contains('Table already exists')) {
    // Table exists, continue
    return;
  }
  rethrow;
}
```

### Validation Errors

Code generation validation errors are thrown as `InvalidGenerationSourceError`:

- Class doesn't extend AggregateRoot
- Class missing @Serializable annotation
- Invalid annotation parameters

These are build-time errors that prevent code generation.

## Testing Strategy

### Unit Testing

Unit tests will verify specific behaviors and edge cases:

**Code Generator Tests**:
- Validate error messages for invalid annotations
- Verify table name generation from class names
- Verify concrete vs abstract base class generation logic
- Verify generated code structure and method signatures

**Connection Tests**:
- Verify client initialization with various configurations
- Verify custom endpoint configuration
- Verify error handling for uninitialized client access

**Conversion Tests**:
- Verify JSON to AttributeValue conversion for all types
- Verify AttributeValue to JSON conversion for all types
- Verify handling of null values
- Verify handling of nested structures

**Table Creation Tests**:
- Verify CreateTableInput structure
- Verify AWS CLI command format
- Verify CloudFormation template format

### Property-Based Testing

Property-based tests will verify universal properties across many inputs using the `test` package with custom generators:

**Testing Framework**: Dart's built-in `test` package with custom property-based testing utilities

**Minimum Iterations**: Each property test will run at least 100 iterations with randomly generated inputs

**Property Test Annotations**: Each property-based test will include a comment explicitly referencing the correctness property:
- Format: `// Feature: dynamodb-repository, Property N: [property description]`
- Example: `// Feature: dynamodb-repository, Property 1: Repository round-trip persistence`

**Property Tests**:

1. **Round-trip persistence** (Property 1):
   - Generate random aggregate instances
   - Save to repository
   - Retrieve by ID
   - Verify equivalence

2. **Upsert behavior** (Property 2):
   - Generate random aggregate instances
   - Save, modify, save again
   - Verify only one item exists with updated values

3. **Deletion removes items** (Property 3):
   - Generate random aggregate instances
   - Save, then delete
   - Verify getById throws notFound exception

4. **AttributeValue round-trip** (Property 4):
   - Generate random JSON objects
   - Convert to AttributeValue and back
   - Verify equivalence

5. **Snake case conversion** (Property 5):
   - Generate random PascalCase class names
   - Convert to snake_case
   - Verify correct format

6. **Exception mapping** (Property 6, 7):
   - Trigger various DynamoDB exceptions
   - Verify correct RepositoryException types

**Test Generators**:
- Aggregate generator: Creates random aggregate instances with varied field values
- JSON generator: Creates random JSON structures with all supported types
- Class name generator: Creates random PascalCase identifiers

### Integration Testing

Integration tests will verify end-to-end functionality with real DynamoDB Local:

**Setup Requirements**:
- DynamoDB Local running on localhost:8000
- Tables created before tests
- Cleanup after tests

**Integration Test Scenarios**:
- Complete CRUD workflow with generated repositories
- Custom repository interface implementation
- Table creation utilities
- Error handling with real DynamoDB errors
- Multiple aggregate types in same database

**Test Tags**:
- Tag integration tests with `@Tags(['requires-dynamodb-local'])`
- Allow exclusion in CI environments without DynamoDB Local

### Test Organization

```
test/
├── generator_test.dart              # Code generator unit tests
├── connection_test.dart             # Connection management unit tests
├── attribute_converter_test.dart    # Conversion logic unit tests
├── table_creation_test.dart         # Table creation utilities tests
├── repository_property_test.dart    # Property-based tests
├── repository_integration_test.dart # Integration tests (tagged)
├── test_helpers.dart                # Shared test utilities
└── test_models.dart                 # Test aggregate definitions
```

### Testing Best Practices

1. **Isolation**: Each test should be independent and not rely on execution order
2. **Cleanup**: Integration tests must clean up created tables and items
3. **Mocking**: Unit tests should mock DynamoDB client when appropriate
4. **Real Testing**: Integration tests should use real DynamoDB Local, not mocks
5. **Error Cases**: Test both success and failure scenarios
6. **Edge Cases**: Test boundary conditions (empty strings, null values, large objects)

## Implementation Notes

### AWS SDK Integration

The package will use `aws_dynamodb_api` from the official AWS SDK for Dart:

```yaml
dependencies:
  aws_dynamodb_api: ^2.0.0
```

**Key Classes**:
- `DynamoDB`: Main client class for DynamoDB operations
- `AwsClientCredentials`: Credentials configuration
- `GetItemInput`, `PutItemInput`, `DeleteItemInput`: Operation request objects
- `AttributeValue`: DynamoDB's typed value representation

### Code Generation Configuration

The package will use `build.yaml` to configure the code generator:

```yaml
builders:
  dynamo_repository:
    import: "package:dddart_repository_dynamodb/src/generators/dynamo_repository_generator.dart"
    builder_factories: ["dynamoRepositoryBuilder"]
    build_extensions: {".dart": [".dynamo_repository.g.dart"]}
    auto_apply: dependents
    build_to: source
```

### Generated File Naming

Generated files will follow the pattern: `{filename}.dynamo_repository.g.dart`

Example:
- Source: `lib/domain/user.dart`
- Generated: `lib/domain/user.dynamo_repository.g.dart`

### Part Directive

Source files must include a part directive:

```dart
part 'user.dynamo_repository.g.dart';
```

### DynamoDB Local Setup

For local development and testing:

```bash
# Using Docker
docker run -p 8000:8000 amazon/dynamodb-local

# Using AWS CLI to create table
aws dynamodb create-table \
  --table-name users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:8000
```

### Performance Considerations

1. **Connection Reuse**: Create one DynamoConnection per application, not per request
2. **Batch Operations**: For bulk operations, consider using BatchWriteItem (future enhancement)
3. **Consistent Reads**: Default to eventually consistent reads for better performance
4. **Projection Expressions**: For custom queries, use projection expressions to retrieve only needed attributes
5. **Pagination**: For scan/query operations, implement pagination for large result sets

### Security Considerations

1. **Credentials**: Never hardcode AWS credentials - use environment variables or IAM roles
2. **Least Privilege**: Use IAM policies with minimum required permissions
3. **Encryption**: Enable encryption at rest for production tables
4. **VPC Endpoints**: Use VPC endpoints for DynamoDB in production to avoid internet traffic
5. **Input Validation**: Validate aggregate data before persistence

### Limitations and Future Enhancements

**Current Limitations**:
- Single-table design only (one aggregate type per table)
- No support for Global Secondary Indexes (GSI) or Local Secondary Indexes (LSI)
- No batch operations (BatchGetItem, BatchWriteItem)
- No transactions (TransactWriteItems, TransactGetItems)
- No DynamoDB Streams integration

**Future Enhancements**:
- Support for GSI/LSI in custom repository methods
- Batch operation helpers
- Transaction support for multi-aggregate operations
- DynamoDB Streams integration for event sourcing
- Query and Scan operation builders
- Conditional write helpers
- TTL (Time To Live) support
