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
        'category',
        effectiveConfig.fieldRename,
      ): instance.category,
      SerializationUtils.applyFieldRename(
        'description',
        effectiveConfig.fieldRename,
      ): instance.description,
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
        category:
            json[SerializationUtils.applyFieldRename(
                  'category',
                  effectiveConfig.fieldRename,
                )]
                as String,
        description:
            json[SerializationUtils.applyFieldRename(
                  'description',
                  effectiveConfig.fieldRename,
                )]
                as String,
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
// RestRepositoryGenerator
// **************************************************************************

/// Generated abstract base REST repository for [Product] aggregate.
///
/// This abstract class implements the base Repository<Product> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class ProductRestRepositoryBase implements ProductRepository {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  ProductRestRepositoryBase(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for Product aggregates.
  String get _resourcePath => '/products';

  /// The JSON serializer for Product aggregates.
  final _serializer = ProductJsonSerializer();

  @override
  Future<Product> getById(UuidValue id) async {
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
        'Failed to retrieve Product',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(Product aggregate) async {
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
        'Failed to save Product',
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
        'Failed to delete Product',
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
  Future<List<Product>> findByCategory(String category);

  @override
  Future<List<Product>> findByPriceRange(double minPrice, double maxPrice);
}
