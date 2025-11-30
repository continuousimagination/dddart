# DDDart DynamoDB Repository Examples

This directory contains comprehensive examples demonstrating how to use `dddart_repository_dynamodb` for DynamoDB persistence in DDDart applications.

## Prerequisites

Before running these examples, you need:

1. **Dart SDK** (>=3.0.0)
2. **DynamoDB Local** running locally
   - Default examples use `localhost:8000`
   - No AWS credentials required for local examples

### Installing DynamoDB Local

**Using Docker (Recommended):**
```bash
docker run -p 8000:8000 amazon/dynamodb-local
```

**Using AWS CLI:**
```bash
# Download DynamoDB Local
wget https://s3.us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz
tar -xzf dynamodb_local_latest.tar.gz

# Run DynamoDB Local
java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb
```

**Verify DynamoDB Local is running:**
```bash
aws dynamodb list-tables --endpoint-url http://localhost:8000
```

## Setup

1. Install dependencies:
```bash
dart pub get
```

2. Generate code (serializers and repositories):
```bash
dart run build_runner build
```

## Examples

### 1. Basic CRUD Example

**File:** `basic_crud_example.dart`

**What it demonstrates:**
- Creating a DynamoDB connection
- Creating and saving aggregates
- Retrieving aggregates by ID
- Updating aggregates
- Deleting aggregates
- Basic error handling

**Run:**
```bash
dart run basic_crud_example.dart
```

**Key concepts:**
- `DynamoConnection` for connection management
- `DynamoConnection.local()` factory for local development
- Generated `UserDynamoRepository` for CRUD operations
- Proper connection lifecycle (dispose)

---

### 2. Custom Interface Example

**File:** `custom_interface_example.dart`

**What it demonstrates:**
- Defining custom repository interfaces
- Using `@GenerateDynamoRepository(implements: ...)` annotation
- Extending generated abstract base classes
- Implementing custom query methods using DynamoDB Scan
- Using both generated and custom methods

**Run:**
```bash
dart run custom_interface_example.dart
```

**Key concepts:**
- `UserRepository` interface with custom methods
- `UserWithCustomRepoDynamoRepositoryBase` generated abstract class
- `UserWithCustomRepoDynamoRepository` concrete implementation
- Custom queries: `findByEmail()`, `findByLastName()`
- DynamoDB Scan operations with filter expressions

---

### 3. Local Development Example

**File:** `local_development_example.dart`

**What it demonstrates:**
- Configuring DynamoDB Local connection
- Using the local factory constructor
- Creating tables programmatically
- Testing with local DynamoDB instance
- Benefits of local development workflow

**Run:**
```bash
dart run local_development_example.dart
```

**Key concepts:**
- `DynamoConnection.local()` for local development
- Custom port configuration
- Programmatic table creation
- Offline development workflow
- Fast iteration cycle

---

### 4. Table Creation Example

**File:** `table_creation_example.dart`

**What it demonstrates:**
- Creating tables programmatically
- Getting AWS CLI commands for table creation
- Getting CloudFormation templates
- Getting CreateTableInput definitions
- Best practices for table management

**Run:**
```bash
dart run table_creation_example.dart
```

**Key concepts:**
- `createTable()` method for programmatic creation
- `createTableDefinition()` for CreateTableInput
- `getCreateTableCommand()` for AWS CLI commands
- `getCloudFormationTemplate()` for IaC
- PAY_PER_REQUEST billing mode

---

### 5. Error Handling Example

**File:** `error_handling_example.dart`

**What it demonstrates:**
- Handling `RepositoryException.notFound`
- Handling connection errors
- Proper try-catch patterns
- Error type checking and recovery strategies
- Graceful degradation

**Run:**
```bash
dart run error_handling_example.dart
```

**Key concepts:**
- `RepositoryException` types
- Pattern matching on exception types
- Retry logic for transient errors
- Graceful error recovery
- Null return patterns for optional lookups

---

## Domain Models

The examples use the following domain models located in `lib/domain/`:

### User
Simple aggregate demonstrating basic DynamoDB repository usage:
- `User` - Basic user aggregate with first name, last name, and email
- `UserDynamoRepository` - Generated concrete repository

### UserWithCustomRepo
Aggregate demonstrating custom repository interfaces:
- `UserWithCustomRepo` - User aggregate with custom repository
- `UserRepository` - Custom interface with domain-specific methods
- `UserWithCustomRepoDynamoRepositoryBase` - Generated abstract base class
- `UserWithCustomRepoDynamoRepository` - Concrete implementation with custom queries

### Product
Additional aggregate for examples:
- `Product` - Product aggregate with name, description, price, and stock status
- `ProductDynamoRepository` - Generated concrete repository

## Code Generation

The examples use code generation for:

1. **JSON Serialization** (`dddart_json`)
   - Generates `*.g.dart` files with `JsonSerializer` classes
   - Handles aggregate serialization to/from JSON

2. **DynamoDB Repositories** (`dddart_repository_dynamodb`)
   - Generates `*.dynamo_repository.g.dart` files
   - Creates concrete or abstract base repository classes
   - Implements CRUD operations with DynamoDB AttributeValue conversion

To regenerate code after changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Common Issues

### DynamoDB Local Connection Failed
**Error:** `Connection refused` or `Failed to connect`

**Solution:**
- Ensure DynamoDB Local is running on port 8000
- Check with: `docker ps` (if using Docker)
- Try: `curl http://localhost:8000` (should return error page)
- Restart DynamoDB Local if needed

### Table Not Found
**Error:** `ResourceNotFoundException` or table not found

**Solution:**
- Run `table_creation_example.dart` first to create tables
- Or manually create tables using AWS CLI:
```bash
aws dynamodb create-table \
  --table-name users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:8000
```

### Build Runner Errors
**Error:** `Could not format because the source could not be parsed`

**Solution:**
- Run `dart run build_runner clean`
- Then `dart run build_runner build --delete-conflicting-outputs`
- Check for syntax errors in domain models

### Import Errors
**Error:** `Target of URI doesn't exist`

**Solution:**
- Run `dart pub get` to install dependencies
- Ensure code generation has completed successfully
- Check that generated files exist in `lib/domain/`

## AWS Production Usage

For production AWS usage, configure credentials:

```dart
final connection = DynamoConnection(
  region: 'us-east-1',
  credentials: AwsClientCredentials(
    accessKey: Platform.environment['AWS_ACCESS_KEY_ID']!,
    secretKey: Platform.environment['AWS_SECRET_ACCESS_KEY']!,
  ),
);
```

**Best practices:**
- Use IAM roles instead of hardcoded credentials
- Use environment variables for configuration
- Create tables using CloudFormation or Terraform
- Use separate tables per environment
- Enable encryption at rest
- Use VPC endpoints for security
- Monitor with CloudWatch

## Next Steps

After exploring these examples:

1. **Create your own aggregates** with `@Serializable()` and `@GenerateDynamoRepository()`
2. **Define custom repository interfaces** for domain-specific queries
3. **Implement custom query methods** using DynamoDB operations
4. **Write tests** using `InMemoryRepository` for fast unit tests
5. **Configure production** using environment variables
6. **Deploy tables** using CloudFormation or Terraform

## Performance Considerations

- **Connection Reuse**: Create one `DynamoConnection` per application, not per request
- **Batch Operations**: For bulk operations, consider using BatchWriteItem (future enhancement)
- **Consistent Reads**: Default to eventually consistent reads for better performance
- **Projection Expressions**: For custom queries, retrieve only needed attributes
- **Pagination**: For scan/query operations, implement pagination for large result sets

## Additional Resources

- [DDDart Documentation](https://github.com/continuousimagination/dddart)
- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/continuousimagination/dddart/issues
- Documentation: https://github.com/continuousimagination/dddart

## License

These examples are part of the DDDart project and are licensed under the MIT License.
