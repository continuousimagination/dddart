# dddart_rest

RESTful CRUD API framework for DDDart - Provides REST endpoints for aggregate roots with minimal boilerplate.

> **Note:** This package was previously named `dddart_http`. See the [Migration Guide](#migration-from-dddart_http) below.

## Features

- **Automatic CRUD endpoints** - Expose aggregate roots through REST APIs with a single configuration
- **ETag concurrency control** - Optimistic locking with If-Match headers to prevent lost updates
- **JWT Authentication** - Built-in support for self-hosted and OAuth/OIDC authentication
- **Device Flow** - OAuth2 device flow for CLI tools and limited-input devices
- **Content negotiation** - Support multiple serialization formats (JSON, YAML, etc.) via HTTP headers
- **Custom query handlers** - Define filterable endpoints with custom query parameters
- **Pagination support** - Built-in pagination with configurable defaults and limits
- **Custom exception handling** - Map domain exceptions to appropriate HTTP responses
- **RFC 7807 error format** - Standardized error responses using Problem Details format
- **Type-safe** - Leverages Dart's type system for compile-time correctness
- **Repository integration** - Works seamlessly with DDDart's repository pattern

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dddart_rest: ^0.9.0
  dddart: ^0.9.0
  dddart_serialization: ^0.9.0
```

## Quick Start

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';

void main() async {
  // Create repository and serializer
  final repository = InMemoryRepository<User>();
  final serializer = UserSerializer();

  // Create and configure HTTP server
  final server = HttpServer(port: 8080);
  
  server.registerResource(
    CrudResource<User>(
      path: '/users',
      repository: repository,
      serializers: {'application/json': serializer},
    ),
  );

  await server.start();
  print('Server running on http://localhost:8080');
}
```

This creates the following endpoints:
- `GET /users` - List all users
- `GET /users/:id` - Get user by ID
- `POST /users` - Create new user
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user

### Adding Custom Routes

You can add custom routes (like health checks, metrics, or webhooks) to the same server:

```dart
import 'package:dddart_rest/dddart_rest.dart';

final server = HttpServer(port: 8080);

// Register CRUD resources (creates 5 routes automatically)
server.registerResource(userResource);

// Add custom routes
server.addRoute('GET', '/health', healthCheckHandler);
server.addRoute('GET', '/metrics', metricsHandler);

// You can also add webhook handlers from dddart_webhooks package
// server.addRoute('POST', webhook.path, webhook.handleRequest);

await server.start();
```

This allows you to run REST CRUD endpoints and custom handlers on a single server instance. See `example/custom_routes_example.dart` for a complete example.

## Usage Guide

### Basic CRUD Operations

#### GET - Retrieve by ID

```bash
curl http://localhost:8080/users/123e4567-e89b-12d3-a456-426614174000
```

Response (200 OK):
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

#### GET - List all (collection)

```bash
curl http://localhost:8080/users
```

Response (200 OK):
```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com"
  },
  {
    "id": "987fcdeb-51a2-43f7-b123-456789abcdef",
    "firstName": "Jane",
    "lastName": "Smith",
    "email": "jane@example.com"
  }
]
```

Headers:
```
X-Total-Count: 150
```

#### POST - Create

```bash
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Alice",
    "lastName": "Williams",
    "email": "alice@example.com"
  }'
```

Response (201 Created):
```json
{
  "id": "abc12345-6789-0def-1234-567890abcdef",
  "firstName": "Alice",
  "lastName": "Williams",
  "email": "alice@example.com",
  "createdAt": "2024-01-15T11:00:00Z",
  "updatedAt": "2024-01-15T11:00:00Z"
}
```

#### PUT - Update

```bash
curl -X PUT http://localhost:8080/users/123e4567-e89b-12d3-a456-426614174000 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "firstName": "John",
    "lastName": "Doe-Smith",
    "email": "john.doesmith@example.com"
  }'
```

Response (200 OK):
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "firstName": "John",
  "lastName": "Doe-Smith",
  "email": "john.doesmith@example.com",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T12:00:00Z"
}
```

#### DELETE - Remove

```bash
curl -X DELETE http://localhost:8080/users/123e4567-e89b-12d3-a456-426614174000
```

Response (204 No Content) - empty body

### Content Negotiation

Support multiple serialization formats by registering multiple serializers:

```dart
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: repository,
    serializers: {
      'application/json': jsonSerializer,  // First entry is default
      'application/yaml': yamlSerializer,
      'application/xml': xmlSerializer,
    },
  ),
);
```

#### Request Format (POST/PUT)

Clients specify the request body format using the `Content-Type` header:

```bash
# Send JSON
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"firstName": "John", "email": "john@example.com"}'

# Send YAML
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/yaml" \
  -d 'firstName: John
email: john@example.com'
```

If `Content-Type` is missing, the first registered serializer is used as default.

If `Content-Type` specifies an unsupported format, returns **415 Unsupported Media Type**.

#### Response Format (GET)

Clients specify the desired response format using the `Accept` header:

```bash
# Request JSON response
curl http://localhost:8080/users/123 \
  -H "Accept: application/json"

# Request YAML response
curl http://localhost:8080/users/123 \
  -H "Accept: application/yaml"
```

If `Accept` is `*/*` or missing, the first registered serializer is used as default.

If `Accept` specifies an unsupported format, returns **406 Not Acceptable**.

### Pagination

All collection endpoints support pagination via query parameters:

```bash
# Get items 21-30
curl http://localhost:8080/users?skip=20&take=10
```

Response includes `X-Total-Count` header with the total number of items:

```
HTTP/1.1 200 OK
X-Total-Count: 150
Content-Type: application/json

[...]
```

#### Configuration

Configure pagination defaults when registering a resource:

```dart
CrudResource<User>(
  path: '/users',
  repository: repository,
  serializers: {'application/json': serializer},
  defaultSkip: 0,      // Default: 0
  defaultTake: 20,     // Default: 50
  maxTake: 100,        // Default: 100 (prevents excessive queries)
)
```

Pagination applies to:
- Unfiltered collection requests (`GET /users`)
- Filtered requests using custom query handlers (`GET /users?firstName=John`)

### Custom Query Handlers

Define custom query handlers to enable filtering by specific fields:

```dart
// Define a query handler
Future<QueryResult<User>> firstNameHandler(
  Repository<User> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
) async {
  final firstName = queryParams['firstName']!;
  
  // Filter results
  final allUsers = await repository.getAll();
  final matches = allUsers
      .where((u) => u.firstName.toLowerCase() == firstName.toLowerCase())
      .toList();
  
  // Apply pagination
  final paginated = matches.skip(skip).take(take).toList();
  
  return QueryResult(paginated, totalCount: matches.length);
}

// Register the handler
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: repository,
    serializers: {'application/json': serializer},
    queryHandlers: {
      'firstName': firstNameHandler,
      'email': emailHandler,
    },
  ),
);
```

#### Using Query Handlers

```bash
# Filter by first name
curl http://localhost:8080/users?firstName=John

# Filter by email
curl http://localhost:8080/users?email=john@example.com

# Filter with pagination
curl http://localhost:8080/users?firstName=John&skip=0&take=10
```

#### Query Handler Rules

1. **No filter params** - Returns all items (paginated)
   ```bash
   GET /users
   GET /users?skip=10&take=5
   ```

2. **Exactly one filter param** - Invokes the corresponding handler
   ```bash
   GET /users?firstName=John  # ✓ Valid
   ```

3. **Multiple filter params** - Returns 400 error
   ```bash
   GET /users?firstName=John&lastName=Doe  # ✗ Invalid
   ```

4. **Pagination params are always allowed** - `skip` and `take` don't count as filter params
   ```bash
   GET /users?firstName=John&skip=0&take=10  # ✓ Valid
   ```

5. **Unsupported param** - Returns 400 error
   ```bash
   GET /users?age=30  # ✗ Invalid (no handler registered)
   ```

#### Handler Reuse

Register the same handler under multiple parameter names for backward compatibility:

```dart
queryHandlers: {
  'firstName': firstNameHandler,
  'first_name': firstNameHandler,  // Support both naming conventions
}
```

### Custom Exception Handling

Map domain-specific exceptions to appropriate HTTP responses:

```dart
// Define custom exceptions
class InvalidEmailException implements Exception {
  InvalidEmailException(this.email);
  final String email;
}

class DuplicateEmailException implements Exception {
  DuplicateEmailException(this.email);
  final String email;
}

// Define exception handlers
Response handleInvalidEmail(Object error) {
  final e = error as InvalidEmailException;
  return Response(
    400,
    headers: {'Content-Type': 'application/problem+json'},
    body: jsonEncode({
      'type': 'about:blank',
      'title': 'Invalid Email',
      'status': 400,
      'detail': 'The email address ${e.email} is not valid',
    }),
  );
}

Response handleDuplicateEmail(Object error) {
  final e = error as DuplicateEmailException;
  return Response(
    409,
    headers: {'Content-Type': 'application/problem+json'},
    body: jsonEncode({
      'type': 'about:blank',
      'title': 'Duplicate Email',
      'status': 409,
      'detail': 'A user with email ${e.email} already exists',
    }),
  );
}

// Register handlers
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: repository,
    serializers: {'application/json': serializer},
    customExceptionHandlers: {
      InvalidEmailException: handleInvalidEmail,
      DuplicateEmailException: handleDuplicateEmail,
    },
  ),
);
```

#### Exception Handling Flow

1. Custom exception handlers are checked first
2. If no custom handler matches, falls back to built-in error mapping
3. Built-in handlers cover framework exceptions (RepositoryException, DeserializationException, etc.)

### Error Responses

All error responses use **RFC 7807 Problem Details** format with `Content-Type: application/problem+json`:

```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "User with ID 123e4567-e89b-12d3-a456-426614174000 not found"
}
```

#### Built-in Error Mappings

| Exception | HTTP Status | Title |
|-----------|-------------|-------|
| RepositoryException (notFound) | 404 | Not Found |
| RepositoryException (duplicate) | 409 | Conflict |
| RepositoryException (constraint) | 422 | Unprocessable Entity |
| DeserializationException | 400 | Bad Request |
| SerializationException | 500 | Internal Server Error |
| UnsupportedMediaTypeException | 406 | Not Acceptable |
| Unsupported Content-Type | 415 | Unsupported Media Type |
| Other exceptions | 500 | Internal Server Error |

## ETag Concurrency Control

ETags provide optimistic concurrency control to prevent lost updates when multiple clients modify the same resource concurrently.

### How It Works

1. **GET requests** include an `ETag` header with the resource version
2. **PUT requests** can include an `If-Match` header with the ETag
3. Server validates the ETag before updating
4. If ETag doesn't match, returns `412 Precondition Failed`

### Basic Usage

```dart
// Configure resource with ETag support (enabled by default)
server.registerResource(
  CrudResource<User>(
    path: '/users',
    repository: repository,
    serializers: {'application/json': serializer},
    etagStrategy: ETagStrategy.timestamp,  // Default
  ),
);
```

### Client Flow

```bash
# Step 1: Fetch resource (receives ETag)
curl http://localhost:8080/users/123
# Response includes: ETag: "2024-01-15T10:30:00.000Z"

# Step 2: Update with If-Match header
curl -X PUT http://localhost:8080/users/123 \
  -H "Content-Type: application/json" \
  -H "If-Match: \"2024-01-15T10:30:00.000Z\"" \
  -d '{"id":"123","name":"Updated",...}'

# Success: 200 OK with new ETag
# Conflict: 412 Precondition Failed with current ETag
```

### ETag Strategies

**Timestamp Strategy** (default):
- Uses aggregate's `updatedAt` timestamp
- Fast and efficient
- Detects changes based on modification time

```dart
etagStrategy: ETagStrategy.timestamp
```

**Content Hash Strategy**:
- Uses SHA-256 hash of serialized content
- More precise - detects any content change
- Slightly slower due to hashing

```dart
etagStrategy: ETagStrategy.contentHash
```

### Handling Conflicts

When a `412 Precondition Failed` response is received:

1. Response includes current ETag in header
2. Client fetches latest version
3. Client merges changes
4. Client retries with new ETag

**Example 412 Response:**
```json
{
  "type": "about:blank",
  "title": "Precondition Failed",
  "status": 412,
  "detail": "Resource was modified by another client"
}
```

**Headers:**
- `ETag: "2024-01-15T11:00:00.000Z"` - Current resource version

### Backward Compatibility

ETags are **optional** - the `If-Match` header is not required:

- **With If-Match**: Validates ETag, returns 412 on mismatch
- **Without If-Match**: Updates without validation (backward compatible)

This allows gradual adoption without breaking existing clients.

### Concurrent Update Example

```dart
// Client A fetches user
final responseA = await client.get('/users/123');
final etagA = responseA.headers['etag'];

// Client B fetches user (same ETag)
final responseB = await client.get('/users/123');
final etagB = responseB.headers['etag'];

// Client A updates successfully
await client.put(
  '/users/123',
  headers: {'If-Match': etagA},
  body: updatedDataA,
);

// Client B's update is rejected (stale ETag)
final responseBUpdate = await client.put(
  '/users/123',
  headers: {'If-Match': etagB},  // Stale!
  body: updatedDataB,
);
// Returns: 412 Precondition Failed

// Client B fetches latest and retries
final latestResponse = await client.get('/users/123');
final latestETag = latestResponse.headers['etag'];
await client.put(
  '/users/123',
  headers: {'If-Match': latestETag},
  body: mergedData,
);
```

See [example/etag_concurrency_example.dart](example/etag_concurrency_example.dart) for a complete working example.

## Complete Example

See the [example application](example/main.dart) for a complete working implementation that demonstrates:

- Defining an aggregate root with child entities and value objects
- Creating a JSON serializer
- Setting up an HTTP server with CRUD endpoints
- Registering custom query handlers (firstName, email)
- Registering custom exception handlers
- Configuring pagination
- Sample data seeding

Run the example:

```bash
cd packages/dddart_rest/example
dart run main.dart
```

Then test the endpoints:

```bash
# List all users
curl http://localhost:8080/users

# Get user by ID
curl http://localhost:8080/users/<id>

# Filter by first name
curl http://localhost:8080/users?firstName=John

# Create user
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Bob","lastName":"Smith","email":"bob@example.com","address":{"street":"123 Main St","city":"Portland","state":"OR","zipCode":"97201","country":"USA"}}'
```

## API Reference

### HttpServer

Main server class that manages the shelf HTTP server lifecycle.

```dart
class HttpServer {
  HttpServer({this.port = 8080});
  
  void registerResource<T extends AggregateRoot>(CrudResource<T> resource);
  Future<void> start();
  Future<void> stop();
}
```

### CrudResource<T>

Configures and handles CRUD operations for an aggregate root type.

```dart
class CrudResource<T extends AggregateRoot> {
  CrudResource({
    required String path,
    required Repository<T> repository,
    required Map<String, Serializer<T>> serializers,
    Map<String, QueryHandler<T>> queryHandlers = const {},
    Map<Type, Response Function(Object)> customExceptionHandlers = const {},
    int defaultSkip = 0,
    int defaultTake = 50,
    int maxTake = 100,
    ETagStrategy etagStrategy = ETagStrategy.timestamp,
  });
}
```

**Parameters:**
- `path` - Base URL path for the resource (e.g., '/users')
- `repository` - Repository instance for persistence operations
- `serializers` - Map of content types to serializer instances (first is default)
- `queryHandlers` - Map of query parameter names to handler functions
- `customExceptionHandlers` - Map of exception types to error response handlers
- `defaultSkip` - Default skip value for pagination (default: 0)
- `defaultTake` - Default take value for pagination (default: 50)
- `maxTake` - Maximum allowed take value (default: 100)
- `etagStrategy` - Strategy for generating ETags (default: timestamp)
- `serializers` - Map of content types to serializer instances (first is default)
- `queryHandlers` - Map of query parameter names to handler functions
- `customExceptionHandlers` - Map of exception types to error response handlers
- `defaultSkip` - Default skip value for pagination (default: 0)
- `defaultTake` - Default take value for pagination (default: 50)
- `maxTake` - Maximum allowed take value (default: 100)

### QueryHandler<T>

Function signature for custom query handlers.

```dart
typedef QueryHandler<T extends AggregateRoot> = Future<QueryResult<T>> Function(
  Repository<T> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
);
```

### QueryResult<T>

Result from a query handler including items and optional total count.

```dart
class QueryResult<T extends AggregateRoot> {
  QueryResult(this.items, {this.totalCount});
  
  final List<T> items;
  final int? totalCount;
}
```

### ErrorMapper

Maps domain exceptions to HTTP responses.

```dart
class ErrorMapper {
  static Response mapException(Object error, StackTrace stackTrace);
}
```

### ResponseBuilder<T>

Builds HTTP responses with proper status codes and serialization.

```dart
class ResponseBuilder<T extends AggregateRoot> {
  Response ok(T aggregate, Serializer<T> serializer, String contentType);
  Response created(T aggregate, Serializer<T> serializer, String contentType);
  Response okList(List<T> aggregates, Serializer<T> serializer, String contentType, {int? totalCount});
  Response noContent();
  Response badRequest(String message);
  Response notFound(String message);
}
```

## Architecture

The framework follows a layered architecture:

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

## Migration from dddart_http

This package was renamed from `dddart_http` to `dddart_rest` to better reflect its purpose of providing RESTful CRUD APIs, distinguishing it from other HTTP concerns like webhook handling.

### Migration Steps

**1. Update pubspec.yaml:**
```yaml
dependencies:
  dddart_rest: ^0.9.0  # Changed from dddart_http
```

**2. Update imports:**
```dart
// Before
import 'package:dddart_http/dddart_http.dart';

// After
import 'package:dddart_rest/dddart_rest.dart';
```

**3. Update logger configuration (if used):**
```dart
// Before
Logger('dddart.http').level = Level.INFO;

// After
Logger('dddart.rest').level = Level.INFO;
```

**4. Run pub get and test:**
```bash
dart pub get
dart test
```

### What Changed

- **Package name**: `dddart_http` → `dddart_rest`
- **Import path**: `package:dddart_http/*` → `package:dddart_rest/*`
- **Logger name**: `dddart.http` → `dddart.rest`

### What Stayed the Same

- All API surfaces remain identical
- No breaking changes to functionality
- All class names and methods unchanged

## Authentication

dddart_rest provides comprehensive JWT-based authentication with support for both self-hosted and OAuth/OIDC providers.

### Authentication Modes

**Self-Hosted Authentication:**
- Your application manages user credentials
- Issues JWT access tokens and refresh tokens
- Provides login, refresh, logout, and device flow endpoints
- Requires refresh token storage (in-memory or database)

**OAuth/OIDC Authentication:**
- External provider (AWS Cognito, Auth0, Okta) manages authentication
- Your application validates JWTs using provider's public keys (JWKS)
- No authentication endpoints needed (provider handles them)
- No refresh token storage needed

### Quick Start: Self-Hosted Authentication

#### 1. Define Custom Claims

Create a class for your JWT claims and annotate with `@JwtSerializable()`:

```dart
import 'package:dddart_rest/dddart_rest.dart';

part 'user_claims.g.dart';

@JwtSerializable()
class UserClaims {
  const UserClaims({
    required this.userId,
    required this.email,
    this.roles = const [],
  });
  
  final String userId;
  final String email;
  final List<String> roles;
}
```

Run code generation:
```bash
dart run build_runner build
```

This generates extension methods for serializing/deserializing claims.

#### 2. Set Up Repositories

Choose your persistence strategy:

**Option A: In-Memory (Quick Start / Testing)**

```dart
import 'package:dddart_rest/dddart_rest.dart';

final refreshTokenRepo = InMemoryRepository<RefreshToken>();
final deviceCodeRepo = InMemoryRepository<DeviceCode>();
```

**Option B: MongoDB (Production)**

Extend the base classes and annotate for code generation:

```dart
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

@Serializable()
@GenerateMongoRepository()
class AppRefreshToken extends RefreshToken {
  AppRefreshToken({
    required super.id,
    required super.userId,
    required super.token,
    required super.expiresAt,
    super.revoked,
    super.deviceInfo,
  });
}

@Serializable()
@GenerateMongoRepository()
class AppDeviceCode extends DeviceCode {
  AppDeviceCode({
    required super.id,
    required super.deviceCode,
    required super.userCode,
    required super.clientId,
    required super.expiresAt,
    super.userId,
    super.status,
  });
}

part 'auth_models.g.dart';
```

Run code generation:
```bash
dart run build_runner build
```

Then create repository instances:
```dart
final refreshTokenRepo = AppRefreshTokenMongoRepository(database);
final deviceCodeRepo = AppDeviceCodeMongoRepository(database);
```

#### 3. Create Auth Handler

```dart
final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
  secret: 'your-256-bit-secret',  // Store in environment variable!
  refreshTokenRepository: refreshTokenRepo,
  issuer: 'https://api.example.com',
  audience: 'my-app',
  accessTokenDuration: Duration(minutes: 15),
  refreshTokenDuration: Duration(days: 7),
);
```

#### 4. Set Up Auth Endpoints

```dart
final authEndpoints = AuthEndpoints(
  authHandler: authHandler,
  deviceCodeRepository: deviceCodeRepo,
  userValidator: (username, password) async {
    // Validate credentials against your user database
    final user = await userRepo.findByUsername(username);
    if (user != null && user.verifyPassword(password)) {
      return user.id;
    }
    return null;
  },
  claimsBuilder: (userId) async {
    // Build claims for the user
    final user = await userRepo.getById(userId);
    return UserClaims(
      userId: user.id,
      email: user.email,
      roles: user.roles,
    );
  },
);

// Register auth endpoints
server.addRoute('POST', '/auth/login', authEndpoints.handleLogin);
server.addRoute('POST', '/auth/refresh', authEndpoints.handleRefresh);
server.addRoute('POST', '/auth/logout', authEndpoints.handleLogout);
server.addRoute('POST', '/auth/device', authEndpoints.handleDeviceCode);
server.addRoute('GET', '/auth/device/verify', authEndpoints.handleDeviceVerify);
server.addRoute('POST', '/auth/token', authEndpoints.handleToken);
```

#### 5. Protect Resources

```dart
server.registerResource(
  CrudResource<User, UserClaims>(
    path: '/users',
    repository: userRepo,
    serializers: {'application/json': serializer},
    authHandler: authHandler,  // Require authentication
  ),
);

// Public resource (no auth required)
server.registerResource(
  CrudResource<Product>(
    path: '/products',
    repository: productRepo,
    serializers: {'application/json': serializer},
    // No authHandler = public access
  ),
);
```

### Quick Start: OAuth/OIDC Authentication

#### 1. Define Custom Claims

Same as self-hosted - create a claims class matching your provider's JWT structure:

```dart
@JwtSerializable()
class CognitoClaims {
  const CognitoClaims({
    required this.sub,
    required this.email,
    this.cognitoGroups = const [],
  });
  
  final String sub;
  final String email;
  final List<String> cognitoGroups;
}
```

#### 2. Create OAuth Auth Handler

```dart
final authHandler = OAuthJwtAuthHandler<CognitoClaims>(
  jwksUri: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123/.well-known/jwks.json',
  issuer: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123',
  audience: 'your-cognito-client-id',
  cacheDuration: Duration(hours: 24),
);
```

#### 3. Protect Resources

```dart
server.registerResource(
  CrudResource<User, CognitoClaims>(
    path: '/users',
    repository: userRepo,
    serializers: {'application/json': serializer},
    authHandler: authHandler,
  ),
);
```

**Note:** With OAuth, you don't need auth endpoints - users authenticate through the OAuth provider (Cognito, Auth0, etc.).

### Using Authentication in Custom Handlers

Access user identity and claims in custom query handlers:

```dart
queryHandlers: {
  'me': (repo, params, skip, take, authResult) async {
    // authResult is null for public resources
    // authResult is non-null for protected resources
    
    if (authResult == null) {
      throw UnauthorizedException();
    }
    
    // Type-safe access to claims
    final userId = authResult.claims.userId;
    final email = authResult.claims.email;
    final isAdmin = authResult.claims.roles.contains('admin');
    
    // Return user's own data
    final user = await repo.getById(userId);
    return QueryResult([user], totalCount: 1);
  },
}
```

### Authentication Endpoints (Self-Hosted Only)

#### POST /auth/login

Username/password login.

**Request:**
```json
{
  "username": "alice",
  "password": "secret"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

#### POST /auth/refresh

Refresh access token.

**Request:**
```json
{
  "refresh_token": "def50200..."
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGc...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

#### POST /auth/logout

Revoke refresh token.

**Request:**
```json
{
  "refresh_token": "def50200..."
}
```

**Response:** 204 No Content

#### POST /auth/device

Initiate device flow (for CLI tools).

**Request:**
```json
{
  "client_id": "my-cli-app"
}
```

**Response (200 OK):**
```json
{
  "device_code": "abc123...",
  "user_code": "WDJB-MJHT",
  "verification_uri": "https://api.example.com/auth/device/verify",
  "expires_in": 600,
  "interval": 5
}
```

#### GET /auth/device/verify

Verification page for users to enter device code (HTML form).

#### POST /auth/token

Poll for device flow tokens.

**Request:**
```json
{
  "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
  "device_code": "abc123...",
  "client_id": "my-cli-app"
}
```

**Response (pending):**
```json
{
  "error": "authorization_pending"
}
```

**Response (approved):**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "def50200...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

### JWT Claims Code Generation

The `@JwtSerializable()` annotation generates extension methods for serializing and deserializing claims:

```dart
// Your claims class
@JwtSerializable()
class UserClaims {
  const UserClaims({required this.userId, required this.email});
  final String userId;
  final String email;
}

// Generated extension (in user_claims.g.dart)
extension JwtAuthHandlerUserClaimsExtension on JwtAuthHandler<UserClaims> {
  UserClaims parseClaimsFromJson(Map<String, dynamic> json) {
    return UserClaims(
      userId: json['userId'] as String,
      email: json['email'] as String,
    );
  }
  
  Map<String, dynamic> claimsToJson(UserClaims claims) {
    return {
      'userId': claims.userId,
      'email': claims.email,
    };
  }
}
```

The extension methods are automatically used by the auth handler - no manual wiring needed!

### Built-in StandardClaims

For simple cases, use the pre-generated `StandardClaims` class:

```dart
final authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
  secret: 'your-secret',
  refreshTokenRepository: refreshTokenRepo,
);

// StandardClaims includes: sub, email, name
```

### Security Considerations

**Signing Secrets:**
- Use minimum 256 bits (32 bytes) for HMAC-SHA256
- Store in environment variables, never in code
- Rotate periodically (invalidates all tokens)

**Token Lifetimes:**
- Access tokens: Short-lived (15 minutes default)
- Refresh tokens: Long-lived (7 days default) but revocable
- Device codes: Very short (10 minutes)

**HTTPS Required:**
- Always use HTTPS in production
- Tokens transmitted in Authorization header, not URL

**Rate Limiting:**
- Implement rate limiting on auth endpoints
- Prevent brute force attacks on device codes
- Consider CAPTCHA for repeated failures

**Error Messages:**
- Never expose signing secrets in errors
- Keep error messages generic to prevent information leakage
- Use RFC 7807 format for consistency

### Client Library

For CLI tools and applications, use `dddart_rest_client` for automatic token management:

```dart
import 'package:dddart_rest_client/dddart_rest_client.dart';

final authProvider = DeviceFlowAuthProvider(
  authUrl: 'https://api.example.com/auth',
  clientId: 'my-cli-app',
  credentialsPath: '/path/to/credentials.json',
);

await authProvider.login();  // Device flow

final client = RestClient(
  baseUrl: 'https://api.example.com',
  authProvider: authProvider,
);

// Tokens automatically included and refreshed
final response = await client.get('/users');
```

See the [dddart_rest_client documentation](../dddart_rest_client/README.md) for details.

## License

MIT License - see LICENSE file for details
