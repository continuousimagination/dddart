import 'dart:convert';
import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Example showing how to add custom routes to HttpServer alongside CRUD endpoints.
///
/// This demonstrates:
/// - Using HttpServer for convenient CRUD resource registration
/// - Adding custom routes (health checks, metrics, custom handlers, etc.)
/// - Running everything on a single port
/// - Keeping the convenience of registerResource() while adding flexibility
///
/// Note: This example shows generic custom routes. If you want to add webhooks,
/// you can use the same pattern with WebhookResource from dddart_webhooks package.

void main() async {
  // Set up CRUD resources
  final userRepository = InMemoryRepository<User>();
  final userResource = CrudResource<User>(
    path: '/users',
    repository: userRepository,
    serializers: {'application/json': UserSerializer()},
  );

  // Create HTTP server
  final server = HttpServer(port: 8080);

  // Register CRUD resources (creates 5 routes automatically)
  server.registerResource(userResource);

  // Add custom routes
  server.addRoute('POST', '/events', _handleCustomEvent);

  // Add a health check endpoint
  server.addRoute('GET', '/health', _handleHealthCheck);

  // Start the server
  await server.start();
  print('✅ Server running on http://localhost:${server.port}');
  print('');
  print('REST CRUD endpoints:');
  print('  GET    /users       - List all users');
  print('  GET    /users/:id   - Get user by ID');
  print('  POST   /users       - Create user');
  print('  PUT    /users/:id   - Update user');
  print('  DELETE /users/:id   - Delete user');
  print('');
  print('Custom endpoints:');
  print('  POST   /events  - Custom event handler');
  print('  GET    /health  - Health check');
  print('');
  print('Press Ctrl+C to stop');

  // Keep server running
  await ProcessSignal.sigint.watch().first;
  await server.stop();
  print('Server stopped');
}

/// Example custom event handler
Future<Response> _handleCustomEvent(Request request) async {
  final body = await request.readAsString();
  print('Received event: $body');

  return Response.ok(
    jsonEncode({'status': 'received', 'message': 'Event processed'}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Health check handler
Future<Response> _handleHealthCheck(Request request) async {
  return Response.ok(
    jsonEncode(
        {'status': 'healthy', 'timestamp': DateTime.now().toIso8601String()}),
    headers: {'Content-Type': 'application/json'},
  );
}

// User aggregate root for example
class User extends AggregateRoot {
  User({required this.name, super.id, super.createdAt, super.updatedAt});
  final String name;
}

// User serializer for example
class UserSerializer implements Serializer<User> {
  @override
  String serialize(User user, [dynamic config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    });
  }

  @override
  User deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return User(
      id: UuidValue.fromString(json['id'] as String),
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
