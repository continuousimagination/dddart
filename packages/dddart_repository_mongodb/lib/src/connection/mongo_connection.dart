import 'package:dddart_repository_mongodb/src/exceptions/mongo_repository_exception.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Manages MongoDB database connections.
///
/// Provides connection lifecycle management and database instance access.
/// Does not manage connection pooling (handled by mongo_dart internally).
///
/// Example with individual parameters:
/// ```dart
/// final connection = MongoConnection(
///   host: 'localhost',
///   port: 27017,
///   databaseName: 'myapp',
///   username: 'user',
///   password: 'pass',
/// );
/// await connection.open();
/// final db = connection.database;
/// // Use database...
/// await connection.close();
/// ```
///
/// Example with URI:
/// ```dart
/// final connection = MongoConnection.fromUri(
///   'mongodb://user:pass@localhost:27017/myapp',
/// );
/// await connection.open();
/// ```
///
/// Example with AWS DocumentDB:
/// ```dart
/// final connection = MongoConnection(
///   host: 'docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com',
///   port: 27017,
///   databaseName: 'myapp',
///   username: 'myuser',
///   password: 'mypassword',
///   tls: true,
///   tlsAllowInvalidCertificates: true,
///   authSource: 'admin',
/// );
/// ```
class MongoConnection {
  /// Creates a connection from individual parameters.
  ///
  /// [host] - MongoDB server hostname or IP address
  /// [port] - MongoDB server port (default: 27017)
  /// [databaseName] - Name of the database to connect to
  /// [username] - Optional username for authentication
  /// [password] - Optional password for authentication
  /// [authSource] - Optional authentication database (default: admin)
  /// [tls] - Enable TLS/SSL connection (required for AWS DocumentDB)
  /// [tlsAllowInvalidCertificates] - Allow self-signed certificates
  MongoConnection({
    required this.host,
    required this.port,
    required this.databaseName,
    this.username,
    this.password,
    this.authSource,
    this.tls = false,
    this.tlsAllowInvalidCertificates = false,
  });

  /// Creates a connection from a MongoDB connection string URI.
  ///
  /// Supports standard MongoDB URIs and AWS DocumentDB connection strings.
  ///
  /// Format: `mongodb://[username:password@]host[:port]/database[?options]`
  ///
  /// Example:
  /// ```dart
  /// final connection = MongoConnection.fromUri(
  ///   'mongodb://user:pass@localhost:27017/myapp?tls=true',
  /// );
  /// ```
  factory MongoConnection.fromUri(String uri) {
    final parsedUri = Uri.parse(uri);

    if (parsedUri.scheme != 'mongodb') {
      throw ArgumentError('URI must use mongodb:// scheme');
    }

    final host = parsedUri.host;
    final port = parsedUri.port != 0 ? parsedUri.port : 27017;
    final databaseName = parsedUri.path.replaceFirst('/', '');

    if (databaseName.isEmpty) {
      throw ArgumentError('Database name must be specified in URI path');
    }

    final username =
        parsedUri.userInfo.isNotEmpty && parsedUri.userInfo.contains(':')
            ? Uri.decodeComponent(parsedUri.userInfo.split(':')[0])
            : null;

    final password =
        parsedUri.userInfo.isNotEmpty && parsedUri.userInfo.contains(':')
            ? Uri.decodeComponent(parsedUri.userInfo.split(':')[1])
            : null;

    final queryParams = parsedUri.queryParameters;
    final tls = queryParams['tls']?.toLowerCase() == 'true';
    final tlsAllowInvalidCertificates =
        queryParams['tlsAllowInvalidCertificates']?.toLowerCase() == 'true';
    final authSource = queryParams['authSource'];

    return MongoConnection(
      host: host,
      port: port,
      databaseName: databaseName,
      username: username,
      password: password,
      authSource: authSource,
      tls: tls,
      tlsAllowInvalidCertificates: tlsAllowInvalidCertificates,
    );
  }

  /// MongoDB server hostname or IP address.
  final String host;

  /// MongoDB server port.
  final int port;

  /// Name of the database to connect to.
  final String databaseName;

  /// Username for authentication (optional).
  final String? username;

  /// Password for authentication (optional).
  final String? password;

  /// Authentication database (optional, defaults to admin).
  final String? authSource;

  /// Enable TLS/SSL connection.
  final bool tls;

  /// Allow self-signed certificates (useful for AWS DocumentDB).
  final bool tlsAllowInvalidCertificates;

  Db? _db;

  /// Opens the connection to MongoDB.
  ///
  /// Must be called before accessing [database].
  /// If the connection is already open, this method returns immediately.
  ///
  /// Throws [MongoRepositoryException] if connection fails.
  Future<void> open() async {
    if (_db != null && _db!.isConnected) {
      return;
    }

    try {
      final connectionString = _buildConnectionString();
      _db = await Db.create(connectionString);
      await _db!.open();
    } catch (e, stackTrace) {
      throw MongoRepositoryException(
        'Failed to open MongoDB connection: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Closes the connection to MongoDB.
  ///
  /// After closing, [database] will throw a [StateError] until [open] is
  /// called again.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Gets the database instance.
  ///
  /// Throws [StateError] if connection is not open. Call [open] first.
  Db get database {
    if (_db == null || !_db!.isConnected) {
      throw StateError('Connection not open. Call open() first.');
    }
    return _db!;
  }

  /// Checks if the connection is currently open.
  bool get isConnected => _db != null && _db!.isConnected;

  /// Builds a MongoDB connection string from the connection parameters.
  ///
  /// Supports standard MongoDB format and AWS DocumentDB requirements.
  ///
  /// Format: `mongodb://[username:password@]host:port/database[?options]`
  String _buildConnectionString() {
    final buffer = StringBuffer('mongodb://');

    // Add credentials if provided
    if (username != null && password != null) {
      buffer
        ..write(Uri.encodeComponent(username!))
        ..write(':')
        ..write(Uri.encodeComponent(password!))
        ..write('@');
    }

    // Add host and port
    buffer
      ..write(host)
      ..write(':')
      ..write(port);

    // Add database name
    buffer
      ..write('/')
      ..write(databaseName);

    // Add query parameters
    final queryParams = <String>[];

    if (tls) {
      queryParams.add('tls=true');
    }

    if (tlsAllowInvalidCertificates) {
      queryParams.add('tlsAllowInvalidCertificates=true');
    }

    if (authSource != null) {
      queryParams.add('authSource=${Uri.encodeComponent(authSource!)}');
    }

    if (queryParams.isNotEmpty) {
      buffer
        ..write('?')
        ..write(queryParams.join('&'));
    }

    return buffer.toString();
  }
}
