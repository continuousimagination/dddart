# Migration Guide

## Client-bound, single-use device grants (Unreleased)

`AuthEndpoints` now requires a `DeviceCodeRepository<TDeviceCode>` instead of a
plain `Repository<TDeviceCode>`. Replace the general-purpose in-memory
repository in examples and tests:

```dart
// Before
final deviceCodeRepository = InMemoryRepository<DeviceCode>();

// After
final deviceCodeRepository = InMemoryDeviceCodeRepository<DeviceCode>(
  lifecycle: const StandardDeviceCodeLifecycle(),
);
```

The device-specific repository provides `findByUserCode`, `findByDeviceCode`,
and `consumeApproved`. Redemption supplies both the device code and
`client_id`; the client ID must exactly match the value stored at creation or
the endpoint returns `invalid_grant`.

`consumeApproved` must atomically match an approved, unexpired code for that
client with a non-null user, persist its transition to consumed, and return the
typed consumed value. A non-match returns `null` without mutation. Exactly one
caller can win this transition, so an ordinary read followed by `save()` does
not implement the contract. Production database adapters need a conditional
update or equivalent compare-and-set operation in the database itself.

Every redemption after the successful transition returns `invalid_grant`. If
the successful response is lost after consumption, the client must restart
login and request a new device code. `DeviceFlowAuthProvider` remains
compatible: it reuses one stable client ID for the request and every poll, then
stops after the first successful response.

## Typed token lifecycles (Unreleased)

`JwtAuthHandler` and `AuthEndpoints` no longer construct base token values and
cast them to their generic types. Both constructors now require a lifecycle
whose type exactly matches the corresponding repository:

```dart
final handler = JwtAuthHandler<UserClaims, RefreshToken>(
  secret: secret,
  refreshTokenRepository: refreshTokenRepository,
  refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
  claimsLoader: loadCurrentClaims,
  parseClaimsFromJson: UserClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
);

final endpoints = AuthEndpoints<UserClaims, RefreshToken, DeviceCode>(
  authHandler: handler,
  deviceCodeRepository: deviceCodeRepository,
  deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
  userValidator: validateUser,
);
```

The standard implementations are only for the base `RefreshToken` and
`DeviceCode` types. For a custom subtype, implement the matching typed
contract and use the same type consistently:

```dart
final handler = JwtAuthHandler<UserClaims, AppRefreshToken>(
  secret: secret,
  refreshTokenRepository: appRefreshTokenRepository,
  refreshTokenLifecycle: const AppRefreshTokenLifecycle(),
  claimsLoader: loadCurrentClaims,
  parseClaimsFromJson: UserClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
);

final endpoints =
    AuthEndpoints<UserClaims, AppRefreshToken, AppDeviceCode>(
  authHandler: handler,
  deviceCodeRepository: appDeviceCodeRepository,
  deviceCodeLifecycle: const AppDeviceCodeLifecycle(),
  userValidator: validateUser,
);
```

`RefreshTokenLifecycle<T>` constructs `T` and revokes an existing `T`.
`DeviceCodeLifecycle<T>` constructs `T`, approves an existing `T`, and consumes
an approved `T`. Every creation must initialize the subtype-specific fields.
Every transition must return the requested runtime subtype, preserve those
fields, and apply the base-state transition before it is persisted.

Production storage also needs an adapter that implements the authentication
flows' required lookup and transition behavior. Device-code consumption must be
a database-level conditional operation, not a read followed by `save()`. A
plain generated MongoDB CRUD repository is not documented as sufficient, and
dddart does not currently ship a verified MongoDB authentication adapter.

## Authoritative application claims (Unreleased)

`JwtAuthHandler` now owns the authoritative application-claims loader used for
both initial token issuance and refresh. Move `claimsBuilder` from
`AuthEndpoints` to the handler and remove the claims argument from
`issueTokens`:

```dart
// Before
final handler = JwtAuthHandler<UserClaims, RefreshToken>(
  secret: secret,
  refreshTokenRepository: refreshTokenRepository,
  parseClaimsFromJson: UserClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
);
final endpoints = AuthEndpoints(
  authHandler: handler,
  deviceCodeRepository: deviceCodeRepository,
  userValidator: validateUser,
  claimsBuilder: loadClaims,
);
await handler.issueTokens(userId, claims);

// After
final handler = JwtAuthHandler<UserClaims, RefreshToken>(
  secret: secret,
  refreshTokenRepository: refreshTokenRepository,
  refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
  claimsLoader: loadCurrentClaims,
  parseClaimsFromJson: UserClaims.fromJson,
  claimsToJson: (claims) => claims.toJson(),
);
final endpoints = AuthEndpoints(
  authHandler: handler,
  deviceCodeRepository: deviceCodeRepository,
  deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
  userValidator: validateUser,
);
await handler.issueTokens(userId);
```

The loader is asynchronous and keyed by a validated user ID. It must read
current application state and return `null` for missing, disabled, or otherwise
ineligible users. Role, tenant, and profile changes therefore appear after
refresh. Application claims remain access-token-only; refresh tokens stay
opaque and contain no claim snapshot.

## JSON-only CRUD resources (Unreleased)

`CrudResource<T>` now has one JSON representation. Replace the content-type
serializer map with a single `JsonSerializer<T>`:

```dart
// Before
CrudResource<User>(
  path: '/users',
  repository: userRepository,
  serializers: {'application/json': userSerializer},
);

// After
CrudResource<User>(
  path: '/users',
  repository: userRepository,
  serializer: userJsonSerializer,
);
```

The serializer must implement `JsonSerializer<T>` from `dddart_json`. CRUD
clients must also follow these media rules:

- Send `Content-Type: application/json` with `POST` and `PUT` bodies. Parameters
  such as `charset=utf-8` are allowed. Missing or unsupported content types
  return 415 before authentication, authorization, or repository work.
- Omit `Accept`, use `*/*`, or include a positive-quality `application/json`
  range. Headers that do not allow JSON return 406 before side effects.
- Expect JSON objects for single-resource success responses, JSON arrays for
  collection success responses, and `application/problem+json` for stock errors.
- Ensure every `PUT /resource/:id` JSON body contains the same aggregate ID as
  the route. A mismatch now returns 400 before authorization, ETag lookup, or
  persistence; the route ID is authoritative.

`ResponseBuilder<T>` is also JSON-specific. Remove the positional content-type
argument and pass a `JsonSerializer<T>`:

```dart
// Before
responseBuilder.ok(user, serializer, 'application/json');
responseBuilder.okList(users, serializer, 'application/json');

// After
responseBuilder.ok(user, jsonSerializer);
responseBuilder.okList(users, jsonSerializer);
```

The same change applies to `ResponseBuilder.created`. Successful responses set
`Content-Type: application/json` themselves.

## Breaking Changes in v0.2.0

### AuthHandler → AuthenticationHandler Rename

To improve clarity and distinguish between authentication (verifying identity) and authorization (verifying permissions), the following classes have been renamed:

- `AuthHandler` → `AuthenticationHandler`
- `AuthResult` → `AuthenticationResult`

**This is a breaking change with no deprecation period.**

### Migration Steps

#### 1. Update Import Statements

No changes needed - the classes are exported from the same package.

```dart
// Before and After (no change)
import 'package:dddart_rest/dddart_rest.dart';
```

#### 2. Update Class Names

**Custom Authentication Handler Implementation:**

```dart
// Before
class MyAuthHandler extends AuthHandler<MyClaims> {
  @override
  Future<AuthResult<MyClaims>> authenticate(Request request) async {
    // ... authentication logic
    return AuthResult.success(
      userId: 'user123',
      claims: MyClaims(...),
    );
  }
}

// After
class MyAuthHandler extends AuthenticationHandler<MyClaims> {
  @override
  Future<AuthenticationResult<MyClaims>> authenticate(Request request) async {
    // ... authentication logic
    return AuthenticationResult.success(
      userId: 'user123',
      claims: MyClaims(...),
    );
  }
}
```

**CrudResource Configuration:**

```dart
// Before
final resource = CrudResource<User, StandardClaims>(
  path: '/users',
  repository: userRepo,
  serializer: userSerializer,
  authHandler: jwtAuthHandler,  // Old parameter name
);

// After
final resource = CrudResource<User, StandardClaims>(
  path: '/users',
  repository: userRepo,
  serializer: userSerializer,
  authenticationHandler: jwtAuthHandler,  // New parameter name
);
```

**Mock Authentication Handler for Tests:**

```dart
// Before
class MockAuthHandler implements AuthHandler<String> {
  @override
  Future<AuthResult<String>> authenticate(Request request) async {
    return AuthResult.success(userId: 'test-user');
  }
}

// After
class MockAuthHandler implements AuthenticationHandler<String> {
  @override
  Future<AuthenticationResult<String>> authenticate(Request request) async {
    return AuthenticationResult.success(userId: 'test-user');
  }
}
```

#### 3. Update Type Annotations

```dart
// Before
final AuthHandler<MyClaims>? authHandler;
final AuthResult<MyClaims> result;

// After
final AuthenticationHandler<MyClaims>? authenticationHandler;
final AuthenticationResult<MyClaims> result;
```

#### 4. Update Query Handler Signatures

If you're using custom query handlers, update the `authResult` parameter type:

```dart
// Before
queryHandlers: {
  'me': (repo, params, skip, take, AuthResult<MyClaims>? authResult) async {
    // ... query logic
  },
}

// After
queryHandlers: {
  'me': (repo, params, skip, take, AuthenticationResult<MyClaims>? authResult) async {
    // ... query logic
  },
}
```

### Built-in Authentication Handlers

The built-in authentication handlers have been updated automatically:

- `JwtAuthHandler` now extends `AuthenticationHandler`
- `OAuthJwtAuthHandler` now extends `AuthenticationHandler`

No changes needed to your usage of these classes beyond the parameter name change in `CrudResource`.

### New Authorization Feature

This release also introduces `AuthorizationHandler` for implementing resource-level authorization:

```dart
// New authorization handler interface
class MyAuthorizationHandler extends AuthorizationHandler<User, MyClaims> {
  @override
  Future<AuthorizationResult> authorizeCreate(
    User user,
    AuthenticationResult<MyClaims> authResult,
  ) async {
    // Verify user has permission to create this resource
    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeUpdate(
    User user,
    AuthenticationResult<MyClaims> authResult,
  ) async {
    // Verify user has permission to update this resource
    if (user.id.value != authResult.userId) {
      return AuthorizationResult.deny('You can only update your own profile');
    }
    return AuthorizationResult.allow();
  }

  // ... implement authorizeDelete and authorizeQuery
}

// Wire into CrudResource
final resource = CrudResource<User, MyClaims>(
  path: '/users',
  repository: userRepo,
  serializer: userSerializer,
  authenticationHandler: jwtAuthHandler,  // Verifies identity
  authorizationHandler: myAuthzHandler,   // Verifies permissions
);
```

### Summary of Changes

| Old Name | New Name | Location |
|----------|----------|----------|
| `AuthHandler` | `AuthenticationHandler` | Class name |
| `AuthResult` | `AuthenticationResult` | Class name |
| `authHandler` | `authenticationHandler` | CrudResource parameter |

### Why This Change?

The rename clarifies the distinction between:

- **Authentication**: Verifying *who* the user is (identity)
- **Authorization**: Verifying *what* the user can do (permissions)

This distinction becomes important with the new `AuthorizationHandler` feature, which handles permission checks separately from identity verification.

### Need Help?

If you encounter issues during migration, please:

1. Check that all references to `AuthHandler` are updated to `AuthenticationHandler`
2. Check that all references to `AuthResult` are updated to `AuthenticationResult`
3. Check that `CrudResource` uses `authenticationHandler` parameter (not `authHandler`)
4. Run `dart analyze` to catch any remaining references to old names

For questions or issues, please file an issue on GitHub.
