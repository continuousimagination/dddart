import 'dart:io' as io;

import 'package:dddart_rest/src/crud_resource.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Manages the shelf HTTP server lifecycle and route registration.
///
/// HttpServer allows registering multiple CrudResource instances and
/// automatically creates routes for all CRUD operations. It handles
/// starting and stopping the underlying shelf server.
///
/// Example:
/// ```dart
/// final server = HttpServer(port: 8080);
/// server.registerResource(userResource);
/// server.registerResource(productResource);
/// await server.start();
/// ```
class HttpServer {
  /// Creates an HttpServer with the specified port
  ///
  /// Parameters:
  /// - [port]: The port to bind the server to (defaults to 8080)
  HttpServer({this.port = 8080});

  /// The port the server will bind to
  final int port;

  /// Origins allowed for CORS requests.
  ///
  /// If empty, no CORS headers are added. Use [allowOrigins] to configure.
  final Set<String> _allowedOrigins = {};

  /// List of registered CrudResource instances
  final List<CrudResource> _resources = [];

  /// List of custom route handlers
  final List<_CustomRoute> _customRoutes = [];

  /// The underlying shelf HttpServer instance
  io.HttpServer? _shelfServer;

  /// Configures allowed origins for CORS requests.
  ///
  /// Pass `['*']` to allow all origins, or specify exact origins like
  /// `['http://localhost:3000', 'https://example.com']`.
  ///
  /// Must be called before [start].
  ///
  /// Example:
  /// ```dart
  /// server.allowOrigins(['http://localhost:3000']);
  /// await server.start();
  /// ```
  void allowOrigins(List<String> origins) {
    _allowedOrigins.addAll(origins);
  }

  /// Registers a CRUD resource with the server
  ///
  /// The resource will be available once the server is started.
  /// Routes are automatically created for all CRUD operations.
  ///
  /// Parameters:
  /// - [resource]: The CrudResource instance to register
  ///
  /// Example:
  /// ```dart
  /// server.registerResource(CrudResource<User>(
  ///   path: '/users',
  ///   repository: userRepository,
  ///   serializers: {'application/json': jsonSerializer},
  /// ));
  /// ```
  void registerResource(CrudResource resource) {
    _resources.add(resource);
  }

  /// Registers a custom route handler with the server
  ///
  /// This allows you to add non-CRUD routes (like webhooks) to the same
  /// server instance. The handler will be registered when the server starts.
  ///
  /// Parameters:
  /// - [method]: HTTP method (GET, POST, PUT, DELETE, etc.)
  /// - [path]: The route path (e.g., '/webhooks/slack')
  /// - [handler]: The request handler function
  ///
  /// Example:
  /// ```dart
  /// // Add a webhook endpoint
  /// final webhook = WebhookResource<MyPayload, MyVerification>(...);
  /// server.addRoute('POST', '/webhooks/events', webhook.handleRequest);
  ///
  /// // Add a health check endpoint
  /// server.addRoute('GET', '/health', (request) async {
  ///   return Response.ok('OK');
  /// });
  /// ```
  void addRoute(
    String method,
    String path,
    Function handler,
  ) {
    _customRoutes.add(_CustomRoute(method, path, handler));
  }

  /// Starts the HTTP server
  ///
  /// Creates a shelf_router Router instance and registers routes for all
  /// registered CrudResource instances. Then starts the shelf server on
  /// the configured port.
  ///
  /// Throws [StateError] if the server is already running.
  ///
  /// Example:
  /// ```dart
  /// await server.start();
  /// print('Server running on http://localhost:${server.port}');
  /// ```
  Future<void> start() async {
    if (_shelfServer != null) {
      throw StateError('Server is already running');
    }

    final router = Router();

    // Register routes for each resource
    for (final resource in _resources) {
      // GET /{path}/:id → resource.handleGetById
      router.get('${resource.path}/<id>', resource.handleGetById);

      // GET /{path} → resource.handleQuery
      router.get(resource.path, resource.handleQuery);

      // POST /{path} → resource.handleCreate
      router.post(resource.path, resource.handleCreate);

      // PUT /{path}/:id → resource.handleUpdate
      router.put('${resource.path}/<id>', resource.handleUpdate);

      // DELETE /{path}/:id → resource.handleDelete
      router.delete('${resource.path}/<id>', resource.handleDelete);
    }

    // Register custom routes
    for (final route in _customRoutes) {
      switch (route.method.toUpperCase()) {
        case 'GET':
          router.get(route.path, route.handler);
        case 'POST':
          router.post(route.path, route.handler);
        case 'PUT':
          router.put(route.path, route.handler);
        case 'DELETE':
          router.delete(route.path, route.handler);
        case 'PATCH':
          router.patch(route.path, route.handler);
        case 'HEAD':
          router.head(route.path, route.handler);
        case 'OPTIONS':
          router.options(route.path, route.handler);
        default:
          throw ArgumentError('Unsupported HTTP method: ${route.method}');
      }
    }

    // Build handler with CORS middleware if allowed origins configured.
    Handler handler = router.call;
    if (_allowedOrigins.isNotEmpty) {
      handler = _corsMiddleware().addHandler(handler);
    }

    // Start shelf server with router on configured port
    _shelfServer = await shelf_io.serve(
      handler,
      io.InternetAddress.anyIPv4,
      port,
      shared: true,
    );
  }

  /// Stops the HTTP server
  ///
  /// Closes the underlying shelf server and cleans up resources.
  ///
  /// Throws [StateError] if the server is not running.
  ///
  /// Example:
  /// ```dart
  /// await server.stop();
  /// print('Server stopped');
  /// ```
  Future<void> stop() async {
    if (_shelfServer == null) {
      throw StateError('Server is not running');
    }

    await _shelfServer!.close(force: true);
    _shelfServer = null;
  }

  /// Creates a CORS middleware that handles preflight requests and adds
  /// the appropriate headers to all responses.
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final origin = request.headers['origin'];

        // Determine if the origin is allowed
        final isAllowed = _allowedOrigins.contains('*') ||
            (origin != null && _allowedOrigins.contains(origin));

        final corsHeaders = <String, String>{
          if (isAllowed && origin != null)
            'Access-Control-Allow-Origin': origin,
          if (_allowedOrigins.contains('*')) 'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods':
              'GET, POST, PUT, DELETE, PATCH, OPTIONS',
          'Access-Control-Allow-Headers':
              'Origin, Content-Type, Accept, Authorization',
          'Access-Control-Max-Age': '86400',
        };

        // Handle preflight requests
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: corsHeaders);
        }

        // Forward to inner handler and add CORS headers to response
        final response = await innerHandler(request);
        return response.change(headers: corsHeaders);
      };
    };
  }
}

/// Internal class to store custom route information
class _CustomRoute {
  _CustomRoute(this.method, this.path, this.handler);

  final String method;
  final String path;
  final Function handler;
}
