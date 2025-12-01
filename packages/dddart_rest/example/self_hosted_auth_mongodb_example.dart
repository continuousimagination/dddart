// Example: Self-hosted authentication with MongoDB
//
// This example demonstrates:
// - Setting up JWT authentication with MongoDB persistence
// - Extending RefreshToken and DeviceCode for MongoDB
// - Using code generation for repository implementations
// - Production-ready authentication setup
//
// Prerequisites:
// - MongoDB running locally or accessible
// - Run: dart run build_runner build (to generate repositories)
//
// Run: dart run example/self_hosted_auth_mongodb_example.dart

import 'dart:async';
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';

// NOTE: This is a conceptual example showing the structure.
// To actually run this, you would need:
// 1. Add dddart_repository_mongodb dependency
// 2. Create the extended classes with annotations
// 3. Run code generation
// 4. Connect to MongoDB

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

// Extended RefreshToken for MongoDB
// In a real implementation, you would:
// 1. Create a separate file: lib/auth_models.dart
// 2. Add these annotations:
//
// @Serializable()
// @GenerateMongoRepository()
// class AppRefreshToken extends RefreshToken {
//   AppRefreshToken({
//     required super.id,
//     required super.userId,
//     required super.token,
//     required super.expiresAt,
//     super.revoked,
//     super.deviceInfo,
//   });
// }
//
// @Serializable()
// @GenerateMongoRepository()
// class AppDeviceCode extends DeviceCode {
//   AppDeviceCode({
//     required super.id,
//     required super.deviceCode,
//     required super.userCode,
//     required super.clientId,
//     required super.expiresAt,
//     super.userId,
//     super.status,
//   });
// }
//
// part 'auth_models.g.dart';
//
// 3. Run: dart run build_runner build
// 4. This generates:
//    - AppRefreshTokenMongoRepository
//    - AppDeviceCodeMongoRepository

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
  print('Self-hosted Auth with MongoDB Example\n');
  print('This is a conceptual example showing the structure.');
  print('To run this with real MongoDB:\n');
  print('1. Add dependencies to pubspec.yaml:');
  print('   dependencies:');
  print('     dddart_repository_mongodb: ^0.9.0');
  print('     mongo_dart: ^0.9.0\n');
  print('2. Create auth_models.dart with extended classes:');
  print('   @Serializable()');
  print('   @GenerateMongoRepository()');
  print('   class AppRefreshToken extends RefreshToken { ... }\n');
  print('3. Run code generation:');
  print('   dart run build_runner build\n');
  print('4. Connect to MongoDB and create repositories:');
  print('   final db = await Db.create("mongodb://localhost:27017/myapp");');
  print('   await db.open();');
  print('   final refreshTokenRepo = AppRefreshTokenMongoRepository(db);');
  print('   final deviceCodeRepo = AppDeviceCodeMongoRepository(db);\n');
  print('5. Use the repositories with JwtAuthHandler:\n');
  print('   final authHandler = JwtAuthHandler<UserClaims, AppRefreshToken>(');
  print('     secret: "your-secret",');
  print('     refreshTokenRepository: refreshTokenRepo,');
  print('   );\n');

  // For demonstration, we'll use in-memory repositories
  print('Running with in-memory repositories for demonstration...\n');

  final userRepo = InMemoryRepository<User>();
  final refreshTokenRepo = InMemoryRepository<RefreshToken>();
  final deviceCodeRepo = InMemoryRepository<DeviceCode>();

  await _seedUsers(userRepo);

  final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
    secret: 'your-256-bit-secret-key-change-in-production',
    refreshTokenRepository: refreshTokenRepo,
    issuer: 'https://api.example.com',
    audience: 'example-app',
    accessTokenDuration: const Duration(minutes: 15),
    refreshTokenDuration: const Duration(days: 7),
  );

  final authEndpoints = AuthEndpoints(
    authHandler: authHandler,
    deviceCodeRepository: deviceCodeRepo,
    userValidator: (username, password) async {
      final users = await userRepo.getAll();
      final user = users.where((u) => u.username == username).firstOrNull;
      if (user != null && user.passwordHash == password) {
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

  final server = HttpServer(port: 8080);

  server.addRoute('POST', '/auth/login', authEndpoints.handleLogin);
  server.addRoute('POST', '/auth/refresh', authEndpoints.handleRefresh);
  server.addRoute('POST', '/auth/logout', authEndpoints.handleLogout);
  server.addRoute('POST', '/auth/device', authEndpoints.handleDeviceCode);
  server.addRoute(
      'GET', '/auth/device/verify', authEndpoints.handleDeviceVerify);
  server.addRoute('POST', '/auth/token', authEndpoints.handleToken);

  server.registerResource(
    CrudResource<User, UserClaims>(
      path: '/users',
      repository: userRepo,
      serializers: {'application/json': UserSerializer()},
      authHandler: authHandler,
    ),
  );

  await server.start();

  print('✓ Server running on http://localhost:8080');
  print('\nTest with:');
  print('curl -X POST http://localhost:8080/auth/login \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"username":"alice","password":"password123"}\'');
  print('\nPress Ctrl+C to stop');
}

Future<void> _seedUsers(Repository<User> repo) async {
  final alice = User(
    id: UuidValue.generate().value,
    username: 'alice',
    email: 'alice@example.com',
    passwordHash: 'password123',
    roles: ['admin', 'user'],
  );

  await repo.save(alice);
}
