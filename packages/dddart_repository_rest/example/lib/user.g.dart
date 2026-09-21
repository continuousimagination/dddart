// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class UserJsonSerializer implements JsonSerializer<User> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  UserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(User instance, [SerializationConfig? config]) {
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
  User fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize User from null JSON',
        expectedType: 'User',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'User',
      );
    }
    try {
      return User(
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
        'Failed to deserialize User',
        expectedType: 'User',
      );
    }
  }

  @override
  String serialize(User object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize User',
        expectedType: 'User',
      );
    }
  }

  @override
  User deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'User',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'User',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    User instance, [
    SerializationConfig? config,
  ]) {
    return UserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static User decode(dynamic json, [SerializationConfig? config]) {
    return UserJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// RestRepositoryGenerator
// **************************************************************************

/// Generated REST repository for [User] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class UserRestRepository implements Repository<User> {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  UserRestRepository(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for User aggregates.
  String get _resourcePath => '/users';

  /// The JSON serializer for User aggregates.
  final _serializer = UserJsonSerializer();

  @override
  Future<User> getById(UuidValue id) async {
    try {
      final response = await _connection.client.get(
        Uri.parse('${_connection.baseUrl}$_resourcePath/${id.uuid}'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _serializer.fromJson(json);
      }

      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve User',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(User aggregate) async {
    try {
      final json = _serializer.toJson(aggregate);
      final body = jsonEncode(json);

      final response = await _connection.client.put(
        Uri.parse('${_connection.baseUrl}$_resourcePath/${aggregate.id.uuid}'),
        body: body,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to save User',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final response = await _connection.client.delete(
        Uri.parse('${_connection.baseUrl}$_resourcePath/${id.uuid}'),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }

      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to delete User',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  /// Maps status codes without exposing response bodies or provider text.
  RepositoryException _mapHttpException(int statusCode, String _) {
    switch (statusCode) {
      case 400:
      case 412:
      case 422:
        return RepositoryException(
          'Request validation failed',
          type: RepositoryExceptionType.constraint,
        );
      case 401:
        return RepositoryException(
          'Authentication required',
          type: RepositoryExceptionType.unauthorized,
        );
      case 403:
        return RepositoryException(
          'Access denied',
          type: RepositoryExceptionType.forbidden,
        );
      case 404:
        return RepositoryException(
          'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      case 409:
        return RepositoryException(
          'Resource conflict',
          type: RepositoryExceptionType.duplicate,
        );
      case 408:
      case 504:
        return RepositoryException(
          'Request timed out',
          type: RepositoryExceptionType.timeout,
        );
      case >= 500:
        return RepositoryException(
          'Remote service failed',
          type: RepositoryExceptionType.connection,
        );
      default:
        return RepositoryException(
          'Unexpected HTTP response',
          type: RepositoryExceptionType.unknown,
        );
    }
  }
}
