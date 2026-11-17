# dddart_rest

HTTP authentication also exposes request-independent
`CredentialVerifier<TClaims>.verifyCredential`. Reuse `JwtAuthHandler` or
`OAuthJwtAuthHandler` directly, or instantiate `JwtCredentialVerifier` without
issuance/refresh storage for a native Lambda authorizer. Narrow `credentials.dart`
and `http.dart` exports support standalone runtimes. See the
[aggregate events guide](../../docs/DISTRIBUTED_EVENTS.md) for shared HTTP/AppSync
authentication, policy injection and serverless handler registration.

## Typed identities (pre-release breaking change)

Use `AggregateRoot<UuidValue>` for UUID models and `Repository<User, UuidValue>`
for UUID CRUD. Native models extend `AggregateRoot<IssueId>`. Both base
constructors require an ID; domain constructors can call `UuidValue.generate()`.
Register explicit `IdentityCodec<IssueId>` implementations in an instance-local
`IdentityCodecRegistry`; configure the server's `JsonSerializer` and
`CrudResource<Issue, IssueId, void>` with the same registry. Generated REST
repositories accept `identityCodecs: registry` and share it with body serialization.

`CrudResource<T, I, TClaims>`, `AuthorizationHandler<T, I, TClaims>` and
`QueryHandler<T, I, TClaims>` retain concrete identity and claim types. Read and
delete policies receive persisted aggregates; update policies receive separate
current and proposed snapshots. Query handlers receive typed caller and scope.

Client paths URI-encode canonical codec keys once. `HttpServer` decodes one
segment once; direct `CrudResource.handleGetById/handleUpdate/handleDelete`
callers supply decoded canonical keys. Slash, percent, punctuation and Unicode
remain data. Empty, malformed UTF-8 and dot-only (`.`/`..`) keys are unsupported
and fail before client I/O. Invalid/noncanonical server keys yield problem+json
400; valid missing IDs keep 404. Client 400 and 422 map to repository constraint
errors. POST validates the final aggregate's key after `preCreate`, rejecting
unsupported identities with 400 before authorization or persistence. A get
response with a different typed identity is rejected.


RESTful CRUD API framework for DDDart - Provides REST endpoints for aggregate roots with minimal boilerplate.

## Optional access policies

No verifier or security policy means public CRUD. Installing an
`authenticationHandler` defaults the resource to `AccessPolicy.authenticated()`.
An explicit `defaultPolicy` replaces that default, and `operationPolicies`
replaces it for each selected `CrudOperation`: `read`, `query`, `create`, `update`,
`delete`. A public read override works without credentials on the same resource
whose writes require authentication. No duplicate registration or dummy identity
is needed.

- `AccessPolicy.public()` permits anonymous requests.
- `AccessPolicy.authenticated()` requires the configured verifier; this establishes
  identity, not application ownership or tenant permissions.
- `AccessPolicy.custom(handler, authentication: AuthenticationRequirement.optional)`
  always calls the handler, including with `AnonymousCaller<TClaims>`. Select
  `AuthenticationRequirement.required` when anonymous evaluation is inappropriate.

Required authentication without a verifier is rejected at construction. Optional
operations skip verification when credentials are missing. If a verifier is
installed, supplied invalid credentials return 401 even on public operations;
they never become anonymous after failure. The default detector checks for an
Authorization header, including an empty one. Set `credentialsPresent` for a
cookie or other credential transport. Without a verifier, public requests remain
anonymous and request claims are never trusted.

`AuthorizationHandler<T, I, TClaims>.authorize(context)` receives one of:

| Context | Policy input supplied by the framework |
| --- | --- |
| `ReadContext` | Current persisted aggregate |
| `QueryContext` | Typed caller and untrusted filter parameters |
| `CreateContext` | Final proposed aggregate after `preCreate` |
| `UpdateContext` | Separate current and proposed aggregate snapshots |
| `DeleteContext` | Current persisted aggregate |

Custom aggregate policies require an explicit `authorizationSnapshot` function
that deep-copies the complete domain state, including permission fields omitted
from public JSON. It must preserve identity and metadata, detach mutable values,
and omit transient pending events. Use a domain copy function or a complete
persistence codec, never a lossy public projection. The framework deliberately
has no response-serializer fallback: public serialization must not rewrite the
stored owner seen by policy. Query-only policies do not need aggregate snapshots.
Public and authentication-only resources need no snapshot configuration.

For example, the ownership sample supplies `authorizationSnapshot: snapshotDocument`
alongside its custom policy. Changing a policy context object cannot modify storage
or normalize the eventual proposal. Use `preCreate` for normalization. `Caller<TClaims>` is either `AnonymousCaller` (no claims) or
`VerifiedCaller` (successful verifier result). Claims can be absent if the
application's verifier intentionally returns none.

Return `AuthorizationResult.allow()` or `AuthorizationResult.deny()`.
An allowed custom collection decision must explicitly provide a `QueryScope`;
`UnrestrictedQueryScope()` deliberately exposes all rows selected by that handler.
The framework does not infer a tenant predicate. Denied/thrown collection policies
never invoke query code, including unfiltered and pagination-only requests.

Requests negotiate JSON first, then verify credentials, deserialize/validate
identities, apply `preCreate` for creation, load any current state required by policy,
evaluate access, and only then return protected data or perform mutations.
Missing/invalid required credentials return 401; verified or custom anonymous
denial returns 403. `AuthorizationResult.deny(conceal: true)` returns the same
generic 404 as a missing record. Policy/verifier exceptions return generic 500,
without their private exception text, body, ETag or query counts. Access failures
cannot be overridden through `customExceptionHandlers`.

See [the ownership example](example/authorization_example.dart) for an exhaustive
policy using stored ownership, explicit owner transfer, public objects and scoped
queries. Treat proposed ownership/tenant fields as untrusted unless server-owned
normalization has assigned them. Policies must check the stored state first.

### Run the public/protected example

From `packages/dddart_rest/example`, run:

```bash
dart pub get
dart run public_leaderboard_example.dart
```

The example starts an ephemeral local HTTP server, exercises anonymous leaderboard
reads, authenticated submissions and moderator corrections/deletions, then checks
public/private document scope and an unconfigured public CRUD resource. It closes
the server and exits. Its credential verifier uses deterministic local fixtures;
replace that verifier with JWT/OAuth verification in an application. The policies
and optional/public operation configuration remain the same. This entrypoint is
registered in the normal validation inventory and is executed, not just compiled.

### Read authorization and query scope

Item policy evaluates a detached view of persisted state before the HTTP response
encoder or ETag builder runs. The explicit domain snapshot function is independent
of public serialization; a denied read produces no aggregate response. A concealed denial
and a missing item share the generic 404 body.

Filtered, unfiltered and pagination-only reads all pass through the same selected
collection policy. Scope is application-owned: constrain both the datastore query
and its count with the verified tenant/owner, then apply request filters and
pagination. A request such as `?tenant=someone-else` must never replace that verified
scope. An empty page can still carry the authorized total count, but never a global
count. The ownership example applies its scope before filtering and pagination;
production repositories should perform the equivalent selection in their datastore.

### Mutation authorization and atomic persistence

Custom mutation policies require `ConditionalAggregateRepository<T, I>`. An
incapable repository returns 501 before mutation; it never falls back to a
read/check/ordinary save. Generated SQLite, MySQL, MongoDB and DynamoDB repositories
and `InMemoryConditionalRepository` provide this capability.

For an existing PUT or DELETE, the policy receives the persisted aggregate and
caller (plus the separate PUT proposal). Its decision is bound to that loaded
revision even when the client omits If-Match. If another writer changes ownership
before commit, the CAS rejects the operation: 409 for an implicit policy condition,
or 412 for a client-supplied condition. Reload and make a new authorization decision;
the framework never retries with old permission and a new token. Ownership and
tenant transfer are application policy, not framework-defined roles or immutable
fields. The example checks stored ownership and explicitly permits administrator
transfers while rejecting ordinary owner/tenant reassignment.

POST is create-only. It authorizes the final `preCreate` proposal and uses atomic
create-if-absent when available. An existing identity returns 409 (412 with explicit
`If-None-Match: *`); POST with If-Match is unsupported (501), so create permission
cannot overwrite a protected record. PUT of a missing identity additionally uses
the create policy and `preCreate`, preserving the route ID. It returns 201 when
created. PUT's selected authentication requirement still applies before this lookup;
creation cannot be used to evade a stricter create policy.

A missing ordinary DELETE returns 404; a matching-revision delete of a missing
record returns 412. Explicit assert-absence deletion can return 204 after atomic
absence confirmation. No aggregate-specific hook runs when there is no aggregate
to inspect. Denial, exceptions and conflicts cause no persistence/publication or
pending-event acknowledgment. Policy snapshots cannot normalize stored/proposed
state; use `preCreate` for server-owned creation fields.

Unconfigured public CRUD and deliberately anonymous custom policies remain
supported. Plain repositories retain public/authentication-only CRUD and reject
sequential POST overwrite, but they cannot guarantee isolation of competing
creations. Use the conditional capability for that guarantee or for custom mutation
policy. An authenticated-only policy verifies identity without making an ownership
decision; use a custom policy when permissions depend on stored state.

## Features

- **Automatic CRUD endpoints** - Expose aggregate roots through REST APIs with a single configuration
- **Atomic conditional writes** - Reject stale storage revisions without overwriting a competing update
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
    CrudResource<User, UuidValue, void>(
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
  CrudResource<User, UuidValue, void>(
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
CrudResource<User, UuidValue, void>(
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
abstract interface class UserReadRepository implements Repository<User, UuidValue> {
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
  Repository<User, UuidValue> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  AuthorizedQuery<void> authorization,
) {
  return (repository as UserReadRepository).listPage(
    skip: skip,
    take: take,
  );
}

Future<QueryResult<User>> firstNameHandler(
  Repository<User, UuidValue> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  AuthorizedQuery<void> authorization,
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
  CrudResource<User, UuidValue, void>(
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
  CrudResource<User, UuidValue, void>(
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

## Atomic conditional writes

`CrudResource` uses the optional `ConditionalAggregateRepository<T, I>` capability
for conditional PUT/DELETE. Generated SQLite, MySQL, MongoDB and DynamoDB
repositories implement it. `InMemoryConditionalRepository` provides a detached
reference store for examples/tests. Ordinary CRUD stays available by default.

GET from a versioned repository returns the aggregate and its coherent storage
revision as a strong ETag (`"r1.<base64url UTF-8 revision>"`, without padding).
The token is storage metadata; changing `updatedAt` does not grant permission to
write. Every successful save changes the revision, including identical or
unconditional saves. Deleting and recreating an ID invalidates previous tokens.

```dart
final resource = CrudResource<User, UuidValue, void>(
  path: '/users',
  repository: conditionalRepository,
  serializer: UserJsonSerializer(),
  requirePrecondition: true, // Optional: require a condition on PUT/DELETE.
);
```

| Request | Behavior |
|---|---|
| PUT/DELETE with one strong `If-Match` tag | Atomic match-and-write/delete; a stale or missing record returns 412. |
| Strong tag list | Select a matching revision, then retain that condition through the atomic write. |
| Weak tags | Never match; a list can still match another strong tag. |
| `If-Match: *` | Explicit 501: the shared capability does not expose existence-only writes. GET a revision first. |
| `If-None-Match: *` | Atomic create-if-absent on POST/PUT (201), or assert-absence on DELETE (204). An existing record returns 412. |
| Other valid `If-None-Match` shapes | Explicit 501. |
| Malformed or conflicting condition headers | 400; no mutation. |
| No condition | Ordinary CRUD by default; 428 on PUT/DELETE when `requirePrecondition` is enabled. |

Successful conditional PUT, custom-policy PUT, and creation through a conditional
repository return their committed revision ETag. Public ordinary updates return
no validator: the basic save API does not return a committed token. GET again
before a conditional edit. A plain repository returns
no ETag on GET and rejects requested atomic mutations with 501; requiring
preconditions with such a repository is a configuration error.

A 412 problem response contains no current private content or ETag. Reload,
recompute/re-authorize the intended change, then deliberately submit a new
condition. Storage failures and uncertain commits are server errors, never fake
412s or success. Neither the server nor generated repository retries with a fresh
revision. Authentication and authorization remain separate from this contract.

Run `dart run etag_concurrency_example.dart` from the example directory for a
self-contained two-writer HTTP demonstration. See
[conditional-write semantics](../../docs/CONDITIONAL_WRITES.md) for backend
transaction, topology, and uncertainty boundaries.

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

### CrudResource<T, I, TClaims>

```dart
CrudResource<T, I, TClaims>(
  path: '/records',
  repository: repository,
  serializer: serializer,
  authenticationHandler: verifier, // Optional credential verification
  defaultPolicy: const AccessPolicy.authenticated(),
  operationPolicies: {
    CrudOperation.read: const AccessPolicy.public(),
    CrudOperation.query: const AccessPolicy.public(),
  },
  collectionHandler: collectionHandler,
  queryHandlers: queryHandlers,
  requirePrecondition: false,
);
```

`defaultSkip` (0), `defaultTake` (50), and `maxTake` (100) normalize pagination.
`collectionHandler` handles unfiltered and pagination-only requests; if absent,
those requests return 400. `queryHandlers` selects one named filter. The serializer
and `identityCodecs` use the same typed identity vocabulary. `preCreate` receives
`(T, Caller<TClaims>)` and returns the final proposal before create authorization.

### QueryHandler<T, I, TClaims>

```dart
typedef QueryHandler<T extends AggregateRoot<I>, I extends Identity, TClaims>
    = Future<QueryResult<T>> Function(
  Repository<T, I> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  AuthorizedQuery<TClaims> authorization,
);
```

`authorization.caller` retains the concrete claims type. `authorization.scope`
is an application-defined `QueryScope`; apply it to rows AND totalCount before
pagination. Untrusted owner/tenant filters may narrow this scope, never widen it.
A handler can enforce stricter permissions with `AccessDeniedException`.

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
CrudResource (selects operation policy and verifies the caller)
    ↓
├─ Item GET → Stored snapshot → Read policy
├─ Collection GET → Query policy/scope → Application selection/count/pagination
├─ POST → Deserialize/normalize → Create policy → Create-if-absent
├─ PUT → Current + proposal → Update/create policy → Conditional mutation
└─ DELETE → Current state → Delete policy → Conditional mutation
    ↓
Public/authentication-only ordinary CRUD remains available where no condition is required.
    ↓
ErrorMapper (catches exceptions)
    ↓
ResponseBuilder (serializes result)
    ↓
HTTP Response
```

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
  CrudResource<User, UuidValue, UserClaims>(
    path: '/users',
    repository: userRepo,
    serializer: serializer,
    authenticationHandler: authHandler,  // Require authentication
  ),
);

// Public resource (no auth required)
server.registerResource(
  CrudResource<Product, UuidValue, void>(
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
  CrudResource<User, UuidValue, CognitoClaims>(
    path: '/users',
    repository: userRepo,
    serializer: serializer,
    authenticationHandler: authHandler,
  ),
);
```

**Note:** With OAuth, you don't need auth endpoints - users authenticate through the OAuth provider (Cognito, Auth0, etc.).

### Using Authentication in Custom Handlers

Query handlers receive `AuthorizedQuery<TClaims>`. They may add restrictions to
the resource policy, and must apply its authorized scope to rows/counts before
pagination. Use required authentication on a `me` operation or reject an anonymous
caller explicitly; the context itself is never null.

```dart
queryHandlers: {
  'me': (repo, params, skip, take, authorization) async {
    final claims = authorization.caller.claims;
    if (!authorization.caller.isAuthenticated || claims == null) {
      throw const AccessDeniedException();
    }
    final user = await repo.getById(UuidValue.fromString(claims.userId));
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
