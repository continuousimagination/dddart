// Example: Self-hosted authentication with in-memory storage
//
// This example demonstrates:
// - Setting up JWT authentication with custom claims
// - Creating auth endpoints (login, refresh, logout, device flow)
// - Protecting resources with authentication
// - Using in-memory repositories for quick start
//
// Run: dart run example/self_hosted_auth_example.dart
// Then test with curl or the CLI client example

import 'dart:async';
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';

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

  @override
  List<Object?> get props => [id, username, email, passwordHash, roles];
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
class UserSerializer implements Serializer<User> {
  @override
  User deserialize(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      passwordHash: json['passwordHash'] as String? ?? '',
      roles: (json['roles'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  String serialize(User aggregate) {
    return jsonEncode({
      'id': aggregate.id,
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
  final userRepo = InMemoryRepository<User>();
  final refreshTokenRepo = InMemoryRepository<RefreshToken>();
  final deviceCodeRepo = InMemoryRepository<DeviceCode>();

  // Seed test users
  await _seedUsers(userRepo);

  // Create auth handler with custom claims
  final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
    secret: 'your-256-bit-secret-key-change-in-production',
    refreshTokenRepository: refreshTokenRepo,
    issuer: 'https://api.example.com',
    audience: 'example-app',
    accessTokenDuration: const Duration(minutes: 15),
    refreshTokenDuration: const Duration(days: 7),
  );

  // Create auth endpoints
  final authEndpoints = AuthEndpoints(
    authHandler: authHandler,
    deviceCodeRepository: deviceCodeRepo,
    userValidator: (username, password) async {
      // Find user by username
      final users = await userRepo.getAll();
      final user = users.where((u) => u.username == username).firstOrNull;

      if (user == null) {
        return null;
      }

      // In production, use proper password hashing (bcrypt, argon2)
      // This is simplified for the example
      if (user.passwordHash == password) {
        return user.id;
      }

      return null;
    },
    claimsBuilder: (userId) async {
      final user = await userRepo.getById(userId);
      return UserClaims(
        userId: user.id,
        username: user.username,
        email: user.email,
        roles: user.roles,
      );
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
      serializers: {'application/json': UserSerializer()},
      authHandler: authHandler,
      queryHandlers: {
        'me': (repo, params, skip, take, authResult) async {
          // Return current user's data
          if (authResult == null) {
            throw Exception('Unauthorized');
          }
          final user = await repo.getById(authResult.claims!.userId);
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
    id: UuidValue.generate().value,
    username: 'alice',
    email: 'alice@example.com',
    passwordHash: 'password123', // In production, use proper hashing!
    roles: ['admin', 'user'],
  );

  final bob = User(
    id: UuidValue.generate().value,
    username: 'bob',
    email: 'bob@example.com',
    passwordHash: 'password456',
    roles: ['user'],
  );

  await repo.save(alice);
  await repo.save(bob);
}
