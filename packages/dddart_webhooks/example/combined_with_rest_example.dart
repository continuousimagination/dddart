/// Example showing how to combine webhooks with REST CRUD endpoints
/// from dddart_rest package on a single HTTP server.
///
/// This demonstrates the integration pattern between dddart_webhooks
/// and dddart_rest packages.
///
/// ## Integration Pattern
///
/// When you want both REST CRUD endpoints and webhooks on the same server:
///
/// ```dart
/// import 'package:dddart_rest/dddart_rest.dart';
/// import 'package:dddart_webhooks/dddart_webhooks.dart';
///
/// void main() async {
///   // Create HTTP server
///   final server = HttpServer(port: 8080);
///
///   // Register CRUD resources (creates 5 routes each)
///   server.registerResource(userResource);
///   server.registerResource(productResource);
///
///   // Create webhook
///   final webhook = WebhookResource<EventPayload, MyVerification>(
///     path: '/webhooks/events',
///     verifier: MyWebhookVerifier(secret: 'secret'),
///     deserializer: (body) => EventPayload.fromJson(jsonDecode(body)),
///     handler: (payload, verification) async {
///       // Handle webhook
///       return Response.ok('Processed');
///     },
///   );
///
///   // Add webhook to the same server
///   server.addRoute('POST', webhook.path, webhook.handleRequest);
///
///   // Start single server with both REST and webhooks
///   await server.start();
/// }
/// ```
///
/// ## Benefits
///
/// - Single server instance (one port)
/// - Convenient CRUD registration with registerResource()
/// - Flexible webhook handling with WebhookResource
/// - No circular dependencies between packages
///
/// ## See Also
///
/// - packages/dddart_rest/example/custom_routes_example.dart
/// - packages/dddart_webhooks/example/form_encoded_example.dart

void main() {
  print('═══════════════════════════════════════════════════════════');
  print('  Combining dddart_webhooks with dddart_rest');
  print('═══════════════════════════════════════════════════════════');
  print('');
  print('This example shows the integration pattern.');
  print('');
  print('STEP 1: Add both packages to pubspec.yaml');
  print('────────────────────────────────────────────');
  print('dependencies:');
  print('  dddart_rest: ^0.9.0');
  print('  dddart_webhooks: ^0.9.0');
  print('');
  print('STEP 2: Create HttpServer and register CRUD resources');
  print('────────────────────────────────────────────');
  print('final server = HttpServer(port: 8080);');
  print('server.registerResource(userResource);');
  print('server.registerResource(productResource);');
  print('');
  print('STEP 3: Create WebhookResource');
  print('────────────────────────────────────────────');
  print('final webhook = WebhookResource<MyPayload, MyVerification>(');
  print('  path: "/webhooks/events",');
  print('  verifier: MyWebhookVerifier(secret: "secret"),');
  print('  deserializer: (body) => MyPayload.fromJson(jsonDecode(body)),');
  print('  handler: (payload, verification) async {');
  print('    // Process webhook');
  print('    return Response.ok("Processed");');
  print('  },');
  print(');');
  print('');
  print('STEP 4: Add webhook to the same server');
  print('────────────────────────────────────────────');
  print('server.addRoute("POST", webhook.path, webhook.handleRequest);');
  print('');
  print('STEP 5: Start the server');
  print('────────────────────────────────────────────');
  print('await server.start();');
  print('');
  print('RESULT: Single server with both REST and webhooks!');
  print('────────────────────────────────────────────');
  print('REST endpoints:');
  print('  GET    /users       - List users');
  print('  GET    /users/:id   - Get user');
  print('  POST   /users       - Create user');
  print('  PUT    /users/:id   - Update user');
  print('  DELETE /users/:id   - Delete user');
  print('  (same for /products)');
  print('');
  print('Webhook endpoints:');
  print('  POST   /webhooks/events - Process webhooks');
  print('');
  print('═══════════════════════════════════════════════════════════');
  print('');
  print('For working examples, see:');
  print('  • packages/dddart_rest/example/custom_routes_example.dart');
  print('  • packages/dddart_webhooks/example/form_encoded_example.dart');
}
