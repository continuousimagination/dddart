# dddart_http Example

This example demonstrates how to use the `dddart_http` package to create a RESTful HTTP CRUD API for aggregate roots using Domain-Driven Design principles.

## What This Example Demonstrates

This is a complete, working example that shows:

- **Domain-Driven Design Patterns**:
  - Aggregate Root (User)
  - Child Entity (Profile)
  - Value Object (Address)
  - Repository Pattern (InMemoryRepository)

- **HTTP CRUD API Features**:
  - RESTful endpoints for Create, Read, Update, Delete operations
  - Custom query handlers for filtering (by firstName, by email)
  - Custom exception handlers for domain errors
  - Pagination with skip/take parameters
  - Content negotiation (Accept/Content-Type headers)
  - RFC 7807 error responses

- **Best Practices**:
  - Separation of concerns (domain, serialization, HTTP layers)
  - Type-safe serialization
  - Comprehensive inline documentation
  - Sample data for immediate testing

## Quick Start

### 1. Install Dependencies

From the example directory:
```bash
dart pub get
```

### 2. Run the Server

```bash
dart run main.dart
```

You should see:
```
Starting HTTP CRUD API Example...

Seeded 5 sample users
  - 2 users named "John" (for firstName query testing)
  - 3 users with profiles, 2 without (demonstrates optional child entity)
  - All users have addresses (demonstrates required value object)
Server running on http://localhost:8080

Available endpoints:
  GET    /users           - List all users (paginated)
  GET    /users/:id       - Get user by ID
  GET    /users?firstName=John - Filter by first name
  GET    /users?email=john@example.com - Filter by email
  POST   /users           - Create new user
  PUT    /users/:id       - Update user
  DELETE /users/:id       - Delete user

Pagination parameters:
  ?skip=N&take=M          - Skip N items, return M items

Press Ctrl+C to stop the server
```

### 3. Try the API

Open a new terminal and try these commands:

```bash
# List all users
curl http://localhost:8080/users

# Get first user (copy an ID from the list above)
curl http://localhost:8080/users/{paste-id-here}

# Filter by first name (should return 2 Johns)
curl http://localhost:8080/users?firstName=John

# Filter by email (should return 1 user)
curl http://localhost:8080/users?email=john.doe@example.com
```

## API Reference

### List All Users (Paginated)

Returns all users with pagination support.

**Request:**
```bash
# Get all users (default: skip=0, take=10)
curl http://localhost:8080/users

# Get users 3-4 (skip first 2, return 2)
curl http://localhost:8080/users?skip=2&take=2

# Get first 3 users
curl http://localhost:8080/users?take=3
```

**Response:** `200 OK`
```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "address": {
      "street": "123 Main St",
      "city": "Springfield",
      "state": "IL",
      "zipCode": "62701",
      "country": "USA"
    },
    "profile": {
      "id": "987fcdeb-51a2-43f7-b123-456789abcdef",
      "bio": "Software developer and tech enthusiast",
      "avatarUrl": "https://example.com/avatars/john.jpg",
      "phoneNumber": "+1-555-0101",
      "createdAt": "2024-01-15T10:30:00Z",
      "updatedAt": "2024-01-15T10:30:00Z"
    },
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
]
```

**Headers:**
- `X-Total-Count: 5` - Total number of users (before pagination)
- `Content-Type: application/json`

---

### Get User by ID

Retrieves a single user by their unique ID.

**Request:**
```bash
curl http://localhost:8080/users/123e4567-e89b-12d3-a456-426614174000
```

**Response:** `200 OK`
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@example.com",
  "address": {
    "street": "123 Main St",
    "city": "Springfield",
    "state": "IL",
    "zipCode": "62701",
    "country": "USA"
  },
  "profile": {
    "id": "987fcdeb-51a2-43f7-b123-456789abcdef",
    "bio": "Software developer and tech enthusiast",
    "avatarUrl": "https://example.com/avatars/john.jpg",
    "phoneNumber": "+1-555-0101",
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  },
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

**Error Response:** `404 Not Found`
```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "User with ID 123e4567-... not found"
}
```

---

### Filter by First Name

Returns all users with matching first name (case-insensitive).

**Request:**
```bash
# Find all users named "John" (should return 2)
curl http://localhost:8080/users?firstName=John

# With pagination
curl "http://localhost:8080/users?firstName=John&skip=0&take=1"
```

**Response:** `200 OK`
```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    ...
  },
  {
    "id": "456e7890-e89b-12d3-a456-426614174111",
    "firstName": "John",
    "lastName": "Anderson",
    "email": "john.anderson@example.com",
    ...
  }
]
```

**Headers:**
- `X-Total-Count: 2` - Total matching users
- `Content-Type: application/json`

---

### Filter by Email

Returns users with matching email (case-insensitive). Since email is unique, this returns 0 or 1 user.

**Request:**
```bash
curl http://localhost:8080/users?email=john.doe@example.com
```

**Response:** `200 OK`
```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    ...
  }
]
```

**Headers:**
- `X-Total-Count: 1`

**Note:** Even though email is unique, the response is still an array (REST convention for collection endpoints).

---

### Create User

Creates a new user.

**Request:**
```bash
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "id": "111e4567-e89b-12d3-a456-426614174222",
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "address": {
      "street": "123 Test St",
      "city": "Testville",
      "state": "TS",
      "zipCode": "12345",
      "country": "USA"
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }'
```

**Response:** `201 Created`
```json
{
  "id": "111e4567-e89b-12d3-a456-426614174222",
  "firstName": "Test",
  "lastName": "User",
  "email": "test@example.com",
  "address": {
    "street": "123 Test St",
    "city": "Testville",
    "state": "TS",
    "zipCode": "12345",
    "country": "USA"
  },
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Optional Profile:**
```bash
# Create user with profile
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "id": "222e4567-e89b-12d3-a456-426614174333",
    "firstName": "Test",
    "lastName": "User",
    "email": "test2@example.com",
    "address": {
      "street": "123 Test St",
      "city": "Testville",
      "state": "TS",
      "zipCode": "12345",
      "country": "USA"
    },
    "profile": {
      "id": "333e4567-e89b-12d3-a456-426614174444",
      "bio": "Test user bio",
      "avatarUrl": "https://example.com/avatar.jpg",
      "phoneNumber": "+1-555-0199",
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T00:00:00Z"
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }'
```

---

### Update User

Updates an existing user (full replacement).

**Request:**
```bash
curl -X PUT http://localhost:8080/users/111e4567-e89b-12d3-a456-426614174222 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "111e4567-e89b-12d3-a456-426614174222",
    "firstName": "Updated",
    "lastName": "Name",
    "email": "updated@example.com",
    "address": {
      "street": "456 New St",
      "city": "Newville",
      "state": "NV",
      "zipCode": "67890",
      "country": "USA"
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-02T00:00:00Z"
  }'
```

**Response:** `200 OK`
```json
{
  "id": "111e4567-e89b-12d3-a456-426614174222",
  "firstName": "Updated",
  "lastName": "Name",
  "email": "updated@example.com",
  ...
}
```

---

### Delete User

Deletes a user by ID.

**Request:**
```bash
curl -X DELETE http://localhost:8080/users/111e4567-e89b-12d3-a456-426614174222
```

**Response:** `204 No Content`

(Empty response body)

**Error Response:** `404 Not Found`
```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "User with ID 111e4567-... not found"
}
```

---

## Error Handling

All errors follow **RFC 7807 Problem Details** format with `Content-Type: application/problem+json`.

### Common Error Responses

**400 Bad Request** - Invalid input
```json
{
  "type": "about:blank",
  "title": "Bad Request",
  "status": 400,
  "detail": "Invalid JSON in request body"
}
```

**404 Not Found** - Resource doesn't exist
```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "User with ID 123e4567-... not found"
}
```

**409 Conflict** - Duplicate email (custom exception)
```json
{
  "type": "about:blank",
  "title": "Duplicate Email",
  "status": 409,
  "detail": "A user with email test@example.com already exists"
}
```

**415 Unsupported Media Type** - Wrong Content-Type
```json
{
  "type": "about:blank",
  "title": "Unsupported Media Type",
  "status": 415,
  "detail": "Content-Type text/plain is not supported. Supported types: application/json"
}
```

---

## Code Structure

```
example/
├── lib/
│   ├── models/              # Domain models
│   │   ├── user.dart        # Aggregate root with comprehensive DDD comments
│   │   ├── profile.dart     # Child entity with lifecycle
│   │   └── address.dart     # Value object (immutable)
│   ├── serializers/
│   │   └── user_serializer.dart  # JSON serialization logic
│   ├── handlers/
│   │   ├── query_handlers.dart      # Custom query filters
│   │   └── exception_handlers.dart  # Domain exception mapping
│   └── exceptions/
│       └── user_exceptions.dart     # Domain-specific exceptions
└── main.dart                # Server setup and configuration
```

---

## Key Concepts Explained

### 1. Aggregate Root (User)

The `User` class is an **aggregate root** - the entry point to a cluster of related objects:
- Has unique identity (id)
- Controls access to child entities (Profile) and value objects (Address)
- Ensures consistency within the aggregate boundary
- Repository operations work on the entire aggregate

See `lib/models/user.dart` for detailed comments on the aggregate pattern.

### 2. Child Entity (Profile)

The `Profile` class is a **child entity** within the User aggregate:
- Has its own identity (id) and lifecycle (createdAt, updatedAt)
- Can only be accessed through the User aggregate root
- Optional - not all users have profiles
- Lifecycle managed by the parent aggregate

See `lib/models/profile.dart` for detailed comments on child entities.

### 3. Value Object (Address)

The `Address` class is a **value object**:
- Immutable (all fields final, const constructor)
- Defined by its attributes, not identity
- Two addresses with same values are equal
- No independent lifecycle - always part of User

See `lib/models/address.dart` for detailed comments on value objects.

### 4. Custom Query Handlers

Query handlers enable filtering on collection endpoints:

```dart
// Registered in main.dart
queryHandlers: {
  'firstName': firstNameQueryHandler,
  'email': emailQueryHandler,
}

// Invoked when: GET /users?firstName=John
// Returns: QueryResult with filtered users and total count
```

See `lib/handlers/query_handlers.dart` for detailed implementation comments.

### 5. Custom Exception Handlers

Exception handlers map domain exceptions to HTTP responses:

```dart
// Registered in main.dart
customExceptionHandlers: {
  InvalidEmailException: handleInvalidEmailException,
  DuplicateEmailException: handleDuplicateEmailException,
}

// When InvalidEmailException is thrown → 400 Bad Request
// When DuplicateEmailException is thrown → 409 Conflict
```

See `lib/handlers/exception_handlers.dart` and `lib/exceptions/user_exceptions.dart` for detailed comments.

---

## Sample Data

The example seeds 5 users on startup:

1. **John Doe** - Has profile, email: john.doe@example.com
2. **Jane Smith** - Has profile, email: jane.smith@example.com
3. **Bob Johnson** - No profile, email: bob.johnson@example.com
4. **Alice Williams** - Has profile, email: alice.williams@example.com
5. **John Anderson** - No profile, email: john.anderson@example.com

This data is designed to test:
- firstName filter (2 Johns)
- email filter (unique emails)
- Optional profiles (3 with, 2 without)
- Pagination (5 total users)

---

## Pagination

All collection endpoints support pagination:

**Query Parameters:**
- `skip` - Number of items to skip (default: 0)
- `take` - Number of items to return (default: 10, max: 50)

**Response Header:**
- `X-Total-Count` - Total number of items (before pagination)

**Examples:**
```bash
# Get first page (items 1-10)
curl http://localhost:8080/users

# Get second page (items 11-20)
curl http://localhost:8080/users?skip=10&take=10

# Get items 3-5
curl http://localhost:8080/users?skip=2&take=3
```

---

## Next Steps

1. **Explore the Code**: Read the inline comments in each file to understand the patterns
2. **Modify the Domain**: Add new fields to User, create new value objects
3. **Add Query Handlers**: Implement filtering by lastName, city, etc.
4. **Add Validation**: Throw InvalidEmailException in User constructor
5. **Try Different Serializers**: Implement YAML or XML serializer
6. **Add Business Logic**: Implement domain methods on User aggregate

---

## Production Considerations

This is a learning example. For production use:

- **Persistence**: Replace InMemoryRepository with database repository
- **Validation**: Add input validation in domain models
- **Security**: Add authentication, authorization, rate limiting
- **Logging**: Add structured logging for debugging
- **Monitoring**: Add metrics and health checks
- **Error Handling**: Sanitize error messages to avoid information leakage
- **Testing**: Add unit and integration tests
- **Documentation**: Generate OpenAPI/Swagger documentation

---

## Learn More

- [dddart Package](../../packages/dddart/README.md) - Core DDD abstractions
- [dddart_http Package](../README.md) - HTTP CRUD API framework
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html) - Martin Fowler's overview
- [RFC 7807](https://tools.ietf.org/html/rfc7807) - Problem Details for HTTP APIs
