// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class ProductJsonSerializer implements JsonSerializer<Product> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  ProductJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Product instance, [SerializationConfig? config]) {
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
        'description',
        effectiveConfig.fieldRename,
      ): instance.description,
      SerializationUtils.applyFieldRename(
        'inStock',
        effectiveConfig.fieldRename,
      ): instance.inStock,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('price', effectiveConfig.fieldRename):
          instance.price,
    };
    return json;
  }

  @override
  Product fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Product from null JSON',
        expectedType: 'Product',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Product',
      );
    }
    try {
      return Product(
        description:
            json[SerializationUtils.applyFieldRename(
                  'description',
                  effectiveConfig.fieldRename,
                )]
                as String,
        inStock:
            json[SerializationUtils.applyFieldRename(
                  'inStock',
                  effectiveConfig.fieldRename,
                )]
                as bool,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        price:
            json[SerializationUtils.applyFieldRename(
                  'price',
                  effectiveConfig.fieldRename,
                )]
                as int,
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
        'Failed to deserialize Product',
        expectedType: 'Product',
      );
    }
  }

  @override
  String serialize(Product object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Product',
        expectedType: 'Product',
      );
    }
  }

  @override
  Product deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Product',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'Product',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Product instance, [
    SerializationConfig? config,
  ]) {
    return ProductJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Product decode(dynamic json, [SerializationConfig? config]) {
    return ProductJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// MongoRepositoryGenerator
// **************************************************************************

/// Generated MongoDB repository for [Product] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class ProductMongoRepository implements Repository<Product> {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  ProductMongoRepository(this._database);

  /// The MongoDB database instance (library-private).
  final Db _database;

  /// The collection name for Product aggregates.
  String get collectionName => 'products';

  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);

  /// The JSON serializer for Product aggregates.
  final _serializer = ProductJsonSerializer();

  @override
  Future<Product> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));

      if (doc == null) {
        throw RepositoryException(
          'Product with ID $id not found',
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
        'Failed to retrieve Product with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> save(Product aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
        'Failed to save Product: $e',
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
          'Product with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete Product with ID $id: $e',
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
