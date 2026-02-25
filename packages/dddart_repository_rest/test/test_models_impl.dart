part of 'test_models.dart';

/// Concrete implementation of TestOrderRepository.
///
/// Extends the generated abstract base class and implements custom query methods.
class TestOrderRestRepository extends TestOrderRestRepositoryBase {
  /// Creates a test order repository.
  TestOrderRestRepository(super.connection);

  @override
  Future<List<TestOrder>> findByCustomerId(String customerId) async {
    try {
      final response = await _connection.client.get(
        Uri.parse(
          '${_connection.baseUrl}$_resourcePath?customerId=$customerId',
        ),
      );

      if (response.statusCode == 200) {
        final jsonList = json.decode(response.body) as List<dynamic>;
        return jsonList
            .map((j) => _serializer.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to find orders by customer ID: $e',
      );
    }
  }

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber) async {
    try {
      final response = await _connection.client.get(
        Uri.parse(
          '${_connection.baseUrl}$_resourcePath?orderNumber=$orderNumber',
        ),
      );

      if (response.statusCode == 200) {
        final jsonList = json.decode(response.body) as List<dynamic>;
        if (jsonList.isEmpty) return null;
        return _serializer.fromJson(jsonList.first as Map<String, dynamic>);
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to find order by order number: $e',
      );
    }
  }
}
