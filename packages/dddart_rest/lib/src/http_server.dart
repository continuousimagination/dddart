import 'dart:io' as io;

import 'package:dddart_rest/src/crud_resource.dart';
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

  /// List of registered CrudResource instances
  final List<CrudResource> _resources = [];

  /// The underlying shelf HttpServer instance
  io.HttpServer? _shelfServer;

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

    // Start shelf server with router on configured port
    _shelfServer = await shelf_io.serve(
      router.call,
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
}
