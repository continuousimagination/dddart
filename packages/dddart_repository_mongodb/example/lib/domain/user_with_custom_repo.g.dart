// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_with_custom_repo.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class UserWithCustomRepoJsonSerializer
    implements JsonSerializer<UserWithCustomRepo> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  UserWithCustomRepoJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    UserWithCustomRepo instance, [
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
      SerializationUtils.applyFieldRename(
        'firstName',
        effectiveConfig.fieldRename,
      ): instance.firstName,
      SerializationUtils.applyFieldRename(
        'lastName',
        effectiveConfig.fieldRename,
      ): instance.lastName,
    };
    return json;
  }

  @override
  UserWithCustomRepo fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize UserWithCustomRepo from null JSON',
        expectedType: 'UserWithCustomRepo',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'UserWithCustomRepo',
      );
    }
    try {
      return UserWithCustomRepo(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        firstName:
            json[SerializationUtils.applyFieldRename(
                  'firstName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        lastName:
            json[SerializationUtils.applyFieldRename(
                  'lastName',
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
        'Failed to deserialize UserWithCustomRepo',
        expectedType: 'UserWithCustomRepo',
      );
    }
  }

  @override
  String serialize(UserWithCustomRepo object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize UserWithCustomRepo',
        expectedType: 'UserWithCustomRepo',
      );
    }
  }

  @override
  UserWithCustomRepo deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'UserWithCustomRepo',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'UserWithCustomRepo',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    UserWithCustomRepo instance, [
    SerializationConfig? config,
  ]) {
    return UserWithCustomRepoJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static UserWithCustomRepo decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return UserWithCustomRepoJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// MongoRepositoryGenerator
// **************************************************************************

/// Generated abstract base MongoDB repository for [UserWithCustomRepo] aggregate.
///
/// This abstract class implements the base Repository<UserWithCustomRepo> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class UserWithCustomRepoMongoRepositoryBase implements UserRepository {
  /// Creates a repository instance.
  ///
  /// [database] - An open MongoDB database connection.
  UserWithCustomRepoMongoRepositoryBase(this._database);

  /// The MongoDB database instance (library-private).
  final Db _database;

  /// The collection name for UserWithCustomRepo aggregates.
  String get collectionName => 'users';

  /// Gets the MongoDB collection for this aggregate type.
  DbCollection get _collection => _database.collection(collectionName);

  /// The JSON serializer for UserWithCustomRepo aggregates.
  final _serializer = UserWithCustomRepoJsonSerializer();

  @override
  Future<UserWithCustomRepo> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));

      if (doc == null) {
        throw RepositoryException(
          'UserWithCustomRepo with ID $id not found',
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
        'Failed to retrieve UserWithCustomRepo with ID $id: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<void> save(UserWithCustomRepo aggregate) async {
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
        'Failed to save UserWithCustomRepo: $e',
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
          'UserWithCustomRepo with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete UserWithCustomRepo with ID $id: $e',
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
  Future<UserWithCustomRepo?> findByEmail(String email);

  @override
  Future<List<UserWithCustomRepo>> findByLastName(String lastName);
}
