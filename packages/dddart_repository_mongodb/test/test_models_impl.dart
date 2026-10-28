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
      doc.remove('_id');
      return _serializer.fromJson(doc);
    }).toList();
  }

  @override
  Future<TestOrder?> findByOrderNumber(String orderNumber) async {
    final doc = await _collection.findOne(where.eq('orderNumber', orderNumber));

    if (doc == null) return null;

    doc.remove('_id');
    return _serializer.fromJson(doc);
  }
}

/// Custom implementation keeps typed ID and named parameters from its interface.
class ScopedIssueMongoRepositoryImpl extends ScopedIssueMongoRepositoryBase {
  /// Creates a repository with its application codecs.
  ScopedIssueMongoRepositoryImpl(super.database, {super.identityCodecs});
  @override
  Future<ScopedIssue?> findScoped(ScopedId id, {String? label}) async {
    final doc = await _collection.findOne(
      where.eq('_id', encodeMongoIdentityKey<ScopedId>(_identityCodecs, id)),
    );
    if (doc == null) return null;
    final issue = fromDocument(doc);
    return label == null || issue.label == label ? issue : null;
  }
}
