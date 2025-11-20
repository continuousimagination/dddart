/// Implementation of test repository interfaces.
part of 'test_models.dart';

/// Implementation of TestOrderRepository for testing.
class TestOrderMongoRepositoryImpl extends TestOrderMongoRepositoryBase {
  /// Creates the repository implementation.
  TestOrderMongoRepositoryImpl(super.database);

  @override
  Future<List<TestOrder>> findByCustomerId(String customerId) async {
    final docs =
        await _collection.find(where.eq('customerId', customerId)).toList();

    return docs.map((doc) {
      doc['id'] = doc['_id'];
      doc.remove('_id');
      return _serializer.fromJson(doc);
    }).toList();
  }

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber) async {
    final doc = await _collection.findOne(where.eq('orderNumber', orderNumber));

    if (doc == null) return null;

    doc['id'] = doc['_id'];
    doc.remove('_id');
    return _serializer.fromJson(doc);
  }
}
