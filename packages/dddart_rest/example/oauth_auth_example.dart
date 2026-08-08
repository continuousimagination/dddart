// Example: OAuth/OIDC authentication with AWS Cognito
//
// This example demonstrates:
// - Setting up OAuth JWT validation with Cognito
// - Protecting resources with OAuth authentication
// - Extracting claims from Cognito JWTs
// - No auth endpoints needed (Cognito handles authentication)
//
// Prerequisites:
// - AWS Cognito User Pool configured
// - User Pool ID and Client ID
// - JWKS endpoint URL
//
// Run: dart run example/oauth_auth_example.dart
// Then test with a JWT from Cognito

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
    required this.email,
    required this.name,
    this.cognitoGroups = const [],
  });

  final String email;
  final String name;
  final List<String> cognitoGroups;

  @override
  List<Object?> get props => [id, email, name, cognitoGroups];
}

// Cognito JWT claims
// These match the structure of Cognito's JWT tokens
class CognitoClaims {
  const CognitoClaims({
    required this.sub,
    required this.email,
    this.name,
    this.cognitoGroups = const [],
    this.cognitoUsername,
  });

  final String sub; // Subject (user ID)
  final String email;
  final String? name;
  final List<String> cognitoGroups;
  final String? cognitoUsername;

  Map<String, dynamic> toJson() => {
        'sub': sub,
        'email': email,
        if (name != null) 'name': name,
        'cognito:groups': cognitoGroups,
        if (cognitoUsername != null) 'cognito:username': cognitoUsername,
      };

  factory CognitoClaims.fromJson(Map<String, dynamic> json) => CognitoClaims(
        sub: json['sub'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
        cognitoGroups:
            (json['cognito:groups'] as List?)?.cast<String>() ?? const [],
        cognitoUsername: json['cognito:username'] as String?,
      );
}

// Simple serializer for User
class UserSerializer extends ExampleJsonSerializer<User> {
  @override
  User deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return User(
      id: UuidValue.fromString(json['id'] as String),
      email: json['email'] as String,
      name: json['name'] as String,
      cognitoGroups:
          (json['cognitoGroups'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  String serialize(User aggregate, [dynamic config]) {
    return jsonEncode({
      'id': aggregate.id.toString(),
      'email': aggregate.email,
      'name': aggregate.name,
      'cognitoGroups': aggregate.cognitoGroups,
      'createdAt': aggregate.createdAt.toIso8601String(),
      'updatedAt': aggregate.updatedAt.toIso8601String(),
    });
  }
}

void main() async {
  print('Starting OAuth/Cognito auth example...\n');

  // Configuration - Replace with your Cognito details
  const userPoolId = 'us-east-1_ABC123'; // Your User Pool ID
  const region = 'us-east-1'; // Your AWS region
  const clientId = 'your-cognito-client-id'; // Your App Client ID

  final jwksUri =
      'https://cognito-idp.$region.amazonaws.com/$userPoolId/.well-known/jwks.json';
  final issuer = 'https://cognito-idp.$region.amazonaws.com/$userPoolId';

  print('Configuration:');
  print('  JWKS URI: $jwksUri');
  print('  Issuer: $issuer');
  print('  Audience: $clientId\n');

  // Create repository
  final userRepo = InMemoryRepository<User>();

  // Seed test user (in production, users would be synced from Cognito)
  await _seedUsers(userRepo);

  // Create OAuth auth handler
  final authHandler = OAuthJwtAuthHandler<CognitoClaims>(
    jwksUri: jwksUri,
    issuer: issuer,
    audience: clientId,
    cacheDuration: const Duration(hours: 24),
    parseClaimsFromJson: CognitoClaims.fromJson,
  );

  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register protected user resource
  server.registerResource(
    CrudResource<User, CognitoClaims>(
      path: '/users',
      repository: userRepo,
      serializer: UserSerializer(),
      authenticationHandler: authHandler,
      queryHandlers: {
        'me': (repo, params, skip, take, authResult) async {
          // Return current user's data based on Cognito sub
          if (authResult == null) {
            throw Exception('Unauthorized');
          }

          final cognitoSub = authResult.claims!.sub;

          // Find user by Cognito sub
          // Note: InMemoryRepository doesn't have efficient querying,
          // so we'll just check if the user exists by ID
          try {
            final user = await repo.getById(UuidValue.fromString(cognitoSub));
            return QueryResult([user], totalCount: 1);
          } catch (e) {
            // Auto-create user from Cognito claims
            final newUser = User(
              id: UuidValue.fromString(cognitoSub),
              email: authResult.claims!.email,
              name: authResult.claims!.name ?? authResult.claims!.email,
              cognitoGroups: authResult.claims!.cognitoGroups,
            );
            await repo.save(newUser);
            return QueryResult([newUser], totalCount: 1);
          }
        },
        'admins': (repo, params, skip, take, authResult) async {
          // Only allow admins to see admin list
          if (authResult == null ||
              !authResult.claims!.cognitoGroups.contains('Admins')) {
            throw Exception('Forbidden');
          }

          // For this example, return empty list
          // In production, you'd implement proper querying
          return QueryResult([], totalCount: 0);
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
  print('This server validates JWTs from AWS Cognito.');
  print('No login endpoints - users authenticate through Cognito.\n');
  print('To test:');
  print(
      '1. Get a JWT from Cognito (use AWS Amplify, Cognito SDK, or device flow)');
  print('2. Make requests with the JWT:\n');
  print('curl http://localhost:8080/users?me \\');
  print('  -H "Authorization: Bearer <cognito_jwt_token>"');
  print('\nPress Ctrl+C to stop the server');
}

Future<void> _seedUsers(Repository<User> repo) async {
  // In production, users would be synced from Cognito
  // This is just for demonstration
  final testUser = User(
    id: UuidValue.fromString('00000000-0000-0000-0000-000000000123'),
    email: 'test@example.com',
    name: 'Test User',
    cognitoGroups: ['Users', 'Admins'],
  );

  await repo.save(testUser);
}
