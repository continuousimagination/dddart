// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_models.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class TestUserJsonSerializer implements JsonSerializer<TestUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUser instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  TestUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUser from null JSON',
        expectedType: 'TestUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    try {
      return TestUser(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestUser: $e',
        expectedType: 'TestUser',
      );
    }
  }

  @override
  String serialize(TestUser object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUser instance, [
    SerializationConfig? config,
  ]) {
    return TestUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUser decode(dynamic json, [SerializationConfig? config]) {
    return TestUserJsonSerializer().fromJson(json, config);
  }
}

class TestProductJsonSerializer implements JsonSerializer<TestProduct> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestProduct instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          instance.price,
    };
    return json;
  }

  @override
  TestProduct fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestProduct from null JSON',
        expectedType: 'TestProduct',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestProduct',
      );
    }
    try {
      return TestProduct(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        price:
            (json[SerializationUtils.applyFieldRename(
                  'price',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'price',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'price',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestProduct: $e',
        expectedType: 'TestProduct',
      );
    }
  }

  @override
  String serialize(TestProduct object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestProduct deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestProduct',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestProduct instance, [
    SerializationConfig? config,
  ]) {
    return TestProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestProduct decode(dynamic json, [SerializationConfig? config]) {
    return TestProductJsonSerializer().fromJson(json, config);
  }
}

class TestOrderJsonSerializer implements JsonSerializer<TestOrder> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestOrderJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestOrder instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'customerId',
        effectiveConfig.fieldRename,
      ): instance.customerId,
      SerializationUtils.applyFieldRename(
        'orderNumber',
        effectiveConfig.fieldRename,
      ): instance.orderNumber,
      SerializationUtils.applyFieldRename('total', effectiveConfig.fieldRename):
          instance.total,
    };
    return json;
  }

  @override
  TestOrder fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestOrder from null JSON',
        expectedType: 'TestOrder',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestOrder',
      );
    }
    try {
      return TestOrder(
        customerId:
            json[SerializationUtils.applyFieldRename(
                  'customerId',
                  effectiveConfig.fieldRename,
                )]
                as String,
        orderNumber:
            json[SerializationUtils.applyFieldRename(
                  'orderNumber',
                  effectiveConfig.fieldRename,
                )]
                as String,
        total:
            (json[SerializationUtils.applyFieldRename(
                  'total',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'total',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'total',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestOrder: $e',
        expectedType: 'TestOrder',
      );
    }
  }

  @override
  String serialize(TestOrder object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestOrder deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestOrder',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestOrder instance, [
    SerializationConfig? config,
  ]) {
    return TestOrderJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestOrder decode(dynamic json, [SerializationConfig? config]) {
    return TestOrderJsonSerializer().fromJson(json, config);
  }
}

class TestAccountJsonSerializer implements JsonSerializer<TestAccount> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestAccountJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestAccount instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'accountName',
        effectiveConfig.fieldRename,
      ): instance.accountName,
      SerializationUtils.applyFieldRename(
        'accountType',
        effectiveConfig.fieldRename,
      ): instance.accountType,
      SerializationUtils.applyFieldRename(
        'balance',
        effectiveConfig.fieldRename,
      ): instance.balance,
    };
    return json;
  }

  @override
  TestAccount fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestAccount from null JSON',
        expectedType: 'TestAccount',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestAccount',
      );
    }
    try {
      return TestAccount(
        accountName:
            json[SerializationUtils.applyFieldRename(
                  'accountName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        accountType:
            json[SerializationUtils.applyFieldRename(
                  'accountType',
                  effectiveConfig.fieldRename,
                )]
                as String,
        balance:
            (json[SerializationUtils.applyFieldRename(
                  'balance',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'balance',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'balance',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestAccount: $e',
        expectedType: 'TestAccount',
      );
    }
  }

  @override
  String serialize(TestAccount object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestAccount deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestAccount',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestAccount instance, [
    SerializationConfig? config,
  ]) {
    return TestAccountJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestAccount decode(dynamic json, [SerializationConfig? config]) {
    return TestAccountJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// MongoRepositoryGenerator
// **************************************************************************

/// Generated MongoDB repository for [TestUser] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class TestUserMongoRepository implements Repository<TestUser> {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  TestUserMongoRepository(this._database);

  /// The MongoDB database instance (library-private).
  final Db _database;

  /// The collection name for TestUser aggregates.
  String get collectionName => 'test_users';

  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);

  /// The JSON serializer for TestUser aggregates.
  final _serializer = TestUserJsonSerializer();

  @override
  Future<TestUser> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));

      if (doc == null) {
        throw RepositoryException(
          'TestUser with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }

      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');

      return _serializer.fromJson(doc);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve TestUser with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> save(TestUser aggregate) async {
    try {
      final doc = _serializer.toJson(aggregate);

      // Use aggregate's id as MongoDB _id
      doc['_id'] = doc['id'];
      doc.remove('id');

      // Upsert operation
      await _collection.replaceOne(
        where.eq('_id', aggregate.id.toString()),
        doc,
        upsert: true,
      );
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'save');
    } catch (e) {
      throw RepositoryException(
        'Failed to save TestUser: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final result = await _collection.deleteOne(
        where.eq('_id', id.toString()),
      );

      if (result.nRemoved == 0) {
        throw RepositoryException(
          'TestUser with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete TestUser with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  /// Maps MongoDB exceptions to RepositoryException types.
  RepositoryException _mapMongoException(
    MongoDartError error,
    String operation,
  ) {
    // Map specific MongoDB error codes to RepositoryExceptionType
    if (error.message?.contains('duplicate key') ?? false) {
      return RepositoryException(
        'Duplicate key error during $operation: ${error.message}',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (error.message?.contains('connection') ?? false) {
      return RepositoryException(
        'Connection error during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    if (error.message?.contains('timeout') ?? false) {
      return RepositoryException(
        'Timeout during $operation: ${error.message}',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MongoDB error during $operation: ${error.message}',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated MongoDB repository for [TestProduct] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class TestProductMongoRepository implements Repository<TestProduct> {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  TestProductMongoRepository(this._database);

  /// The MongoDB database instance (library-private).
  final Db _database;

  /// The collection name for TestProduct aggregates.
  String get collectionName => 'custom_products';

  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);

  /// The JSON serializer for TestProduct aggregates.
  final _serializer = TestProductJsonSerializer();

  @override
  Future<TestProduct> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));

      if (doc == null) {
        throw RepositoryException(
          'TestProduct with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }

      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');

      return _serializer.fromJson(doc);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve TestProduct with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> save(TestProduct aggregate) async {
    try {
      final doc = _serializer.toJson(aggregate);

      // Use aggregate's id as MongoDB _id
      doc['_id'] = doc['id'];
      doc.remove('id');

      // Upsert operation
      await _collection.replaceOne(
        where.eq('_id', aggregate.id.toString()),
        doc,
        upsert: true,
      );
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'save');
    } catch (e) {
      throw RepositoryException(
        'Failed to save TestProduct: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final result = await _collection.deleteOne(
        where.eq('_id', id.toString()),
      );

      if (result.nRemoved == 0) {
        throw RepositoryException(
          'TestProduct with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete TestProduct with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  /// Maps MongoDB exceptions to RepositoryException types.
  RepositoryException _mapMongoException(
    MongoDartError error,
    String operation,
  ) {
    // Map specific MongoDB error codes to RepositoryExceptionType
    if (error.message?.contains('duplicate key') ?? false) {
      return RepositoryException(
        'Duplicate key error during $operation: ${error.message}',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (error.message?.contains('connection') ?? false) {
      return RepositoryException(
        'Connection error during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    if (error.message?.contains('timeout') ?? false) {
      return RepositoryException(
        'Timeout during $operation: ${error.message}',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MongoDB error during $operation: ${error.message}',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}

/// Generated abstract base MongoDB repository for [TestOrder] aggregate.
///
/// This abstract class implements the base Repository<TestOrder> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class TestOrderMongoRepositoryBase implements TestOrderRepository {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  TestOrderMongoRepositoryBase(this._database);

  /// The MongoDB database instance (library-private).
  final Db _database;

  /// The collection name for TestOrder aggregates.
  String get collectionName => 'test_orders';

  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);

  /// The JSON serializer for TestOrder aggregates.
  final _serializer = TestOrderJsonSerializer();

  @override
  Future<TestOrder> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));

      if (doc == null) {
        throw RepositoryException(
          'TestOrder with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }

      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');

      return _serializer.fromJson(doc);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve TestOrder with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> save(TestOrder aggregate) async {
    try {
      final doc = _serializer.toJson(aggregate);

      // Use aggregate's id as MongoDB _id
      doc['_id'] = doc['id'];
      doc.remove('id');

      // Upsert operation
      await _collection.replaceOne(
        where.eq('_id', aggregate.id.toString()),
        doc,
        upsert: true,
      );
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'save');
    } catch (e) {
      throw RepositoryException(
        'Failed to save TestOrder: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final result = await _collection.deleteOne(
        where.eq('_id', id.toString()),
      );

      if (result.nRemoved == 0) {
        throw RepositoryException(
          'TestOrder with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete TestOrder with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  /// Maps MongoDB exceptions to RepositoryException types.
  RepositoryException _mapMongoException(
    MongoDartError error,
    String operation,
  ) {
    // Map specific MongoDB error codes to RepositoryExceptionType
    if (error.message?.contains('duplicate key') ?? false) {
      return RepositoryException(
        'Duplicate key error during $operation: ${error.message}',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (error.message?.contains('connection') ?? false) {
      return RepositoryException(
        'Connection error during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    if (error.message?.contains('timeout') ?? false) {
      return RepositoryException(
        'Timeout during $operation: ${error.message}',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MongoDB error during $operation: ${error.message}',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }

  // Custom methods (must be implemented by subclass)

  @override
  Future<List<TestOrder>> findByCustomerId(String customerId);

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber);
}

/// Generated MongoDB repository for [TestAccount] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class TestAccountMongoRepository implements Repository<TestAccount> {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  TestAccountMongoRepository(this._database);

  /// The MongoDB database instance (library-private).
  final Db _database;

  /// The collection name for TestAccount aggregates.
  String get collectionName => 'test_accounts';

  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);

  /// The JSON serializer for TestAccount aggregates.
  final _serializer = TestAccountJsonSerializer();

  @override
  Future<TestAccount> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));

      if (doc == null) {
        throw RepositoryException(
          'TestAccount with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }

      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');

      return _serializer.fromJson(doc);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve TestAccount with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> save(TestAccount aggregate) async {
    try {
      final doc = _serializer.toJson(aggregate);

      // Use aggregate's id as MongoDB _id
      doc['_id'] = doc['id'];
      doc.remove('id');

      // Upsert operation
      await _collection.replaceOne(
        where.eq('_id', aggregate.id.toString()),
        doc,
        upsert: true,
      );
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'save');
    } catch (e) {
      throw RepositoryException(
        'Failed to save TestAccount: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final result = await _collection.deleteOne(
        where.eq('_id', id.toString()),
      );

      if (result.nRemoved == 0) {
        throw RepositoryException(
          'TestAccount with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete TestAccount with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  /// Maps MongoDB exceptions to RepositoryException types.
  RepositoryException _mapMongoException(
    MongoDartError error,
    String operation,
  ) {
    // Map specific MongoDB error codes to RepositoryExceptionType
    if (error.message?.contains('duplicate key') ?? false) {
      return RepositoryException(
        'Duplicate key error during $operation: ${error.message}',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (error.message?.contains('connection') ?? false) {
      return RepositoryException(
        'Connection error during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    if (error.message?.contains('timeout') ?? false) {
      return RepositoryException(
        'Timeout during $operation: ${error.message}',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MongoDB error during $operation: ${error.message}',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}
