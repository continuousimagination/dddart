# Design Document

## Overview

The `dddart_repository_rest` package provides a code-generated REST API-backed repository implementation for DDDart aggregate roots. This package enables distributed domain-driven design architectures where aggregates are persisted via HTTP rather than direct database access, allowing for microservices and remote data storage scenarios.

The package follows the established patterns from `dddart_repository_mongodb`, `dddart_repository_dynamodb`, and `dddart_repository_sqlite`, ensuring consistency across the DDDart ecosystem. It leverages existing infrastructure including `dddart_json` for serialization and `dddart_rest_client` for HTTP communication with automatic authentication.

### Key Design Principles

1. **Consistency**: Follow the same annotation and generation patterns as other repository packages
2. **Reuse**: Leverage existing `dddart_json` serializers and `dddart_rest_client` for HTTP
3. **Extensibility**: Support custom repository interfaces for domain-specific queries
4. **Type Safety**: Generate compile-time safe code with proper error handling
5. **Testability**: Design for comprehensive testing including integration tests with real HTTP communication

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Application                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  @Serializable()                                      │  │
│  │  @GenerateRestRepository(resourcePath: '/users')     │  │
│  │  class User extends AggregateRoot { ... }            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ build_runner
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Generated Repository Code                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  class UserRestRepository                            │  │
│  │    implements Repository<User> {                     │  │
│  │    - RestConnection _connection                      │  │
│  │    - UserJsonSerializer _serializer                  │  │
│  │    + Future<User> getById(UuidValue id)             │  │
│  │    + Future<void> save(User aggregate)              │  │
│  │    + Future<void> deleteById(UuidValue id)          │  │
│  │  }                                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ uses
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              dddart_repository_rest                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  RestConnection                                       │  │
│  │    - String baseUrl                                   │  │
│  │    - RestClient client                                │  │
│  │    - AuthProvider? authProvider                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ uses
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              dddart_rest_client                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  RestClient                                           │  │
│  │    + Future<Response> get(path)                      │  │
│  │    + Future<Response> put(path, body)                │  │
│  │    + Future<Response> delete(path)                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Remote REST API                           │
│              (e.g., dddart_rest server)                      │
└─────────────────────────────────────────────────────────────┘
```


## Components and Interfaces

### 1. Annotation: `@GenerateRestRepository`

The annotation that marks aggregate roots for REST repository generation.

```dart
class GenerateRestRepository {
  const GenerateRestRepository({
    this.resourcePath,
    this.implements,
  });
  
  /// The REST API resource path (e.g., '/users', '/orders')
  /// If null, generates from class name (User -> 'users', OrderItem -> 'order-items')
  final String? resourcePath;
  
  /// Optional custom repository interface to implement
  /// If provided with custom methods, generates abstract base class
  /// If null or only has base methods, generates concrete class
  final Type? implements;
}
```

### 2. Connection: `RestConnection`

Manages the HTTP client and authentication for REST API communication.

```dart
class RestConnection {
  RestConnection({
    required this.baseUrl,
    this.authProvider,
    http.Client? httpClient,
  }) : _client = RestClient(
         baseUrl: baseUrl,
         authProvider: authProvider,
         httpClient: httpClient,
       );
  
  /// The base URL of the REST API (e.g., 'https://api.example.com')
  final String baseUrl;
  
  /// Optional authentication provider for obtaining access tokens
  final AuthProvider? authProvider;
  
  /// The REST client for making HTTP requests
  final RestClient _client;
  
  /// Get the REST client instance
  RestClient get client => _client;
  
  /// Dispose the connection and release resources
  void dispose() {
    _client.close();
  }
}
```

### 3. Generator: `RestRepositoryGenerator`

The code generator that processes `@GenerateRestRepository` annotations.

```dart
class RestRepositoryGenerator extends GeneratorForAnnotation<GenerateRestRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // 1. Validate element is a ClassElement
    // 2. Validate class extends AggregateRoot
    // 3. Validate class has @Serializable annotation
    // 4. Extract resourcePath and implements from annotation
    // 5. Determine if concrete or abstract base class is needed
    // 6. Generate appropriate repository code
  }
}
```

### 4. Generated Repository Classes

#### Concrete Repository (No Custom Interface)

```dart
class UserRestRepository implements Repository<User> {
  UserRestRepository(this._connection);
  
  final RestConnection _connection;
  final _serializer = UserJsonSerializer();
  String get _resourcePath => 'users';
  
  @override
  Future<User> getById(UuidValue id) async {
    try {
      final response = await _connection.client.get('$_resourcePath/${id.value}');
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _serializer.fromJson(json);
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to retrieve User: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
  
  @override
  Future<void> save(User aggregate) async {
    try {
      final json = _serializer.toJson(aggregate);
      final body = jsonEncode(json);
      
      final response = await _connection.client.put(
        '$_resourcePath/${aggregate.id.value}',
        body: body,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to save User: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
  
  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final response = await _connection.client.delete('$_resourcePath/${id.value}');
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to delete User: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
  
  RepositoryException _mapHttpException(int statusCode, String body) {
    switch (statusCode) {
      case 404:
        return RepositoryException(
          'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      case 409:
        return RepositoryException(
          'Duplicate resource',
          type: RepositoryExceptionType.duplicate,
        );
      case 408:
      case 504:
        return RepositoryException(
          'Request timeout',
          type: RepositoryExceptionType.timeout,
        );
      case >= 500:
        return RepositoryException(
          'Server error: $statusCode',
          type: RepositoryExceptionType.connection,
        );
      default:
        return RepositoryException(
          'HTTP error $statusCode: $body',
          type: RepositoryExceptionType.unknown,
        );
    }
  }
}
```


#### Abstract Base Repository (Custom Interface)

```dart
abstract class UserRestRepositoryBase implements UserRepository {
  UserRestRepositoryBase(this._connection);
  
  final RestConnection _connection;
  final _serializer = UserJsonSerializer();
  String get _resourcePath => 'users';
  
  // Concrete implementations of base Repository methods (same as above)
  @override
  Future<User> getById(UuidValue id) async { /* ... */ }
  
  @override
  Future<void> save(User aggregate) async { /* ... */ }
  
  @override
  Future<void> deleteById(UuidValue id) async { /* ... */ }
  
  RepositoryException _mapHttpException(int statusCode, String body) { /* ... */ }
  
  // Abstract methods from custom interface
  @override
  Future<User?> findByEmail(String email);
  
  @override
  Future<List<User>> findByLastName(String lastName);
}
```

User extends and implements custom methods:

```dart
class UserRestRepository extends UserRestRepositoryBase {
  UserRestRepository(super.connection);
  
  @override
  Future<User?> findByEmail(String email) async {
    try {
      final response = await _connection.client.get('$_resourcePath?email=$email');
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        if (json.isEmpty) return null;
        return _serializer.fromJson(json.first as Map<String, dynamic>);
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to find user by email: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
  
  @override
  Future<List<User>> findByLastName(String lastName) async {
    try {
      final response = await _connection.client.get('$_resourcePath?lastName=$lastName');
      
      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;
        return jsonList
            .map((json) => _serializer.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to find users by last name: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
}
```

## Data Models

### RestConnection

The connection object that encapsulates HTTP client configuration and authentication.

**Fields:**
- `baseUrl: String` - The base URL of the REST API
- `authProvider: AuthProvider?` - Optional authentication provider
- `_client: RestClient` - The underlying HTTP client

**Methods:**
- `RestConnection({required baseUrl, authProvider, httpClient})` - Constructor
- `RestClient get client` - Access the HTTP client
- `void dispose()` - Clean up resources

### GenerateRestRepository Annotation

The annotation for marking aggregate roots for code generation.

**Fields:**
- `resourcePath: String?` - Optional custom resource path
- `implements: Type?` - Optional custom repository interface

### HTTP Response Mapping

The generator creates code that maps HTTP status codes to repository exceptions:

| HTTP Status | RepositoryExceptionType | Description |
|-------------|------------------------|-------------|
| 200, 204 | Success | Operation completed successfully |
| 404 | notFound | Resource not found |
| 409 | duplicate | Duplicate resource (conflict) |
| 408, 504 | timeout | Request timeout |
| 500-599 | connection | Server error |
| Other | unknown | Unexpected error |


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Code generation produces valid Dart code

*For any* aggregate root class that extends `AggregateRoot` and has `@Serializable()` and `@GenerateRestRepository()` annotations, the code generator should produce syntactically valid Dart code that compiles without errors.
**Validates: Requirements 1.1**

### Property 2: Resource path configuration is respected

*For any* specified `resourcePath` in the annotation, all generated HTTP requests should use that exact path in the URL construction.
**Validates: Requirements 1.2**

### Property 3: Resource path generation follows naming convention

*For any* class name when `resourcePath` is omitted, the generated path should be the class name converted to lowercase with pluralization (e.g., User → users, OrderItem → order-items).
**Validates: Requirements 1.3**

### Property 4: Custom interface determines class type

*For any* annotation with a custom interface containing methods beyond base `Repository<T>`, the generator should produce an abstract base class; otherwise, it should produce a concrete class.
**Validates: Requirements 1.4, 1.5**

### Property 5: CRUD operations round-trip correctly

*For any* aggregate instance, saving it via `save()` and then retrieving it via `getById()` should return an equivalent aggregate with the same field values.
**Validates: Requirements 2.1, 2.2**

### Property 6: Delete removes aggregates

*For any* aggregate that has been saved, calling `deleteById()` followed by `getById()` should throw a `RepositoryException` with type `notFound`.
**Validates: Requirements 2.3**

### Property 7: Serialization uses dddart_json serializers

*For any* aggregate type, the generated repository should use the `{ClassName}JsonSerializer` for both `toJson()` and `fromJson()` operations.
**Validates: Requirements 3.1, 3.2, 3.3**

### Property 8: HTTP status codes map to correct exception types

*For any* HTTP response status code, the `_mapHttpException` method should return a `RepositoryException` with the correct type according to the status code mapping table.
**Validates: Requirements 4.1, 4.2, 4.3, 4.4**

### Property 9: Connection configuration is used consistently

*For any* `RestConnection` with a base URL, all HTTP requests made by repositories using that connection should use the configured base URL as the URL prefix.
**Validates: Requirements 5.1**

### Property 10: Authentication is applied when configured

*For any* `RestConnection` with an `AuthProvider`, all HTTP requests should include the authorization header with the access token obtained from the provider.
**Validates: Requirements 5.2, 7.2**

### Property 11: Multiple repositories share connection state

*For any* two repositories created with the same `RestConnection` instance, they should share the same HTTP client and authentication state.
**Validates: Requirements 5.5**

### Property 12: Custom interface methods are abstract

*For any* custom repository interface with methods beyond base `Repository<T>`, the generated base class should declare those methods as abstract.
**Validates: Requirements 6.1**

### Property 13: Protected members are accessible in subclasses

*For any* generated abstract base class, subclasses should have access to `_connection`, `_serializer`, `_resourcePath`, and `_mapHttpException`.
**Validates: Requirements 6.3, 6.5**

### Property 14: Integration test round-trip preserves data

*For any* aggregate instance, saving it via REST repository to a test server backed by in-memory repository, then retrieving it, should return an equivalent aggregate.
**Validates: Requirements 11.3**

## Error Handling

### Exception Hierarchy

All repository operations throw `RepositoryException` from the `dddart` package:

```dart
class RepositoryException implements Exception {
  RepositoryException(
    this.message, {
    required this.type,
    this.cause,
  });
  
  final String message;
  final RepositoryExceptionType type;
  final Object? cause;
}

enum RepositoryExceptionType {
  notFound,
  duplicate,
  connection,
  timeout,
  unknown,
}
```

### Error Mapping Strategy

The generated `_mapHttpException` method maps HTTP responses to repository exceptions:

1. **404 Not Found** → `RepositoryExceptionType.notFound`
   - Thrown when `getById()` or `deleteById()` targets a non-existent resource
   
2. **409 Conflict** → `RepositoryExceptionType.duplicate`
   - Thrown when `save()` attempts to create a duplicate resource
   
3. **408 Request Timeout, 504 Gateway Timeout** → `RepositoryExceptionType.timeout`
   - Thrown when the server takes too long to respond
   
4. **500-599 Server Errors** → `RepositoryExceptionType.connection`
   - Thrown when the server encounters an internal error
   
5. **Network Errors** → `RepositoryExceptionType.connection`
   - Thrown when HTTP client cannot reach the server
   
6. **Serialization Errors** → `RepositoryExceptionType.unknown`
   - Thrown when JSON serialization/deserialization fails
   
7. **Other HTTP Errors** → `RepositoryExceptionType.unknown`
   - Thrown for unexpected HTTP status codes

### Error Handling Patterns

```dart
// Pattern 1: Handle specific error types
try {
  final user = await userRepo.getById(userId);
} on RepositoryException catch (e) {
  switch (e.type) {
    case RepositoryExceptionType.notFound:
      return null; // User doesn't exist
    case RepositoryExceptionType.connection:
      throw ServiceUnavailableException();
    case RepositoryExceptionType.timeout:
      // Retry with exponential backoff
      await Future.delayed(Duration(seconds: 1));
      return await userRepo.getById(userId);
    default:
      rethrow;
  }
}

// Pattern 2: Retry transient errors
Future<User> getUserWithRetry(UuidValue id, {int maxAttempts = 3}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await userRepo.getById(id);
    } on RepositoryException catch (e) {
      if (e.type == RepositoryExceptionType.timeout ||
          e.type == RepositoryExceptionType.connection) {
        if (attempt == maxAttempts - 1) rethrow;
        await Future.delayed(Duration(seconds: math.pow(2, attempt).toInt()));
        continue;
      }
      rethrow;
    }
  }
  throw StateError('Unreachable');
}

// Pattern 3: Graceful degradation
Future<User?> findUserSafely(UuidValue id) async {
  try {
    return await userRepo.getById(id);
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.notFound) {
      return null;
    }
    logger.error('Failed to fetch user', error: e);
    return null;
  }
}
```


## Testing Strategy

### Overview

The testing strategy employs a dual approach combining unit tests and property-based tests to ensure comprehensive coverage and correctness verification.

### Unit Testing

Unit tests verify specific examples, edge cases, and integration points:

**Generator Tests:**
- Valid aggregate root with all annotations generates code
- Missing `@Serializable()` annotation fails with clear error
- Non-class element fails with clear error
- Class not extending `AggregateRoot` fails with clear error
- Custom interface with extra methods generates abstract base class
- Custom interface with only base methods generates concrete class
- Resource path annotation parameter is used in generated code
- Default resource path follows naming convention

**Connection Tests:**
- `RestConnection` stores base URL correctly
- `RestConnection` with auth provider includes auth headers
- `RestConnection` without auth provider makes unauthenticated requests
- `dispose()` closes the HTTP client
- Multiple repositories share the same connection instance

**Error Mapping Tests:**
- 404 status maps to `notFound` exception type
- 409 status maps to `duplicate` exception type
- 408/504 status maps to `timeout` exception type
- 5xx status maps to `connection` exception type
- Network errors map to `connection` exception type

### Property-Based Testing

Property-based tests verify universal properties across many randomly generated inputs using the `test` package with custom generators.

**Property Testing Library:** Dart's `test` package with custom property test helpers

**Minimum Iterations:** 100 runs per property test

**Property Test Tags:** Each property-based test must include a comment tag in this format:
```dart
// **Feature: rest-repository, Property 1: Code generation produces valid Dart code**
test('generated code compiles for any valid aggregate root', () { ... });
```

**Properties to Test:**

1. **Property 1: Code generation produces valid Dart code**
   - Generate random aggregate root classes with various field types
   - Run code generator on each
   - Verify generated code compiles without errors
   - **Validates: Requirements 1.1**

2. **Property 2: Resource path configuration is respected**
   - Generate random resource paths
   - Verify they appear in generated HTTP request URLs
   - **Validates: Requirements 1.2**

3. **Property 3: Resource path generation follows naming convention**
   - Generate random class names
   - Verify generated paths follow lowercase pluralization
   - **Validates: Requirements 1.3**

4. **Property 4: Custom interface determines class type**
   - Generate interfaces with and without custom methods
   - Verify correct class type (concrete vs abstract) is generated
   - **Validates: Requirements 1.4, 1.5**

5. **Property 5: CRUD operations round-trip correctly**
   - Generate random aggregate instances
   - Save, retrieve, and verify equivalence
   - **Validates: Requirements 2.1, 2.2**

6. **Property 6: Delete removes aggregates**
   - Generate random aggregates, save them
   - Delete and verify `getById` throws `notFound`
   - **Validates: Requirements 2.3**

7. **Property 7: Serialization uses dddart_json serializers**
   - Generate random aggregates
   - Verify serialization produces valid JSON matching serializer output
   - **Validates: Requirements 3.1, 3.2, 3.3**

8. **Property 8: HTTP status codes map to correct exception types**
   - Generate random HTTP status codes
   - Verify `_mapHttpException` returns correct exception type
   - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

9. **Property 9: Connection configuration is used consistently**
   - Generate random base URLs
   - Verify all requests use the configured base URL
   - **Validates: Requirements 5.1**

10. **Property 10: Authentication is applied when configured**
    - Generate random auth tokens
    - Verify requests include authorization headers
    - **Validates: Requirements 5.2, 7.2**

11. **Property 11: Multiple repositories share connection state**
    - Create multiple repositories with same connection
    - Verify they share HTTP client instance
    - **Validates: Requirements 5.5**

12. **Property 12: Custom interface methods are abstract**
    - Generate interfaces with custom methods
    - Verify generated base class declares them as abstract
    - **Validates: Requirements 6.1**

13. **Property 13: Protected members are accessible in subclasses**
    - Generate abstract base classes
    - Verify subclasses can access protected members
    - **Validates: Requirements 6.3, 6.5**

14. **Property 14: Integration test round-trip preserves data**
    - Generate random aggregates
    - Round-trip through REST repository → HTTP → in-memory repository
    - Verify data preservation
    - **Validates: Requirements 11.3**

### Integration Testing

Integration tests verify end-to-end functionality with real HTTP communication:

**Test Server Setup:**
```dart
// Create test server using dddart_rest with in-memory repository
final inMemoryRepo = InMemoryRepository<User>();
final serializer = UserJsonSerializer();

final server = HttpServer(port: 0); // Random port
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: inMemoryRepo,
    serializers: {'application/json': serializer},
  ),
);

await server.start();
final baseUrl = 'http://localhost:${server.port}';
```

**Test Scenarios:**
1. **Basic CRUD Operations**
   - Create user via REST repository
   - Verify it exists in in-memory repository
   - Retrieve via REST repository
   - Update via REST repository
   - Delete via REST repository
   - Verify it's gone from in-memory repository

2. **Authentication Flow**
   - Configure test server with JWT authentication
   - Create REST repository with auth provider
   - Verify authenticated requests succeed
   - Verify unauthenticated requests fail
   - Test token refresh scenario

3. **Error Handling**
   - Request non-existent resource (404)
   - Attempt duplicate creation (409)
   - Simulate server error (500)
   - Verify correct exception types

4. **Custom Query Methods**
   - Implement custom repository with query methods
   - Verify custom queries work end-to-end
   - Test pagination and filtering

**Test Cleanup:**
```dart
tearDown(() async {
  await server.stop();
});
```

### Test Organization

```
test/
├── generator_test.dart              # Unit tests for code generator
├── connection_test.dart             # Unit tests for RestConnection
├── error_mapping_test.dart          # Unit tests for HTTP error mapping
├── generator_property_test.dart     # Property tests for generator
├── crud_property_test.dart          # Property tests for CRUD operations
├── serialization_property_test.dart # Property tests for serialization
├── integration_test.dart            # Integration tests with test server
├── auth_integration_test.dart       # Integration tests with authentication
└── test_helpers.dart                # Shared test utilities and generators
```

### Test Helpers

```dart
// Random aggregate generator for property tests
User generateRandomUser() {
  return User(
    id: UuidValue.generate(),
    firstName: generateRandomString(10),
    lastName: generateRandomString(10),
    email: '${generateRandomString(8)}@example.com',
  );
}

// Test server factory
Future<TestServer> createTestServer<T extends AggregateRoot>({
  required Repository<T> repository,
  required Serializer<T> serializer,
  required String path,
  bool withAuth = false,
}) async {
  final server = HttpServer(port: 0);
  
  if (withAuth) {
    // Configure authentication
  }
  
  server.registerResource(
    CrudResource<T>(
      path: path,
      repository: repository,
      serializers: {'application/json': serializer},
    ),
  );
  
  await server.start();
  return TestServer(server, 'http://localhost:${server.port}');
}
```

### Coverage Goals

- **Line Coverage:** > 90%
- **Branch Coverage:** > 85%
- **Property Tests:** All 14 properties tested with 100+ iterations each
- **Integration Tests:** All CRUD operations, authentication, and error scenarios
- **Edge Cases:** Empty collections, null values, network failures, auth failures


## Implementation Details

### Package Structure

```
packages/dddart_repository_rest/
├── lib/
│   ├── dddart_repository_rest.dart          # Main library export
│   └── src/
│       ├── annotations/
│       │   └── generate_rest_repository.dart # Annotation definition
│       ├── connection/
│       │   └── rest_connection.dart          # Connection management
│       └── generators/
│           └── rest_repository_generator.dart # Code generator
├── test/
│   ├── generator_test.dart
│   ├── connection_test.dart
│   ├── error_mapping_test.dart
│   ├── generator_property_test.dart
│   ├── crud_property_test.dart
│   ├── serialization_property_test.dart
│   ├── integration_test.dart
│   ├── auth_integration_test.dart
│   └── test_helpers.dart
├── example/
│   ├── lib/
│   │   └── models/
│   │       ├── user.dart                     # Example aggregate
│   │       └── user.g.dart                   # Generated serializer
│   ├── basic_crud_example.dart               # Basic CRUD operations
│   ├── authentication_example.dart           # With authentication
│   ├── custom_repository_example.dart        # Custom query methods
│   └── error_handling_example.dart           # Error handling patterns
├── build.yaml                                # Build configuration
├── pubspec.yaml                              # Package dependencies
├── README.md                                 # Package documentation
├── CHANGELOG.md                              # Version history
└── LICENSE                                   # MIT license
```

### Dependencies

```yaml
dependencies:
  dddart: ^0.9.0
  dddart_serialization: ^0.9.0
  dddart_rest_client: ^0.1.0
  http: ^1.2.0
  build: ^2.4.0
  source_gen: ^1.4.0
  analyzer: ^6.0.0

dev_dependencies:
  build_runner: ^2.4.0
  test: ^1.24.0
  dddart_json: ^0.9.0        # For test models with @Serializable
  dddart_rest: ^0.9.0        # For integration test server
```

### Build Configuration

```yaml
# build.yaml
builders:
  rest_repository:
    import: "package:dddart_repository_rest/src/generators/rest_repository_generator.dart"
    builder_factories: ["restRepositoryBuilder"]
    build_extensions: {".dart": [".rest_repository.g.dart"]}
    auto_apply: dependents
    build_to: source
    applies_builders: ["source_gen|combining_builder"]
```

### Code Generation Flow

1. **Annotation Discovery**
   - `build_runner` scans for `@GenerateRestRepository` annotations
   - Passes annotated elements to `RestRepositoryGenerator`

2. **Validation**
   - Verify element is a `ClassElement`
   - Verify class extends `AggregateRoot`
   - Verify class has `@Serializable()` annotation
   - Extract annotation parameters

3. **Interface Analysis**
   - If `implements` parameter provided, analyze interface methods
   - Determine if custom methods exist beyond base `Repository<T>`
   - Decide between concrete class or abstract base class

4. **Code Generation**
   - Generate class declaration with appropriate type
   - Generate constructor accepting `RestConnection`
   - Generate fields: `_connection`, `_serializer`, `_resourcePath`
   - Generate `getById()`, `save()`, `deleteById()` methods
   - Generate `_mapHttpException()` helper method
   - If abstract base, generate abstract method declarations

5. **Output**
   - Write generated code to `.rest_repository.g.dart` file
   - Include proper imports and part directive

### Resource Path Generation

The resource path is generated from the class name using this algorithm:

```dart
String generateResourcePath(String className) {
  // Convert PascalCase to kebab-case
  final kebab = className
      .replaceAllMapped(
        RegExp('([A-Z])'),
        (match) => '-${match.group(0)!.toLowerCase()}',
      )
      .substring(1); // Remove leading dash
  
  // Simple pluralization (can be enhanced)
  if (kebab.endsWith('y')) {
    return '${kebab.substring(0, kebab.length - 1)}ies';
  } else if (kebab.endsWith('s') || kebab.endsWith('x') || kebab.endsWith('ch')) {
    return '${kebab}es';
  } else {
    return '${kebab}s';
  }
}

// Examples:
// User -> users
// OrderItem -> order-items
// Company -> companies
// Address -> addresses
```

### HTTP Request Construction

All HTTP requests follow this pattern:

```dart
// GET by ID
final url = '${_connection.baseUrl}/$_resourcePath/${id.value}';
final response = await _connection.client.get(url);

// PUT (save)
final url = '${_connection.baseUrl}/$_resourcePath/${aggregate.id.value}';
final response = await _connection.client.put(
  url,
  body: jsonEncode(_serializer.toJson(aggregate)),
  headers: {'Content-Type': 'application/json'},
);

// DELETE
final url = '${_connection.baseUrl}/$_resourcePath/${id.value}';
final response = await _connection.client.delete(url);
```

### Authentication Integration

When a `RestConnection` is created with an `AuthProvider`, the underlying `RestClient` automatically:

1. Obtains access token from the provider before each request
2. Includes `Authorization: Bearer <token>` header
3. Refreshes expired tokens automatically
4. Retries failed requests after token refresh

This is handled transparently by `dddart_rest_client`, so generated repository code doesn't need authentication logic.

### Serialization Integration

The generator assumes that `dddart_json` has already generated a serializer class:

```dart
// User aggregate
@Serializable()
@GenerateRestRepository()
class User extends AggregateRoot { ... }

// Generated by dddart_json (user.g.dart)
class UserJsonSerializer implements JsonSerializer<User> {
  Map<String, dynamic> toJson(User instance) { ... }
  User fromJson(Map<String, dynamic> json) { ... }
}

// Generated by dddart_repository_rest (user.rest_repository.g.dart)
class UserRestRepository implements Repository<User> {
  final _serializer = UserJsonSerializer(); // Uses generated serializer
  ...
}
```

### Custom Repository Extension

When users need custom query methods:

1. **Define Interface:**
```dart
abstract interface class UserRepository implements Repository<User> {
  Future<User?> findByEmail(String email);
  Future<List<User>> findByLastName(String lastName);
}
```

2. **Annotate Aggregate:**
```dart
@Serializable()
@GenerateRestRepository(implements: UserRepository)
class User extends AggregateRoot { ... }
```

3. **Generator Creates Abstract Base:**
```dart
abstract class UserRestRepositoryBase implements UserRepository {
  // Concrete CRUD methods
  // Abstract custom methods
}
```

4. **User Implements Custom Methods:**
```dart
class UserRestRepository extends UserRestRepositoryBase {
  UserRestRepository(super.connection);
  
  @override
  Future<User?> findByEmail(String email) async {
    // Use _connection.client to make custom HTTP request
    // Use _serializer to deserialize response
    // Use _mapHttpException for error handling
  }
  
  @override
  Future<List<User>> findByLastName(String lastName) async {
    // Similar implementation
  }
}
```

### Performance Considerations

1. **Connection Reuse**
   - Create one `RestConnection` per application
   - Share across all repositories
   - Reuses HTTP client connection pool

2. **Serialization**
   - Serializers are instantiated once per repository
   - No reflection overhead (code generation)

3. **HTTP Efficiency**
   - Uses `http` package with connection pooling
   - Supports HTTP/2 when available
   - Automatic gzip compression

4. **Authentication**
   - Tokens cached by `AuthProvider`
   - Automatic refresh minimizes auth overhead
   - No redundant token requests

### Security Considerations

1. **HTTPS Required**
   - Always use HTTPS in production
   - Validate SSL certificates
   - Never send tokens over HTTP

2. **Token Storage**
   - `AuthProvider` handles secure token storage
   - Tokens never logged or exposed in errors

3. **Error Messages**
   - Don't expose sensitive data in error messages
   - Use generic messages for auth failures
   - Log detailed errors server-side only

4. **Input Validation**
   - Validate aggregate data before serialization
   - Sanitize custom query parameters
   - Prevent injection attacks in custom methods

