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
        'Failed to deserialize TestUser',
        expectedType: 'TestUser',
      );
    }
  }

  @override
  String serialize(TestUser object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestUser',
        expectedType: 'TestUser',
      );
    }
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestUser',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestUser',
      );
    }
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
        'Failed to deserialize TestProduct',
        expectedType: 'TestProduct',
      );
    }
  }

  @override
  String serialize(TestProduct object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestProduct',
        expectedType: 'TestProduct',
      );
    }
  }

  @override
  TestProduct deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestProduct',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestProduct',
      );
    }
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
        'Failed to deserialize TestOrder',
        expectedType: 'TestOrder',
      );
    }
  }

  @override
  String serialize(TestOrder object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestOrder',
        expectedType: 'TestOrder',
      );
    }
  }

  @override
  TestOrder deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestOrder',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestOrder',
      );
    }
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
        'Failed to deserialize TestAccount',
        expectedType: 'TestAccount',
      );
    }
  }

  @override
  String serialize(TestAccount object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize TestAccount',
        expectedType: 'TestAccount',
      );
    }
  }

  @override
  TestAccount deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'TestAccount',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'TestAccount',
      );
    }
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
// RestRepositoryGenerator
// **************************************************************************

/// Generated REST repository for [TestUser] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class TestUserRestRepository implements Repository<TestUser> {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  TestUserRestRepository(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for TestUser aggregates.
  String get _resourcePath => '/users';

  /// The JSON serializer for TestUser aggregates.
  final _serializer = TestUserJsonSerializer();

  @override
  Future<TestUser> getById(UuidValue id) async {
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
        'Failed to retrieve TestUser',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(TestUser aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
        'Failed to save TestUser',
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
        'Failed to delete TestUser',
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

/// Generated REST repository for [TestProduct] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class TestProductRestRepository implements Repository<TestProduct> {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  TestProductRestRepository(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for TestProduct aggregates.
  String get _resourcePath => '/products';

  /// The JSON serializer for TestProduct aggregates.
  final _serializer = TestProductJsonSerializer();

  @override
  Future<TestProduct> getById(UuidValue id) async {
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
        'Failed to retrieve TestProduct',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(TestProduct aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
        'Failed to save TestProduct',
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
        'Failed to delete TestProduct',
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

/// Generated abstract base REST repository for [TestOrder] aggregate.
///
/// This abstract class implements the base Repository<TestOrder> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class TestOrderRestRepositoryBase implements TestOrderRepository {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  TestOrderRestRepositoryBase(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for TestOrder aggregates.
  String get _resourcePath => '/orders';

  /// The JSON serializer for TestOrder aggregates.
  final _serializer = TestOrderJsonSerializer();

  @override
  Future<TestOrder> getById(UuidValue id) async {
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
        'Failed to retrieve TestOrder',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(TestOrder aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
        'Failed to save TestOrder',
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
        'Failed to delete TestOrder',
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

  // Custom methods (must be implemented by subclass)

  @override
  Future<List<TestOrder>> findByCustomerId(String customerId);

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber);
}

/// Generated REST repository for [TestAccount] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class TestAccountRestRepository implements Repository<TestAccount> {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  TestAccountRestRepository(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for TestAccount aggregates.
  String get _resourcePath => '/accounts';

  /// The JSON serializer for TestAccount aggregates.
  final _serializer = TestAccountJsonSerializer();

  @override
  Future<TestAccount> getById(UuidValue id) async {
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
        'Failed to retrieve TestAccount',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(TestAccount aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
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
        'Failed to save TestAccount',
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
        'Failed to delete TestAccount',
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
