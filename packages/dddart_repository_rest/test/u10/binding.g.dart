// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'binding.dart';

// **************************************************************************
// RestRepositoryGenerator
// **************************************************************************

/// Generated REST repository for [shared.RemoteRecord] aggregate.
///
/// This class can be used directly for basic CRUD operations or extended
/// to add custom query methods.
class ProbeRestRepository implements Repository<shared.RemoteRecord> {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  ProbeRestRepository(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for shared.RemoteRecord aggregates.
  String get _resourcePath => 'records';

  /// The JSON serializer for shared.RemoteRecord aggregates.
  final _serializer = shared.RemoteRecordJsonSerializer();

  @override
  Future<shared.RemoteRecord> getById(UuidValue id) async {
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
        'Failed to retrieve shared.RemoteRecord',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(shared.RemoteRecord aggregate) async {
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
        'Failed to save shared.RemoteRecord',
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
        'Failed to delete shared.RemoteRecord',
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

/// Generated abstract base REST repository for [shared.RemoteRecord] aggregate.
///
/// This abstract class implements the base Repository<shared.RemoteRecord> methods
/// (getById, save, deleteById) and declares custom methods as abstract.
///
/// Extend this class and implement the abstract methods to complete
/// the repository implementation.
abstract class CallbackRestRepositoryBase implements shared.RemotePort {
  /// Creates a repository instance.
  ///
  /// [connection] - A REST connection to the API server.
  CallbackRestRepositoryBase(this._connection);

  /// The REST connection instance.
  final RestConnection _connection;

  /// The resource path for shared.RemoteRecord aggregates.
  String get _resourcePath => 'records';

  /// The JSON serializer for shared.RemoteRecord aggregates.
  final _serializer = shared.RemoteRecordJsonSerializer();

  @override
  Future<shared.RemoteRecord> getById(UuidValue id) async {
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
        'Failed to retrieve shared.RemoteRecord',
        type: RepositoryExceptionType.unknown,
      );
    }
  }

  @override
  Future<void> save(shared.RemoteRecord aggregate) async {
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
        'Failed to save shared.RemoteRecord',
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
        'Failed to delete shared.RemoteRecord',
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
  Future<shared.RemoteRecord Function(shared.RemoteRecord)> callback({
    int take = 20,
    String label = "\$label",
    shared.FilterMode mode = shared.FilterMode.all,
  });
}
