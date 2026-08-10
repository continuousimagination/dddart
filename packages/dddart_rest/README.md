# dddart_rest

RESTful CRUD API framework for DDDart - Provides REST endpoints for aggregate roots with minimal boilerplate.

> **Note:** This package was previously named `dddart_http`. See the [Migration Guide](#migration-from-dddart_http) below.

## Features

- **Automatic CRUD endpoints** - Expose aggregate roots through REST APIs with a single configuration
- **ETag conditional checks** - Detect changed ETags before an update
- **JWT Authentication** - Built-in support for self-hosted and OAuth/OIDC authentication
- **Device Flow** - OAuth2 device flow for CLI tools and limited-input devices
- **JSON media contract** - JSON success bodies, JSON arrays for collections, and RFC 7807 errors
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
  dddart_json: ^0.9.0
  dddart_serialization: ^0.9.0
```

## Quick Start

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';

void main() async {
  // Create repository and serializer
  final UserReadRepository repository = UserDatabaseRepository();
  final serializer = UserJsonSerializer();

  // Create and configure HTTP server
  final server = HttpServer(port: 8080);
  
  server.registerResource(
    CrudResource<User, void>(
      path: '/users',
      repository: repository,
      serializer: serializer,
      collectionHandler: listUsers,
    ),
  );

  await server.start();
  print('Server running on http://localhost:8080');
}
```

This creates the following endpoints:
- `GET /users` - List a datastore-paginated user collection
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

#### GET - Read a collection page

This endpoint is available only when the resource configures a
`collectionHandler`. The handler owns datastore-side selection, ordering,
pagination, and the accurate total count. Without one, an unfiltered collection
request returns a problem+json `400 Bad Request`; `CrudResource` never loads the
repository and paginates it in memory.

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

Optional header (when the handler supplies `totalCount`):
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

### JSON Media Contract

Each CRUD resource uses one `JsonSerializer<T>`:

```dart
server.registerResource(
  CrudResource<User, void>(
    path: '/users',
    repository: repository,
    serializer: jsonSerializer,
  ),
);
```

#### Request Format (POST/PUT)

`POST` and `PUT` require `Content-Type: application/json`. Media type
parameters and casing are accepted, for example
`Application/JSON; Charset=UTF-8`.

```bash
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"firstName": "John", "email": "john@example.com"}'
```

Missing or unsupported request media types return **415 Unsupported Media
Type** before authentication, authorization, or repository side effects.

#### Response Format (GET)

Success responses use `Content-Type: application/json`. Collection responses
are JSON arrays, including `[]` for an empty collection.

```bash
curl http://localhost:8080/users/123 \
  -H "Accept: application/json"
```

Missing `Accept`, `*/*`, or any comma-separated range containing a positive
quality `application/json` or `*/*` range selects JSON.

An unsupported header, including `application/json;q=0` with no other supported
positive-quality range, returns **406 Not Acceptable** before authentication,
authorization, or repository side effects. Stock errors use
`Content-Type: application/problem+json`.

For `PUT /resource/:id`, the route ID is authoritative. The JSON body's
aggregate ID must match it; otherwise the server returns a problem+json
**400 Bad Request** before authorization, `If-Match` lookup, or persistence.

### Pagination

All collection endpoints support pagination via query parameters:

```bash
# Get items 21-30
curl http://localhost:8080/users?skip=20&take=10
```

When a handler supplies `totalCount`, the response includes an
`X-Total-Count` header:

```
HTTP/1.1 200 OK
X-Total-Count: 150
Content-Type: application/json

[...]
```

#### Configuration

Configure pagination defaults when registering a resource:

```dart
CrudResource<User, void>(
  path: '/users',
  repository: repository,
  serializer: serializer,
  collectionHandler: listUsers,
  defaultSkip: 0,      // Default: 0
  defaultTake: 20,     // Default: 50
  maxTake: 100,        // Default: 100 (prevents excessive queries)
)
```

Pagination applies to:
- Unfiltered collection requests (`GET /users`)
- Filtered requests using custom query handlers (`GET /users?firstName=John`)

### Custom Query Handlers

Define explicit application read contracts and adapt them to collection and
filter handlers:

```dart
abstract interface class UserReadRepository implements Repository<User> {
  Future<QueryResult<User>> listPage({
    required int skip,
    required int take,
  });

  Future<QueryResult<User>> findByFirstName(
    String firstName, {
    required int skip,
    required int take,
  });
}

Future<QueryResult<User>> listUsers(
  Repository<User> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
) {
  return (repository as UserReadRepository).listPage(
    skip: skip,
    take: take,
  );
}

Future<QueryResult<User>> firstNameHandler(
  Repository<User> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
) {
  final firstName = queryParams['firstName']!;
  return (repository as UserReadRepository).findByFirstName(
    firstName,
    skip: skip,
    take: take,
  );
}

// Register the handler
server.registerResource(
  CrudResource<User, void>(
    path: '/users',
    repository: repository,
    serializer: serializer,
    collectionHandler: listUsers,
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

1. **No filter params** - Invokes `collectionHandler`, or returns 400 when no
   collection handler is configured
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
  CrudResource<User, void>(
    path: '/users',
    repository: repository,
    serializer: serializer,
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

## ETag Conditional Update Checks

`CrudResource` includes ETags in item responses and can compare an `If-Match`
header with the currently stored aggregate before a PUT. This can detect a stale
client when another update has already been persisted and produces a different
ETag before the comparison.

The comparison and `repository.save()` are separate operations. They are not an
atomic conditional write, so overlapping requests can both pass validation and
then overwrite one another. Treat this feature as best-effort stale-update
detection, not guaranteed optimistic locking.

### How It Works

1. **GET requests** include an `ETag` header derived from the aggregate
2. **PUT requests** can include an `If-Match` header with the ETag
3. The server reads the current aggregate and compares its ETag
4. If ETag doesn't match, returns `412 Precondition Failed`
5. If it matches, the server later performs an ordinary repository save

### Basic Usage

```dart
// Configure resource with ETag support (enabled by default)
server.registerResource(
  CrudResource<User, void>(
    path: '/users',
    repository: repository,
    serializer: serializer,
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
# Different current ETag: 412 Precondition Failed
```

### ETag Strategies

**Timestamp Strategy** (default):
- Uses aggregate's `updatedAt` timestamp
- Fast and efficient
- Detects changes only when application code advances `updatedAt`

```dart
etagStrategy: ETagStrategy.timestamp
```

**Content Hash Strategy**:
- Uses SHA-256 hash of serialized content
- More precise - detects serialized-content changes at comparison time
- Slightly slower due to hashing

Neither strategy makes the subsequent repository save atomic.

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
  "detail": "The provided ETag does not match the current resource state. Fetch the current representation before retrying."
}
```

**Headers:**
- `ETag: "2024-01-15T11:00:00.000Z"` - ETag derived from the current aggregate

### Backward Compatibility

ETags are **optional** - the `If-Match` header is not required:

- **With If-Match**: Validates ETag, returns 412 on mismatch
- **Without If-Match**: Updates without validation (backward compatible)

This allows gradual adoption without breaking existing clients.

### Sequential Stale-Update Example

This flow rejects Client B because Client A's save completes before Client B's
PUT begins. It does not model two overlapping PUT operations.

```dart
// Client A fetches user
final responseA = await client.get('/users/123');
final etagA = responseA.headers['etag'];

// Client B fetches user (same ETag)
final responseB = await client.get('/users/123');
final etagB = responseB.headers['etag'];

// Client A's update completes successfully
await client.put(
  '/users/123',
  headers: {'If-Match': etagA},
  body: updatedDataA,
);

// Client B's later update is rejected (stale ETag)
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
# Read the default user page
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
  
  void registerResource(CrudResource resource);
  Future<void> start();
  Future<void> stop();
}
```

### CrudResource<T, TClaims>

Configures and handles CRUD operations for an aggregate root type.

```dart
class CrudResource<T extends AggregateRoot, TClaims> {
  CrudResource({
    required String path,
    required Repository<T> repository,
    required JsonSerializer<T> serializer,
    QueryHandler<T>? collectionHandler,
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
- `serializer` - JSON serializer for request and success response bodies
- `collectionHandler` - Optional handler for an unfiltered collection GET. It
  owns selection, ordering, pagination, and `totalCount`; without it the request
  returns 400.
- `queryHandlers` - Map of query parameter names to handler functions
- `customExceptionHandlers` - Map of exception types to error response handlers
- `defaultSkip` - Default skip value for pagination (default: 0)
- `defaultTake` - Default take value for pagination (default: 50)
- `maxTake` - Maximum allowed take value (default: 100)
- `etagStrategy` - Strategy for generating ETags (default: timestamp)
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
  dynamic authResult,
);
```

For `collectionHandler`, `queryParams` is empty. Both collection and named
handlers receive normalized pagination values and the current authentication
result.

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
  Response ok(T aggregate, JsonSerializer<T> serializer, {String? etag});
  Response created(T aggregate, JsonSerializer<T> serializer, {String? etag});
  Response okList(List<T> aggregates, JsonSerializer<T> serializer, {int? totalCount});
  Response noContent();
  Response badRequest(String message);
  Response notAcceptable(String message);
  Response unsupportedMediaType(String message);
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
├─ handleQuery() → Explicit Collection or Named Query Handler
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
- Expiration and not-before claims are enforced with configurable clock skew
- No authentication endpoints needed (provider handles them)
- No refresh token storage needed

### Quick Start: Self-Hosted Authentication

#### 1. Define Custom Claims

Create a class that can parse and serialize your JWT claims. The optional
`@JwtSerializable()` annotation also generates convenience extension methods:

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

  factory UserClaims.fromJson(Map<String, dynamic> json) => UserClaims(
    userId: json['userId'] as String,
    email: json['email'] as String,
    roles: (json['roles'] as List<dynamic>).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'roles': roles,
  };
}
```

Run code generation:
```bash
dart run build_runner build
```

This generates convenience extension methods for serializing and deserializing
claims. The auth handler constructor still requires explicit parser and
serializer callbacks.

#### 2. Set Up Repositories

Choose your persistence strategy:

**Option A: In-Memory (Quick Start / Testing)**

```dart
import 'package:dddart_rest/dddart_rest.dart';

final refreshTokenRepo = InMemoryRefreshTokenRepository<RefreshToken>();
final deviceCodeRepo = InMemoryDeviceCodeRepository<DeviceCode>(
  lifecycle: const StandardDeviceCodeLifecycle(),
);
```

**Production persistence**

Use authentication-specific persistence adapters that implement and test the
lookup and state-transition behavior required by the refresh-token and
device-code flows. A refresh-token adapter implements
`RefreshTokenRepository<T>` and performs `findByToken(String token)` as a
datastore query. Do not assume that a generated CRUD repository is a production
authentication adapter. In particular, the generated MongoDB repositories have
not been verified as sufficient for these flows, and dddart does not currently
ship a verified MongoDB authentication adapter.

A production device-code adapter must implement `DeviceCodeRepository<T>`,
including lookup by user code and device code. Its `consumeApproved` operation
must be one database-level conditional operation that matches the device code,
bound client ID, approved state, non-null user, and expiration, then persists
and returns the typed consumed value. An ordinary read followed by `save()` is
not atomic and does not satisfy this contract.

If an application stores custom `RefreshToken` or `DeviceCode` subtypes, keep
the same concrete type in the repository, handler or endpoints, and lifecycle:

```dart
final authHandler = JwtAuthHandler<UserClaims, AppRefreshToken>(
  secret: secret,
  refreshTokenRepository: appRefreshTokenRepository,
  refreshTokenLifecycle: const AppRefreshTokenLifecycle(),
  claimsLoader: loadCurrentClaims,
  parseClaimsFromJson: UserClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
);

final authEndpoints =
    AuthEndpoints<UserClaims, AppRefreshToken, AppDeviceCode>(
  authHandler: authHandler,
  deviceCodeRepository: appDeviceCodeRepository,
  deviceCodeLifecycle: const AppDeviceCodeLifecycle(),
  userValidator: validateUser,
);
```

`AppRefreshTokenLifecycle` implements
`RefreshTokenLifecycle<AppRefreshToken>` and returns `AppRefreshToken` from
both `create` and `revoke`. `AppDeviceCodeLifecycle` implements
`DeviceCodeLifecycle<AppDeviceCode>` and returns `AppDeviceCode` from `create`,
`approve`, and `consume`. Each `create` method initializes the subtype-specific
fields, and transition methods copy those fields from the current value while
applying the required base-state change. This keeps the runtime subtype and
custom state intact through lookup, transition, and typed persistence.

#### 3. Create Auth Handler

```dart
final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
  secret: 'your-256-bit-secret',  // Store in environment variable!
  refreshTokenRepository: refreshTokenRepo,
  refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
  claimsLoader: (userId) async {
    // Read current application state every time a token is issued.
    final user = await userDirectory.findActiveById(userId);
    if (user == null) {
      // Missing and disabled users must not receive tokens.
      return null;
    }
    return UserClaims(
      userId: user.id,
      email: user.email,
      roles: user.roles,
    );
  },
  parseClaimsFromJson: UserClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
  issuer: 'https://api.example.com',
  audience: 'my-app',
  accessTokenDuration: const Duration(minutes: 15),
  refreshTokenDuration: const Duration(days: 7),
);
```

`claimsLoader` is the authoritative, asynchronous source of application
claims. It runs for initial issuance and again for every refresh, so role,
tenant, and profile changes appear in the next access token. Return `null` when
the user is missing, disabled, or otherwise ineligible. Refresh tokens remain
opaque and contain no application claims; refresh never copies claims from an
old access token.

#### 4. Set Up Auth Endpoints

```dart
final authEndpoints = AuthEndpoints(
  authHandler: authHandler,
  deviceCodeRepository: deviceCodeRepo,
  deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
  userValidator: (username, password) async {
    // Validate credentials against your user database
    final user = await userRepo.findByUsername(username);
    if (user != null && user.verifyPassword(password)) {
      return user.id.toString();
    }
    return null;
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
    serializer: serializer,
    authenticationHandler: authHandler,  // Require authentication
  ),
);

// Public resource (no auth required)
server.registerResource(
  CrudResource<Product, void>(
    path: '/products',
    repository: productRepo,
    serializer: serializer,
    // No authenticationHandler = public access
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
  parseClaimsFromJson: CognitoClaims.fromJson,
  issuer: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123',
  audience: 'your-cognito-client-id',
  cacheDuration: const Duration(hours: 24),
  clockSkewTolerance: const Duration(seconds: 30),
);
```

`OAuthJwtAuthHandler` rejects tokens at or after their `exp` time and tokens
whose `nbf` time is still in the future. `clockSkewTolerance` applies the same
allowance in both directions and defaults to zero.

#### 3. Protect Resources

```dart
server.registerResource(
  CrudResource<User, CognitoClaims>(
    path: '/users',
    repository: userRepo,
    serializer: serializer,
    authenticationHandler: authHandler,
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
    final user = await repo.getById(UuidValue.fromString(userId));
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

The `client_id` must exactly match the client ID stored when the device code was
created. A mismatch returns `invalid_grant`. An approved device grant is
single-use: redemption atomically changes it to consumed, only that caller
receives tokens, and every later attempt returns `invalid_grant`.

If the successful response is lost after the grant is consumed, the tokens
cannot be recovered by polling again. Restart login and request a new device
code.

### JWT Claims Code Generation

The `@JwtSerializable()` annotation generates convenience extension methods on
an existing compatible handler for serializing and deserializing claims:

```dart
// Your claims class
@JwtSerializable()
class UserClaims {
  const UserClaims({required this.userId, required this.email});
  final String userId;
  final String email;
}

// Generated extension (in user_claims.g.dart)
extension JwtAuthHandlerUserClaimsExtension
    on JwtAuthHandler<UserClaims, dynamic> {
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

The generated methods are helpers; they are not automatically wired into the
handler constructor. `JwtAuthHandler` still requires `claimsLoader`,
`parseClaimsFromJson`, and `claimsToJson` callbacks, as shown above.

### Built-in StandardClaims

For simple cases, use the pre-generated `StandardClaims` class:

```dart
final authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
  secret: 'your-secret',
  refreshTokenRepository: refreshTokenRepo,
  refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
  claimsLoader: loadCurrentStandardClaims,
  parseClaimsFromJson: StandardClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
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
final response = await client.getPath('/users');
```

See the [dddart_rest_client documentation](../dddart_rest_client/README.md) for details.

## License

MIT License - see LICENSE file for details
