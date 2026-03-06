# Migration Guide

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
  serializers: {'application/json': userSerializer},
  authHandler: jwtAuthHandler,  // Old parameter name
);

// After
final resource = CrudResource<User, StandardClaims>(
  path: '/users',
  repository: userRepo,
  serializers: {'application/json': userSerializer},
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
  serializers: {'application/json': userSerializer},
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
