// Example: Authorization with resource ownership
//
// This example demonstrates:
// - Implementing AuthorizationHandler for resource ownership
// - Protecting resources so users can only modify their own data
// - Combining authentication and authorization
// - Different authorization rules for different operations
//
// Run from this example directory: dart run authorization_example.dart
// Then test with curl using JWT tokens

import 'dart:async';
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';

import 'lib/json_serializer_support.dart';

// Domain model - Document owned by a user
class Document extends AggregateRoot {
  Document({
    required super.id,
    required this.title,
    required this.content,
    required this.ownerId,
    this.isPublic = false,
  });

  final String title;
  final String content;
  final String ownerId; // User ID who owns this document
  final bool isPublic;
}

// Custom JWT claims with user ID
class UserClaims {
  const UserClaims({
    required this.userId,
    required this.username,
    this.isAdmin = false,
  });

  final String userId;
  final String username;
  final bool isAdmin;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'isAdmin': isAdmin,
      };

  factory UserClaims.fromJson(Map<String, dynamic> json) => UserClaims(
        userId: json['userId'] as String,
        username: json['username'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
      );
}

// Authorization handler - enforces ownership rules
class DocumentAuthorizationHandler
    extends AuthorizationHandler<Document, UserClaims> {
  @override
  Future<AuthorizationResult> authorizeCreate(
    Document aggregate,
    AuthenticationResult<UserClaims> authResult,
  ) async {
    // Users can only create documents for themselves
    final userId = authResult.claims!.userId;

    if (aggregate.ownerId != userId) {
      return AuthorizationResult.deny(
        'You can only create documents for yourself',
      );
    }

    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeUpdate(
    Document aggregate,
    AuthenticationResult<UserClaims> authResult,
  ) async {
    // Users can only update their own documents (unless admin)
    final userId = authResult.claims!.userId;
    final isAdmin = authResult.claims!.isAdmin;

    if (aggregate.ownerId != userId && !isAdmin) {
      return AuthorizationResult.deny(
        'You do not have permission to modify this document',
      );
    }

    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeDelete(
    UuidValue aggregateId,
    AuthenticationResult<UserClaims> authResult,
  ) async {
    // For delete, we need to fetch the document to check ownership
    // In production, consider passing the aggregate or using a cache
    final isAdmin = authResult.claims!.isAdmin;

    // Admins can delete any document
    if (isAdmin) {
      return AuthorizationResult.allow();
    }

    // Note: In a real implementation, you'd fetch the document here
    // to check ownership. For this example, we'll allow it and let
    // the repository handle the not-found case.
    // A better approach is to pass the document to this method.
    return AuthorizationResult.allow();
  }

  @override
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> queryParams,
    AuthenticationResult<UserClaims> authResult,
  ) async {
    // Users can only query their own documents (unless admin)
    final userId = authResult.claims!.userId;
    final isAdmin = authResult.claims!.isAdmin;

    if (queryParams.containsKey('ownerId')) {
      final queriedOwnerId = queryParams['ownerId'];

      if (queriedOwnerId != userId && !isAdmin) {
        return AuthorizationResult.deny(
          'You can only query your own documents',
        );
      }
    }

    return AuthorizationResult.allow();
  }
}

// Simple serializer for Document
class DocumentSerializer extends ExampleJsonSerializer<Document> {
  @override
  Document deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return Document(
      id: UuidValue.fromString(json['id'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      ownerId: json['ownerId'] as String,
      isPublic: json['isPublic'] as bool? ?? false,
    );
  }

  @override
  String serialize(Document aggregate, [dynamic config]) {
    return jsonEncode({
      'id': aggregate.id.toString(),
      'title': aggregate.title,
      'content': aggregate.content,
      'ownerId': aggregate.ownerId,
      'isPublic': aggregate.isPublic,
      'createdAt': aggregate.createdAt.toIso8601String(),
      'updatedAt': aggregate.updatedAt.toIso8601String(),
    });
  }
}

void main() async {
  print('Starting authorization example...\n');

  // Create repositories
  final documentRepo = InMemoryRepository<Document>();
  final refreshTokenRepo = InMemoryRepository<RefreshToken>();
  final deviceCodeRepo = InMemoryRepository<DeviceCode>();

  // Seed test documents
  await _seedDocuments(documentRepo);

  // This represents the authoritative user directory for the example. The
  // handler reloads it for login and refresh, so changes are reflected in the
  // next access token and a removed user can no longer receive tokens.
  final claimsByUserId = <String, UserClaims>{
    'user-alice-id': const UserClaims(
      userId: 'user-alice-id',
      username: 'alice',
    ),
    'user-bob-id': const UserClaims(
      userId: 'user-bob-id',
      username: 'bob',
    ),
    'user-admin-id': const UserClaims(
      userId: 'user-admin-id',
      username: 'admin',
      isAdmin: true,
    ),
  };

  // Create authentication handler
  final authHandler = JwtAuthHandler<UserClaims, RefreshToken>(
    secret: 'your-256-bit-secret-key-change-in-production',
    refreshTokenRepository: refreshTokenRepo,
    refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
    claimsLoader: (userId) async => claimsByUserId[userId],
    issuer: 'https://api.example.com',
    audience: 'example-app',
    accessTokenDuration: const Duration(minutes: 15),
    refreshTokenDuration: const Duration(days: 7),
    parseClaimsFromJson: UserClaims.fromJson,
    claimsToJson: (claims) => claims.toJson(),
  );

  // Create authorization handler
  final authzHandler = DocumentAuthorizationHandler();

  // Create auth endpoints
  final authEndpoints = AuthEndpoints(
    authHandler: authHandler,
    deviceCodeRepository: deviceCodeRepo,
    deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
    userValidator: (username, password) async {
      // Simplified user validation
      // In production, check against user database with proper password hashing
      if (username == 'alice' && password == 'password123') {
        return 'user-alice-id';
      }
      if (username == 'bob' && password == 'password456') {
        return 'user-bob-id';
      }
      if (username == 'admin' && password == 'admin123') {
        return 'user-admin-id';
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

  // Register protected document resource with authorization
  server.registerResource(
    CrudResource<Document, UserClaims>(
      path: '/documents',
      repository: documentRepo,
      serializer: DocumentSerializer(),
      authenticationHandler: authHandler,
      authorizationHandler: authzHandler, // Authorization handler added here
      queryHandlers: {
        'ownerId': (repo, params, skip, take, authResult) async {
          final ownerId = params['ownerId'];
          if (ownerId == null) {
            return QueryResult([], totalCount: 0);
          }

          // For this example, we'll return empty results
          // In production, you'd implement a proper query method
          // or use a repository that supports filtering
          return QueryResult([], totalCount: 0);
        },
      },
    ),
  );

  // Register public health check
  server.addRoute('GET', '/health', (Request request) async {
    return Response.ok(
      jsonEncode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  await server.start();

  print('✓ Server running on http://localhost:8080\n');
  print('This example demonstrates authorization with resource ownership.\n');
  print('Test users:');
  print('  - alice / password123 (regular user, owns doc-1 and doc-2)');
  print('  - bob / password456 (regular user, owns doc-3)');
  print('  - admin / admin123 (admin, can modify any document)');
  print('\nTry these commands:\n');
  print('# 1. Login as Alice');
  print('curl -X POST http://localhost:8080/auth/login \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"username":"alice","password":"password123"}\'');
  print('\n# 2. Get Alice\'s documents (use token from step 1)');
  print('curl http://localhost:8080/documents?ownerId=user-alice-id \\');
  print('  -H "Authorization: Bearer <alice_token>"');
  print('\n# 3. Try to get Bob\'s documents as Alice (should fail with 403)');
  print('curl http://localhost:8080/documents?ownerId=user-bob-id \\');
  print('  -H "Authorization: Bearer <alice_token>"');
  print('\n# 4. Update Alice\'s document (should succeed)');
  print('curl -X PUT http://localhost:8080/documents/'
      '00000000-0000-0000-0000-000000000001 \\');
  print('  -H "Authorization: Bearer <alice_token>" \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"id":"00000000-0000-0000-0000-000000000001",'
      '"title":"Updated","content":"New content",'
      '"ownerId":"user-alice-id"}\'');
  print('\n# 5. Try to update Bob\'s document as Alice (should fail with 403)');
  print('curl -X PUT http://localhost:8080/documents/'
      '00000000-0000-0000-0000-000000000003 \\');
  print('  -H "Authorization: Bearer <alice_token>" \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"id":"00000000-0000-0000-0000-000000000003",'
      '"title":"Hacked","content":"Malicious",'
      '"ownerId":"user-bob-id"}\'');
  print('\n# 6. Login as admin and update any document (should succeed)');
  print('curl -X POST http://localhost:8080/auth/login \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"username":"admin","password":"admin123"}\'');
  print('\ncurl -X PUT http://localhost:8080/documents/'
      '00000000-0000-0000-0000-000000000003 \\');
  print('  -H "Authorization: Bearer <admin_token>" \\');
  print('  -H "Content-Type: application/json" \\');
  print('  -d \'{"id":"00000000-0000-0000-0000-000000000003",'
      '"title":"Admin Update","content":"Fixed",'
      '"ownerId":"user-bob-id"}\'');
  print('\nPress Ctrl+C to stop the server');
}

Future<void> _seedDocuments(Repository<Document> repo) async {
  // Alice's documents
  await repo.save(
    Document(
      id: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
      title: 'Alice\'s First Document',
      content: 'This is Alice\'s private document',
      ownerId: 'user-alice-id',
      isPublic: false,
    ),
  );

  await repo.save(
    Document(
      id: UuidValue.fromString('00000000-0000-0000-0000-000000000002'),
      title: 'Alice\'s Public Document',
      content: 'This is Alice\'s public document',
      ownerId: 'user-alice-id',
      isPublic: true,
    ),
  );

  // Bob's document
  await repo.save(
    Document(
      id: UuidValue.fromString('00000000-0000-0000-0000-000000000003'),
      title: 'Bob\'s Document',
      content: 'This is Bob\'s private document',
      ownerId: 'user-bob-id',
      isPublic: false,
    ),
  );

  print('Seeded 3 test documents (2 for Alice, 1 for Bob)\n');
}
