# HTTP CRUD API Design Document

## Overview

The HTTP CRUD API feature provides a declarative, type-safe way to expose aggregate roots through RESTful HTTP endpoints. Built on the shelf framework, it bridges the domain layer (aggregate roots and repositories) with the HTTP transport layer, handling serialization, routing, error mapping, and standard CRUD operations with minimal boilerplate.

The design follows these principles:
- **Separation of concerns**: HTTP logic is separate from domain logic
- **Type safety**: Leverages Dart's type system to ensure compile-time correctness
- **Flexibility**: Supports custom query handlers and extensibility points
- **Convention over configuration**: Sensible defaults with explicit override options
- **Integration**: Works seamlessly with existing dddart components (repositories, serializers, aggregate roots)

## Architecture

### Package Structure

A new package `dddart_http` will be created with the following structure:

```
packages/dddart_http/
├── lib/
│   ├── dddart_http.dart                 # Main export file
│   └── src/
│       ├── crud_resource.dart           # Resource class with configuration and request handlers
│       ├── query_handler.dart           # Query handler types and QueryResult
│       ├── http_server.dart             # Server setup and lifecycle
│       ├── error_mapper.dart            # Maps domain exceptions to HTTP responses
│       └── response_builder.dart        # Builds HTTP responses with proper status codes
├── example/
│   └── main.dart                        # Complete working example
└── pubspec.yaml
```

### Dependencies

- `shelf: ^1.4.0` - HTTP server framework
- `shelf_router: ^1.1.0` - Routing support for shelf
- `dddart` - Core DDD abstractions
- `dddart_serialization` - Serialization interfaces

### High-Level Flow

```
HTTP Request
    ↓
shelf Server
    ↓
Router (matches path + method)
    ↓
CrudResource (determines operation type)
    ↓
├─ handleGetById() → Repository.getById()
├─ handleQuery() → Custom Query Handler or getAll()
├─ handleCreate() → Deserialize + Repository.save()
├─ handleUpdate() → Deserialize + Repository.save()
└─ handleDelete() → Repository.deleteById()
    ↓
ErrorMapper (catches exceptions)
    ↓
ResponseBuilder (serializes result)
    ↓
HTTP Response
```

## Components and Interfaces

### 1. CrudResource<T>

The main class that handles HTTP CRUD operations for an aggregate root. It combines configuration (repository, serializer, query handlers) with request handling logic (handleGetById, handleCreate, etc.).

Each `CrudResource` instance is configured for a specific aggregate type and registered with the HTTP server. Multiple resources can be registered to expose different aggregates through the same server.

```dart
class CrudResource<T extends AggregateRoot> {
  CrudResource({
    required this.path,
    required this.repository,
    required this.serializers,
    this.queryHandlers = const {},
    this.customExceptionHandlers = const {},
    this.defaultSkip = 0,
    this.defaultTake = 50,
    this.maxTake = 100,
  });

  // Configuration fields
  
  /// The base path for this resource (e.g., '/users')
  final String path;
  
  /// Repository instance for persistence operations
  /// All repositories implement Repository<T> interface with getById, save, deleteById methods
  final Repository<T> repository;
  
  /// Map of content types to serializers for content negotiation
  /// Key: MIME type (e.g., 'application/json', 'application/yaml')
  /// Value: Serializer instance for that content type
  /// The first entry is used as the default for responses when Accept header is */* or missing
  /// At least one serializer must be provided
  final Map<String, Serializer<T>> serializers;
  
  /// Map of query parameter names to handler functions
  /// Key: the query parameter name (e.g., 'firstName')
  /// Value: the handler function to invoke when that parameter is present
  /// Note: The same handler can be registered multiple times for backward compatibility
  final Map<String, QueryHandler<T>> queryHandlers;
  
  /// Map of custom exception types to error response handlers
  /// These handlers supplement the built-in error handling for framework exceptions
  /// Key: the exception type (e.g., MyCustomException)
  /// Value: function that converts the exception to an HTTP Response
  /// Note: Built-in handlers for RepositoryException, DeserializationException, etc. are always active
  final Map<Type, Response Function(Object)> customExceptionHandlers;
  
  /// Default skip value for pagination (defaults to 0)
  final int defaultSkip;
  
  /// Default take value for pagination (defaults to 50)
  final int defaultTake;
  
  /// Maximum allowed take value to prevent excessive queries (defaults to 100)
  final int maxTake;
  
  // HTTP Request Handler Methods
  
  /// Handles GET /resource/:id
  /// Parses the ID, calls repository.getById(), and returns serialized aggregate
  /// Uses Accept header for content negotiation
  Future<Response> handleGetById(Request request, String id) async {
    try {
      final uuid = UuidValue.fromString(id);
      final aggregate = await repository.getById(uuid);
      final serializer = _selectSerializer(request.headers['accept']);
      return _responseBuilder.ok(aggregate, serializer);
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }
  
  /// Handles GET /resource with optional query parameters and pagination
  /// - No query params: returns all items (paginated)
  /// - One query param: looks up and invokes corresponding query handler
  /// - Multiple query params: returns 400 error
  Future<Response> handleQuery(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final pagination = _parsePagination(queryParams);
      
      // Remove pagination params for handler matching
      final filterParams = Map<String, String>.from(queryParams)
        ..remove('skip')
        ..remove('take');
      
      QueryResult<T> result;
      
      if (filterParams.isEmpty) {
        // No filters - return all items
        result = await _getAllItems(pagination.skip, pagination.take);
      } else if (filterParams.length > 1) {
        // Multiple filters not allowed
        return _responseBuilder.badRequest(
          'Cannot combine multiple query parameters. Use only one filter at a time.'
        );
      } else {
        // Single filter - look up handler
        final paramName = filterParams.keys.first;
        final handler = queryHandlers[paramName];
        
        if (handler == null) {
          return _responseBuilder.badRequest('Unsupported query parameter: $paramName');
        }
        
        result = await handler(repository, filterParams, pagination.skip, pagination.take);
      }
      
      return _responseBuilder.okList(result.items, totalCount: result.totalCount);
    } catch (e, stackTrace) {
      return ErrorMapper.mapException(e, stackTrace);
    }
  }
  
  /// Handles POST /resource
  /// Deserializes request body using Content-Type header, calls repository.save(), returns created aggregate
  /// Uses Accept header for response content negotiation
  Future<Response> handleCreate(Request request) async {
    try {
      final contentType = request.headers['content-type'] ?? serializers.keys.first;
      final requestSerializer = serializers[contentType];
      
      if (requestSerializer == null) {
        return Response(
          415,
          headers: {'Content-Type': 'application/problem+json'},
          body: jsonEncode({
            'type': 'about:blank',
            'title': 'Unsupported Media Type',
            'status': 415,
            'detail': 'Content-Type $contentType is not supported. Supported types: ${serializers.keys.join(", ")}',
          }),
        );
      }
      
      final body = await request.readAsString();
      final aggregate = requestSerializer.deserialize(body);
      await repository.save(aggregate);
      
      final responseSerializer = _selectSerializer(request.headers['accept']);
      return _responseBuilder.created(aggregate, responseSerializer);
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }
  
  /// Handles PUT /resource/:id
  /// Deserializes request body using Content-Type header, calls repository.save(), returns updated aggregate
  /// Uses Accept header for response content negotiation
  Future<Response> handleUpdate(Request request, String id) async {
    try {
      final contentType = request.headers['content-type'] ?? serializers.keys.first;
      final requestSerializer = serializers[contentType];
      
      if (requestSerializer == null) {
        return Response(
          415,
          headers: {'Content-Type': 'application/problem+json'},
          body: jsonEncode({
            'type': 'about:blank',
            'title': 'Unsupported Media Type',
            'status': 415,
            'detail': 'Content-Type $contentType is not supported. Supported types: ${serializers.keys.join(", ")}',
          }),
        );
      }
      
      final body = await request.readAsString();
      final aggregate = requestSerializer.deserialize(body);
      await repository.save(aggregate);
      
      final responseSerializer = _selectSerializer(request.headers['accept']);
      return _responseBuilder.ok(aggregate, responseSerializer);
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }
  
  /// Handles DELETE /resource/:id
  /// Parses ID, calls repository.deleteById(), returns 204 No Content
  Future<Response> handleDelete(Request request, String id) async {
    try {
      final uuid = UuidValue.fromString(id);
      await repository.deleteById(uuid);
      return _responseBuilder.noContent();
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }
  
  // Private helper methods
  
  /// Selects appropriate serializer based on Accept header
  /// Returns first serializer (default) if Accept is */*, missing, or no match found
  /// Returns 406 Not Acceptable if Accept header specifies unsupported type
  Serializer<T> _selectSerializer(String? acceptHeader) {
    if (acceptHeader == null || acceptHeader == '*/*' || acceptHeader.isEmpty) {
      return serializers.values.first;  // Default to first serializer
    }
    
    // Parse Accept header (simplified - doesn't handle quality values)
    final acceptedTypes = acceptHeader.split(',').map((t) => t.trim().split(';').first).toList();
    
    for (final acceptedType in acceptedTypes) {
      if (acceptedType == '*/*') {
        return serializers.values.first;
      }
      if (serializers.containsKey(acceptedType)) {
        return serializers[acceptedType]!;
      }
    }
    
    // No match found - throw exception that will be caught and converted to 406
    throw UnsupportedMediaTypeException(
      'Accept header specifies unsupported media type(s): $acceptHeader. '
      'Supported types: ${serializers.keys.join(", ")}'
    );
  }
  
  Response _handleException(Object error, StackTrace stackTrace) {
    // Check custom handlers first
    final customHandler = customExceptionHandlers[error.runtimeType];
    if (customHandler != null) {
      return customHandler(error);
    }
    
    // Fall back to built-in ErrorMapper
    return ErrorMapper.mapException(error, stackTrace);
  }
  
  PaginationParams _parsePagination(Map<String, String> queryParams) {
    final skip = int.tryParse(queryParams['skip'] ?? '') ?? defaultSkip;
    var take = int.tryParse(queryParams['take'] ?? '') ?? defaultTake;
    if (take > maxTake) take = maxTake;
    return PaginationParams(skip, take);
  }
  
  Future<QueryResult<T>> _getAllItems(int skip, int take) async {
    final allItems = await repository.getAll();
    final paginatedItems = allItems.skip(skip).take(take).toList();
    return QueryResult(paginatedItems, totalCount: allItems.length);
  }
  
  late final ResponseBuilder<T> _responseBuilder = ResponseBuilder();
}

/// Exception thrown when client requests unsupported media type
class UnsupportedMediaTypeException implements Exception {
  UnsupportedMediaTypeException(this.message);
  final String message;
  
  @override
  String toString() => message;
}

class PaginationParams {
  PaginationParams(this.skip, this.take);
  final int skip;
  final int take;
}
```

### 2. QueryHandler<T>

Represents a custom query handler that processes query parameters and returns results.

```dart
/// Result from a query handler including items and optional total count
class QueryResult<T extends AggregateRoot> {
  QueryResult(this.items, {this.totalCount});
  
  final List<T> items;
  final int? totalCount;
}

/// Function signature for query handlers
/// 
/// Parameters:
/// - repository: The repository instance to query
/// - queryParams: All query parameters from the request (excluding skip/take)
/// - skip: Number of items to skip (for pagination)
/// - take: Number of items to return (for pagination)
/// 
/// Returns: QueryResult containing the filtered items and optional total count
typedef QueryHandler<T extends AggregateRoot> = Future<QueryResult<T>> Function(
  Repository<T> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
);
```

### 3. HttpServer

Manages the shelf server lifecycle and route registration.

```dart
class HttpServer {
  HttpServer({this.port = 8080});
  
  final int port;
  final List<CrudResource> _resources = [];
  
  /// Registers a CRUD resource
  void registerResource<T extends AggregateRoot>(CrudResource<T> resource);
  
  /// Starts the HTTP server
  Future<void> start();
  
  /// Stops the HTTP server
  Future<void> stop();
}
```

### 4. ErrorMapper

Maps domain exceptions to appropriate HTTP responses.

```dart
class ErrorMapper {
  static Response mapException(Object error, StackTrace stackTrace) {
    if (error is RepositoryException) {
      return _mapRepositoryException(error);
    } else if (error is DeserializationException) {
      return _problemResponse(400, 'Bad Request', error.message);
    } else if (error is SerializationException) {
      return _problemResponse(500, 'Internal Server Error', 'Serialization failed');
    } else if (error is UnsupportedMediaTypeException) {
      return _problemResponse(406, 'Not Acceptable', error.message);
    } else {
      return _problemResponse(500, 'Internal Server Error', 'An unexpected error occurred');
    }
  }
  
  static Response _mapRepositoryException(RepositoryException e) {
    switch (e.type) {
      case RepositoryExceptionType.notFound:
        return _problemResponse(404, 'Not Found', e.message);
      case RepositoryExceptionType.duplicate:
        return _problemResponse(409, 'Conflict', e.message);
      case RepositoryExceptionType.constraint:
        return _problemResponse(422, 'Unprocessable Entity', e.message);
      default:
        return _problemResponse(500, 'Internal Server Error', 'Repository operation failed');
    }
  }
  
  static Response _problemResponse(int status, String title, String detail) {
    return Response(
      status,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': title,
        'status': status,
        'detail': detail,
      }),
    );
  }
}
```

### 5. ResponseBuilder

Constructs HTTP responses with proper status codes and serialization.

```dart
class ResponseBuilder<T extends AggregateRoot> {
  /// Builds a 200 OK response with serialized body
  /// Uses provided serializer and sets appropriate Content-Type header
  Response ok(T aggregate, Serializer<T> serializer, String contentType) {
    return Response.ok(
      serializer.serialize(aggregate),
      headers: {'Content-Type': contentType},
    );
  }
  
  /// Builds a 201 Created response with serialized body
  /// Uses provided serializer and sets appropriate Content-Type header
  Response created(T aggregate, Serializer<T> serializer, String contentType) {
    return Response(
      201,
      body: serializer.serialize(aggregate),
      headers: {'Content-Type': contentType},
    );
  }
  
  /// Builds a 200 OK response with list of serialized aggregates
  /// Includes X-Total-Count header if totalCount is provided
  /// Uses provided serializer and sets appropriate Content-Type header
  Response okList(List<T> aggregates, Serializer<T> serializer, String contentType, {int? totalCount}) {
    final headers = {'Content-Type': contentType};
    if (totalCount != null) {
      headers['X-Total-Count'] = totalCount.toString();
    }
    
    // Serialize list of aggregates
    final serializedList = aggregates.map((a) => serializer.serialize(a)).toList();
    return Response.ok(
      jsonEncode(serializedList),  // Wrap in JSON array
      headers: headers,
    );
  }
  
  /// Builds a 204 No Content response
  Response noContent() {
    return Response(204);
  }
  
  /// Builds a 400 Bad Request response using RFC 7807 format
  Response badRequest(String message) {
    return Response(
      400,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Bad Request',
        'status': 400,
        'detail': message,
      }),
    );
  }
  
  /// Builds a 404 Not Found response using RFC 7807 format
  Response notFound(String message) {
    return Response(
      404,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Not Found',
        'status': 404,
        'detail': message,
      }),
    );
  }
}
```

## Data Models

### Route Registration

Routes are automatically generated based on the resource path:

| HTTP Method | Route Pattern | Handler | Description | Return Type |
|-------------|---------------|---------|-------------|-------------|
| GET | `/resource/:id` | handleGetById | Retrieve single resource by ID | Single object |
| GET | `/resource` | handleQuery | Retrieve all resources (paginated) or query with filters | Array |
| POST | `/resource` | handleCreate | Create new resource | Single object |
| PUT | `/resource/:id` | handleUpdate | Update existing resource | Single object |
| DELETE | `/resource/:id` | handleDelete | Delete resource by ID | No content |

### REST Convention: Collection vs Item Endpoints

The HTTP_API_System follows standard REST conventions for determining response types:

- **Collection endpoints** (`/resource`) ALWAYS return a JSON array, even if:
  - Zero items match: returns `[]`
  - One item matches: returns `[{...}]`
  - Multiple items match: returns `[{...}, {...}, ...]`

- **Item endpoints** (`/resource/:id`) ALWAYS return a single JSON object or error:
  - Item exists: returns `{...}`
  - Item doesn't exist: returns 404 error

This convention applies to all collection operations:
- `GET /users` → array
- `GET /users?firstName=Bob` → array (even if only one Bob exists)
- `GET /users?email=unique@example.com` → array (even if email is unique)
- `GET /users/123e4567-...` → single object (or 404)

The path structure determines the return type, making client code predictable and consistent.

### Pagination Parameters

All collection endpoints (GET `/resource`) support pagination via query parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `skip` | int | 0 (configurable) | Number of items to skip |
| `take` | int | 50 (configurable) | Number of items to return (max 100) |

Example: `GET /users?skip=20&take=10` returns users 21-30

### Request/Response Format

All requests and responses use JSON format (when using JsonSerializer):

**GET /users/123e4567-e89b-12d3-a456-426614174000**
```json
Response: 200 OK
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "John Doe",
  "email": "john@example.com",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

**POST /users**
```json
Request Body:
{
  "name": "Jane Smith",
  "email": "jane@example.com"
}

Response: 201 Created
{
  "id": "987fcdeb-51a2-43f7-b123-456789abcdef",
  "name": "Jane Smith",
  "email": "jane@example.com",
  "createdAt": "2024-01-15T11:00:00Z",
  "updatedAt": "2024-01-15T11:00:00Z"
}
```

**GET /users** (all users, paginated)
```json
Response: 200 OK
Headers:
  X-Total-Count: 150
  
[
  {
    "id": "111e4567-e89b-12d3-a456-426614174111",
    "firstName": "Bob",
    "lastName": "Johnson",
    "email": "bob@example.com",
    "createdAt": "2024-01-15T09:00:00Z",
    "updatedAt": "2024-01-15T09:00:00Z"
  },
  // ... more users (up to 'take' limit)
]
```

**GET /users?firstName=Bob&skip=0&take=10** (filtered and paginated)
```json
Response: 200 OK
Headers:
  X-Total-Count: 3
  
[
  {
    "id": "111e4567-e89b-12d3-a456-426614174111",
    "firstName": "Bob",
    "lastName": "Johnson",
    "email": "bob@example.com",
    "createdAt": "2024-01-15T09:00:00Z",
    "updatedAt": "2024-01-15T09:00:00Z"
  }
]
```

**DELETE /users/123e4567-e89b-12d3-a456-426614174000**
```
Response: 204 No Content
(empty body)
```

### Error Response Format

All error responses use RFC 7807 Problem Details format with `Content-Type: application/problem+json`:

```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "User with ID 123e4567-e89b-12d3-a456-426614174000 not found"
}
```

Required fields:
- `type`: URI reference identifying the problem type (use "about:blank" for generic errors)
- `title`: Short, human-readable summary of the problem type
- `status`: HTTP status code
- `detail`: Human-readable explanation specific to this occurrence

## Error Handling

### Built-in Exception Mapping

The system provides built-in error handling for common framework exceptions:

| Exception Type | HTTP Status | Title | Description |
|----------------|-------------|-------|-------------|
| RepositoryException (notFound) | 404 Not Found | Not Found | Resource doesn't exist |
| RepositoryException (duplicate) | 409 Conflict | Conflict | Unique constraint violation |
| RepositoryException (constraint) | 422 Unprocessable Entity | Unprocessable Entity | Database constraint violation |
| DeserializationException | 400 Bad Request | Bad Request | Invalid request body |
| SerializationException | 500 Internal Server Error | Internal Server Error | Failed to serialize response |
| UnsupportedMediaTypeException | 406 Not Acceptable | Not Acceptable | Requested media type not supported |
| Other exceptions | 500 Internal Server Error | Internal Server Error | Unexpected error |

All error responses use RFC 7807 Problem Details format.

### Custom Exception Handling

Developers can register custom exception handlers to supplement the built-in error handling:

```dart
CrudResource<User>(
  path: '/users',
  repository: repository,
  serializer: serializer,
  customExceptionHandlers: {
    MyCustomException: (e) => Response(
      418,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Custom Error',
        'status': 418,
        'detail': (e as MyCustomException).message,
      }),
    ),
    ValidationException: (e) => Response(
      422,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Validation Failed',
        'status': 422,
        'detail': e.toString(),
      }),
    ),
  },
)
```

### Error Handling Flow

1. All handler methods wrap operations in try-catch blocks
2. Caught exceptions are first checked against `customExceptionHandlers` map
3. If a custom handler is found, it's invoked and returns the Response
4. If no custom handler is found, exception is passed to `ErrorMapper.mapException()`
5. ErrorMapper checks for built-in framework exceptions and maps them appropriately
6. If no built-in mapping exists, returns generic 500 Internal Server Error
7. All error responses use RFC 7807 Problem Details format
8. Stack traces are logged but not exposed to clients

```dart
Response _handleException(Object error, StackTrace stackTrace) {
  // 1. Check custom handlers first
  final customHandler = customExceptionHandlers[error.runtimeType];
  if (customHandler != null) {
    return customHandler(error);
  }
  
  // 2. Fall back to built-in ErrorMapper
  return ErrorMapper.mapException(error, stackTrace);
}
```

## Testing Strategy

### Unit Tests

1. **CrudResource Tests**
   - Test each CRUD operation independently (handleGetById, handleCreate, etc.)
   - Mock repository and serializer
   - Verify correct repository methods are called
   - Verify response status codes and bodies
   - Test query parameter matching logic
   - Test handler invocation with correct parameters
   - Test error cases (no handler matches, multiple params, etc.)

2. **ErrorMapper Tests**
   - Test each exception type maps to correct status code
   - Test error message formatting
   - Test unknown exception handling

3. **ResponseBuilder Tests**
   - Test serialization of single aggregates
   - Test serialization of aggregate lists
   - Test empty responses (204)
   - Test X-Total-Count header inclusion

### Integration Tests

1. **End-to-End CRUD Tests**
   - Start test server with InMemoryRepository
   - Perform full CRUD lifecycle via HTTP
   - Verify data persistence across requests

2. **Query Handler Tests**
   - Register custom query handlers
   - Make requests with various query parameters
   - Verify correct handlers are invoked

3. **Error Scenario Tests**
   - Test 404 responses for missing resources
   - Test 400 responses for invalid JSON
   - Test 500 responses for unexpected errors

### Example Application Tests

The example application serves as both documentation and an integration test:
- Defines a complete aggregate root with child entities
- Configures all CRUD routes
- Demonstrates custom query handlers
- Can be run manually for exploratory testing

## Usage Example

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_http/dddart_http.dart';
import 'package:dddart_json/dddart_json.dart';

// Define aggregate root
class User extends AggregateRoot {
  User({
    required this.firstName,
    required this.lastName,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  
  final String firstName;
  final String lastName;
  final String email;
}

// Define serializer (would typically be generated)
class UserSerializer implements JsonSerializer<User> {
  @override
  Map<String, dynamic> toJson(User user, [SerializationConfig? config]) {
    return {
      'id': user.id.toString(),
      'firstName': user.firstName,
      'lastName': user.lastName,
      'email': user.email,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    };
  }
  
  @override
  User fromJson(dynamic json, [SerializationConfig? config]) {
    return User(
      id: UuidValue.fromString(json['id']),
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
  
  // serialize/deserialize methods inherited from JsonSerializer
}

void main() async {
  // Set up repository and serializers
  final repository = InMemoryRepository<User>();
  final jsonSerializer = UserJsonSerializer();
  final yamlSerializer = UserYamlSerializer();  // hypothetical YAML serializer
  
  // Create HTTP server
  final server = HttpServer(port: 8080);
  
  // Define query handlers
  final firstNameHandler = (Repository<User> repo, Map<String, String> params, int skip, int take) async {
    final firstName = params['firstName']!;
    final allMatches = await (repo as UserRepository).getByFirstName(firstName);
    return QueryResult(
      allMatches.skip(skip).take(take).toList(),
      totalCount: allMatches.length,
    );
  };
  
  // Register CRUD resource with multiple serializers and custom handlers
  server.registerResource(
    CrudResource<User>(
      path: '/users',
      repository: repository,
      serializers: {
        'application/json': jsonSerializer,  // First entry is default
        'application/yaml': yamlSerializer,
      },
      defaultSkip: 0,
      defaultTake: 20,
      maxTake: 100,
      queryHandlers: {
        'firstName': firstNameHandler,
        'email': (repo, params, skip, take) async {
          final email = params['email']!;
          final user = await (repo as UserRepository).getByEmail(email);
          return QueryResult(user != null ? [user] : [], totalCount: user != null ? 1 : 0);
        },
      },
      customExceptionHandlers: {
        UserNotFoundException: (e) => Response(
          404,
          headers: {'Content-Type': 'application/problem+json'},
          body: jsonEncode({
            'type': 'about:blank',
            'title': 'User Not Found',
            'status': 404,
            'detail': (e as UserNotFoundException).message,
          }),
        ),
      },
    ),
  );
  
  // Start server
  await server.start();
  print('Server running on http://localhost:8080');
  
  // Server now handles:
  // GET /users/:id - single user
  // GET /users - all users (paginated)
  // GET /users?skip=10&take=5 - users 11-15
  // GET /users?firstName=Bob - filtered by firstName (paginated)
  // GET /users?firstName=Bob&skip=0&take=10 - filtered and paginated
  // GET /users?email=john@example.com - filtered by email
  // GET /users?firstName=Bob&lastName=Smith - 400 error (can't combine)
  // POST /users - create user
  // PUT /users/:id - update user
  // DELETE /users/:id - delete user
}
```

## Implementation Notes

### Routing with shelf_router

The HttpServer registers routes for each CrudResource by calling its handler methods:

```dart
final router = Router();

// Register routes for each resource
for (final resource in _resources) {
  router.get('${resource.path}/<id>', (Request request, String id) {
    return resource.handleGetById(request, id);
  });

  router.get(resource.path, (Request request) {
    return resource.handleQuery(request);
  });

  router.post(resource.path, (Request request) {
    return resource.handleCreate(request);
  });

  router.put('${resource.path}/<id>', (Request request, String id) {
    return resource.handleUpdate(request, id);
  });

  router.delete('${resource.path}/<id>', (Request request, String id) {
    return resource.handleDelete(request);
  });
}
```

### How CrudResource Works with Multiple Aggregates

The `CrudResource` class is generic (`CrudResource<T extends AggregateRoot>`), which means:

1. **One class definition** handles all aggregate types
2. **Multiple instances** are created, one per aggregate type
3. **Each instance** is configured with its specific repository, serializer, and query handlers

Example with multiple aggregates:

```dart
// Create resources for different aggregates
final userResource = CrudResource<User>(
  path: '/users',
  repository: userRepository,  // implements Repository<User>
  serializer: userSerializer,
  queryHandlers: {'firstName': userFirstNameHandler},
);

final productResource = CrudResource<Product>(
  path: '/products',
  repository: productRepository,  // implements Repository<Product>
  serializer: productSerializer,
  queryHandlers: {'category': productCategoryHandler},
);

final orderResource = CrudResource<Order>(
  path: '/orders',
  repository: orderRepository,  // implements Repository<Order>
  serializer: orderSerializer,
  queryHandlers: {'status': orderStatusHandler},
);

// Register all resources with the server
server.registerResource(userResource);
server.registerResource(productResource);
server.registerResource(orderResource);
```

All three resources share the same `handleGetById`, `handleQuery`, `handleCreate`, etc. methods because they're defined in the `CrudResource` class. The generic type parameter `<T>` ensures type safety - each resource works with its specific aggregate type.

The `Repository<T>` interface is key here - all repositories implement the same interface (`getById`, `save`, `deleteById`), so `CrudResource` can call these methods on any repository regardless of the aggregate type.

### Query Handler Matching Rules

The system enforces strict matching rules for query parameters:

1. **No filter params** (`GET /users` or `GET /users?skip=10&take=5`)
   - Returns all items (paginated)
   - ✓ Valid

2. **Exactly one filter param** (`GET /users?firstName=Bob`)
   - Looks up handler by parameter name
   - If handler exists: invokes it
   - If handler doesn't exist: returns 400 "Unsupported query parameter"
   - ✓ Valid if handler registered

3. **Multiple filter params** (`GET /users?firstName=Bob&lastName=Smith`)
   - Returns 400 "Cannot combine multiple query parameters"
   - ✗ Invalid (even if both handlers exist)

4. **Pagination params are always allowed** (`GET /users?firstName=Bob&skip=0&take=10`)
   - `skip` and `take` don't count as filter params
   - ✓ Valid

### Handler Reuse for Backward Compatibility

The same handler function can be registered under multiple parameter names:

```dart
final firstNameHandler = (repo, params, skip, take) async {
  final name = params['firstName'] ?? params['firsstName']!;
  final results = await repo.getByFirstName(name);
  return QueryResult(
    results.skip(skip).take(take).toList(),
    totalCount: results.length,
  );
};

queryHandlers: {
  'firstName': firstNameHandler,
  'firsstName': firstNameHandler,  // backward compatibility for typo
}
```

This allows supporting deprecated parameter names while transitioning to new ones.

### Content Negotiation

The system supports HTTP content negotiation using standard headers:

**Request Content-Type (POST/PUT):**
- Client specifies `Content-Type` header to indicate request body format
- System looks up corresponding serializer from `serializers` map
- If Content-Type is missing, uses first serializer (default)
- If Content-Type is not supported, returns 415 Unsupported Media Type

**Response Accept Header (GET):**
- Client specifies `Accept` header to indicate desired response format
- System looks up corresponding serializer from `serializers` map
- If Accept is `*/*` or missing, uses first serializer (default)
- If Accept specifies unsupported type, returns 406 Not Acceptable

**Example:**
```
POST /users
Content-Type: application/json
Accept: application/yaml

{"name": "John", "email": "john@example.com"}

Response: 201 Created
Content-Type: application/yaml

name: John
email: john@example.com
id: 123e4567-...
```

### ID Parsing

IDs are always parsed as UUIDs using `UuidValue.fromString()`. This is consistent with the Repository interface and AggregateRoot base class, which both require UuidValue for IDs.

## Future Enhancements

Potential features for future iterations:

1. **Pagination**: Support for limit/offset or cursor-based pagination
2. **Filtering**: Generic query parameter filtering without custom handlers
3. **Sorting**: Support for ?sort=field:asc query parameters
4. **PATCH Support**: Partial updates using JSON Patch or JSON Merge Patch
5. **HATEOAS**: Hypermedia links in responses
6. **Authentication/Authorization**: Middleware hooks for auth
7. **Rate Limiting**: Built-in rate limiting middleware
8. **OpenAPI Generation**: Auto-generate OpenAPI specs from registered resources
9. **Validation**: Request validation before deserialization
10. **Caching**: HTTP caching headers (ETag, Cache-Control)
