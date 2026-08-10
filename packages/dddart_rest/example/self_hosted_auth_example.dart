// Example: Self-hosted authentication with in-memory storage
//
// This example demonstrates:
// - Setting up JWT authentication with custom claims
// - Creating auth endpoints (login, refresh, logout, device flow)
// - Protecting resources with authentication
// - Using in-memory repositories for quick start
//
// Run from this example directory: dart run self_hosted_auth_example.dart
// Then test with curl or the CLI client example

import 'dart:async';
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';

import 'lib/json_serializer_support.dart';

// Domain model
class User extends AggregateRoot {
  User({
    required super.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.roles = const [],
  });

  final String username;
  final String email;
  final String passwordHash;
  final List<String> roles;
}

/// User-specific persistence contract used by the authentication flow.
abstract interface class UserRepository implements Repository<User> {
  /// Finds a user by login name.
  Future<User?> findByUsername(String username);
}

/// Instance-local user repository for this example.
final class InMemoryUserRepository implements UserRepository {
  final InMemoryRepository<User> _repository = InMemoryRepository<User>();
  final Map<String, UuidValue> _idsByUsername = {};
  final Map<UuidValue, String> _usernamesById = {};

  @override
  Future<User> getById(UuidValue id) => _repository.getById(id);

  @override
  Future<void> save(User aggregate) async {
    final previousUsername = _usernamesById[aggregate.id];
    if (previousUsername != null && previousUsername != aggregate.username) {
      _idsByUsername.remove(previousUsername);
    }
    await _repository.save(aggregate);
    _idsByUsername[aggregate.username] = aggregate.id;
    _usernamesById[aggregate.id] = aggregate.username;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _repository.deleteById(id);
    final username = _usernamesById.remove(id);
    if (username != null) {
      _idsByUsername.remove(username);
    }
  }

  @override
  Future<User?> findByUsername(String username) {
    final id = _idsByUsername[username];
    return id == null ? Future.value() : _repository.getById(id);
  }
}

// Custom JWT claims
class UserClaims {
  const UserClaims({
    required this.userId,
    required this.username,
    required this.email,
    this.roles = const [],
  });

  final String userId;
  final String username;
  final String email;
  final List<String> roles;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'roles': roles,
      };

  factory UserClaims.fromJson(Map<String, dynamic> json) => UserClaims(
        userId: json['userId'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        roles: (json['roles'] as List?)?.cast<String>() ?? const [],
      );
}

// Simple serializer for User
class UserSerializer extends ExampleJsonSerializer<User> {
  @override
  User deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return User(
      id: UuidValue.fromString(json['id'] as String),
      username: json['username'] as String,
      email: json['email'] as String,
      passwordHash: json['passwordHash'] as String? ?? '',
      roles: (json['roles'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  String serialize(User aggregate, [dynamic config]) {
    return jsonEncode({
      'id': aggregate.id.toString(),
      'username': aggregate.username,
      'email': aggregate.email,
      'roles': aggregate.roles,
      'createdAt': aggregate.createdAt.toIso8601String(),
      'updatedAt': aggregate.updatedAt.toIso8601String(),
    });
  }
}

void main() async {
  print('Starting self-hosted auth example...\n');

  // Create repositories
  final userRepo = InMemoryUserRepository();
  final refreshTokenRepo = InMemoryRefreshTokenRepository<RefreshToken>();
  final deviceCodeRepo = InMemoryDeviceCodeRepository<DeviceCode>(
    lifecycle: const StandardDeviceCodeLifecycle(),
  );

  // Seed test users
  await _seedUsers(userRepo);

  // Create auth handler with custom claims. This loader is the authoritative
  // source for both login and refresh, so role and profile changes are picked
  // up whenever a new access token is issued.
  final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
    secret: 'your-256-bit-secret-key-change-in-production',
    refreshTokenRepository: refreshTokenRepo,
    refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
    claimsLoader: (userId) async {
      final User user;
      try {
        user = await userRepo.getById(UuidValue.fromString(userId));
      } on RepositoryException catch (error) {
        if (error.type == RepositoryExceptionType.notFound) {
          return null;
        }
        rethrow;
      }

      return UserClaims(
        userId: user.id.toString(),
        username: user.username,
        email: user.email,
        roles: user.roles,
      );
    },
    issuer: 'https://api.example.com',
    audience: 'example-app',
    accessTokenDuration: const Duration(minutes: 15),
    refreshTokenDuration: const Duration(days: 7),
    parseClaimsFromJson: UserClaims.fromJson,
    claimsToJson: (claims) => claims.toJson(),
  );

  // Create auth endpoints
  final authEndpoints = AuthEndpoints(
    authHandler: authHandler,
    deviceCodeRepository: deviceCodeRepo,
    deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
    userValidator: (username, password) async {
      final user = await userRepo.findByUsername(username);

      if (user == null) {
        return null;
      }

      // In production, use proper password hashing (bcrypt, argon2)
      // This is simplified for the example
      if (user.passwordHash == password) {
        return user.id.toString();
      }

      return null;
    },
  );

  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register auth endpoints
  server.addRoute('POST', '/auth/login', authEndpoints.handleLogin);
  server.addRoute('POST', '/auth/refresh', authEndpoints.handleRefresh);
  server.addRoute('POST', '/auth/logout', authEndpoints.handleLogout);
  server.addRoute('POST', '/auth/device', authEndpoints.handleDeviceCode);
  server.addRoute(
      'GET', '/auth/device/verify', authEndpoints.handleDeviceVerify);
  server.addRoute('POST', '/auth/token', authEndpoints.handleToken);

  // Register protected user resource
  server.registerResource(
    CrudResource<User, UserClaims>(
      path: '/users',
      repository: userRepo,
      serializer: UserSerializer(),
      authenticationHandler: authHandler,
      queryHandlers: {
        'me': (repo, params, skip, take, authResult) async {
          // Return current user's data
          if (authResult == null) {
            throw Exception('Unauthorized');
          }
          final user = await repo.getById(
            UuidValue.fromString(authResult.claims!.userId),
          );
          return QueryResult([user], totalCount: 1);
        },
      },
    ),
  );

  // Register public health check
  server.addRoute('GET', '/health', (Request request) async {
    return Response.ok(
      jsonEncode(
          {'status': 'healthy', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  await server.start();

  print('✓ Server running on http://localhost:8080\n');
  print('Test users:');
  print('  - alice / password123 (roles: admin, user)');
  print('  - bob / password456 (roles: user)');
  print('\nTry these commands:\n');
  print('# Login');
  print('curl -X POST http://localhost:8080/auth/login \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"username":"alice","password":"password123"}\'');
  print('\n# Get current user (requires token)');
  print('curl http://localhost:8080/users?me \\');
  print('  -H "Authorization: Bearer <access_token>"');
  print('\n# Device flow');
  print('curl -X POST http://localhost:8080/auth/device \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"client_id":"my-cli-app"}\'');
  print('\nPress Ctrl+C to stop the server');
}

Future<void> _seedUsers(Repository<User> repo) async {
  final alice = User(
    id: UuidValue.generate(),
    username: 'alice',
    email: 'alice@example.com',
    passwordHash: 'password123', // In production, use proper hashing!
    roles: ['admin', 'user'],
  );

  final bob = User(
    id: UuidValue.generate(),
    username: 'bob',
    email: 'bob@example.com',
    passwordHash: 'password456',
    roles: ['user'],
  );

  await repo.save(alice);
  await repo.save(bob);
}
