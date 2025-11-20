/// Test helpers and utilities for MongoDB repository testing.
library;

import 'package:mongo_dart/mongo_dart.dart';

/// Helper class for managing test MongoDB connections.
///
/// Provides utilities for setting up and tearing down test database
/// connections and collections.
class TestMongoHelper {
  /// Creates a test MongoDB helper.
  TestMongoHelper({
    this.host = 'localhost',
    this.port = 27017,
    this.databaseName = 'test_dddart_mongodb',
  });

  /// MongoDB host.
  final String host;

  /// MongoDB port.
  final int port;

  /// Test database name.
  final String databaseName;

  Db? _db;

  /// Opens a connection to the test database.
  ///
  /// Returns the database instance for use in tests.
  Future<Db> connect() async {
    if (_db != null && _db!.isConnected) {
      return _db!;
    }

    final connectionString = 'mongodb://$host:$port/$databaseName';
    _db = await Db.create(connectionString);
    await _db!.open();
    return _db!;
  }

  /// Closes the connection to the test database.
  Future<void> disconnect() async {
    await _db?.close();
    _db = null;
  }

  /// Gets the database instance.
  ///
  /// Throws [StateError] if not connected.
  Db get database {
    if (_db == null || !_db!.isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _db!;
  }

  /// Checks if connected to the database.
  bool get isConnected => _db != null && _db!.isConnected;

  /// Clears all documents from a collection.
  ///
  /// Useful for cleaning up between tests.
  Future<void> clearCollection(String collectionName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    await _db!.collection(collectionName).deleteMany({});
  }

  /// Drops a collection entirely.
  ///
  /// Useful for complete cleanup.
  Future<void> dropCollection(String collectionName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    await _db!.collection(collectionName).drop();
  }

  /// Drops the entire test database.
  ///
  /// Use with caution - this removes all data.
  Future<void> dropDatabase() async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    await _db!.drop();
  }

  /// Gets a collection from the test database.
  DbCollection collection(String name) {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _db!.collection(name);
  }

  /// Inserts a document directly into a collection.
  ///
  /// Useful for setting up test data.
  Future<void> insertDocument(
    String collectionName,
    Map<String, dynamic> document,
  ) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    await _db!.collection(collectionName).insertOne(document);
  }

  /// Finds a document by ID.
  ///
  /// Useful for verifying test results.
  Future<Map<String, dynamic>?> findDocumentById(
    String collectionName,
    String id,
  ) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _db!.collection(collectionName).findOne(where.eq('_id', id));
  }

  /// Counts documents in a collection.
  Future<int> countDocuments(String collectionName) async {
    if (!isConnected) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _db!.collection(collectionName).count();
  }
}

/// Creates a test MongoDB helper with default settings.
TestMongoHelper createTestHelper() {
  return TestMongoHelper();
}

/// Runs a test with a MongoDB connection.
///
/// Automatically connects before the test and disconnects after.
/// Optionally clears specified collections before running the test.
Future<void> withMongoConnection(
  Future<void> Function(Db db) testFn, {
  List<String> clearCollections = const [],
}) async {
  final helper = createTestHelper();
  try {
    final db = await helper.connect();

    // Clear specified collections
    for (final collection in clearCollections) {
      await helper.clearCollection(collection);
    }

    await testFn(db);
  } finally {
    await helper.disconnect();
  }
}
