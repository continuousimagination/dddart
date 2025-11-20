# DDDart MongoDB Repository Examples

This directory contains comprehensive examples demonstrating how to use `dddart_repository_mongodb` for MongoDB persistence in DDDart applications.

## Prerequisites

Before running these examples, you need:

1. **Dart SDK** (>=3.0.0)
2. **MongoDB** running locally or accessible remotely
   - Default examples use `localhost:27017`
   - No authentication required for local examples
   - Database name: `dddart_example`

### Installing MongoDB

**macOS (using Homebrew):**
```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

**Ubuntu/Debian:**
```bash
sudo apt-get install mongodb
sudo systemctl start mongodb
```

**Windows:**
Download and install from [MongoDB Download Center](https://www.mongodb.com/try/download/community)

**Docker:**
```bash
docker run -d -p 27017:27017 --name mongodb mongo:latest
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
- Creating a MongoDB connection
- Opening and closing connections
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
- `MongoConnection` for connection management
- Generated `UserMongoRepository` for CRUD operations
- Proper connection lifecycle (open/close)

---

### 2. Custom Interface Example

**File:** `custom_interface_example.dart`

**What it demonstrates:**
- Defining custom repository interfaces
- Using `@GenerateMongoRepository(implements: ...)` annotation
- Extending generated abstract base classes
- Implementing custom query methods
- Using both generated and custom methods

**Run:**
```bash
dart run custom_interface_example.dart
```

**Key concepts:**
- `UserRepository` interface with custom methods
- `UserWithCustomRepoMongoRepositoryBase` generated abstract class
- `UserWithCustomRepoMongoRepository` concrete implementation
- Custom queries: `findByEmail()`, `findByLastName()`

---

### 3. Error Handling Example

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
- Graceful error recovery
- Logging and continuing execution

---

### 4. Configuration Integration Example

**File:** `config_integration_example.dart`

**What it demonstrates:**
- Loading MongoDB configuration from YAML files
- Using `dddart_config` for configuration management
- Environment variable support
- AWS DocumentDB configuration
- Secure credential handling

**Run:**
```bash
dart run config_integration_example.dart
```

**Optional:** Create a `config.yaml` file:
```yaml
mongodb:
  host: localhost
  port: 27017
  database: dddart_example
  # Optional authentication
  # username: myuser
  # password: mypassword
  # authSource: admin
```

**Key concepts:**
- `YamlConfigProvider` for file-based configuration
- `Configuration.load()` for loading config
- Extracting MongoDB settings from config
- TLS configuration for AWS DocumentDB

---

### 5. Repository Swapping Example

**File:** `repository_swapping_example.dart`

**What it demonstrates:**
- Using `InMemoryRepository` for testing
- Using MongoDB repository for production
- Writing implementation-independent business logic
- Benefits of repository pattern abstraction
- Fast unit testing without database

**Run:**
```bash
dart run repository_swapping_example.dart
```

**Key concepts:**
- `Repository<T>` interface abstraction
- `InMemoryRepository<T>` for testing
- Implementation swapping without code changes
- Test-driven development patterns

---

## Domain Models

The examples use the following domain models located in `lib/domain/`:

### User
Simple aggregate demonstrating basic MongoDB repository usage:
- `User` - Basic user aggregate with first name, last name, and email
- `UserMongoRepository` - Generated concrete repository

### UserWithCustomRepo
Aggregate demonstrating custom repository interfaces:
- `UserWithCustomRepo` - User aggregate with custom repository
- `UserRepository` - Custom interface with domain-specific methods
- `UserWithCustomRepoMongoRepositoryBase` - Generated abstract base class
- `UserWithCustomRepoMongoRepository` - Concrete implementation with custom queries

### Product
Additional aggregate for examples:
- `Product` - Product aggregate with name, description, price, and stock status
- `ProductMongoRepository` - Generated concrete repository

## Code Generation

The examples use code generation for:

1. **JSON Serialization** (`dddart_json`)
   - Generates `*.g.dart` files with `JsonSerializer` classes
   - Handles aggregate serialization to/from JSON

2. **MongoDB Repositories** (`dddart_repository_mongodb`)
   - Generates `*.mongo_repository.g.part` files
   - Creates concrete or abstract base repository classes
   - Implements CRUD operations

To regenerate code after changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Common Issues

### MongoDB Connection Failed
**Error:** `Connection refused` or `Failed to connect`

**Solution:**
- Ensure MongoDB is running: `brew services list` (macOS) or `sudo systemctl status mongodb` (Linux)
- Check MongoDB is listening on port 27017
- Try connecting with `mongosh` to verify

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

## Next Steps

After exploring these examples:

1. **Create your own aggregates** with `@Serializable()` and `@GenerateMongoRepository()`
2. **Define custom repository interfaces** for domain-specific queries
3. **Implement custom query methods** using MongoDB queries
4. **Write tests** using `InMemoryRepository` for fast unit tests
5. **Configure production** using `dddart_config` for environment-specific settings

## Additional Resources

- [DDDart Documentation](https://github.com/continuousimagination/dddart)
- [MongoDB Dart Driver](https://pub.dev/packages/mongo_dart)
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/continuousimagination/dddart/issues
- Documentation: https://github.com/continuousimagination/dddart

## License

These examples are part of the DDDart project and are licensed under the MIT License.
