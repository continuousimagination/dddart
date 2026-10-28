import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('DynamoDB validates UTF-8 byte limits and exact identity keys',
      () async {
    final codecs = identityCodecs();
    expect(
      encodeDynamoIdentityKey<NativeId>(codecs, const NativeId('IssueA')),
      'IssueA',
    );
    expect(
      encodeDynamoIdentityKey<NativeId>(codecs, const NativeId('issuea')),
      'issuea',
    );
    expect(
      encodeDynamoIdentityKey<NativeId>(
        codecs,
        NativeId(List.filled(1024, 'é').join()),
      ).length,
      1024,
    );
    final connection = DynamoConnection.local(port: 1);
    addTearDown(connection.dispose);
    final repo =
        NativeIssueDynamoRepository(connection, identityCodecs: codecs);
    final constraint = throwsA(
      isA<RepositoryException>()
          .having((e) => e.type, 'type', RepositoryExceptionType.constraint),
    );
    for (final value in [
      '',
      List.filled(1025, 'é').join(),
      String.fromCharCode(0xd800),
    ]) {
      final id = NativeId(value);
      await expectLater(
        repo.save(NativeIssue(id: id, label: 'bad')),
        constraint,
      );
      await expectLater(repo.getById(id), constraint);
      await expectLater(repo.deleteById(id), constraint);
    }
  });

  test(
      'custom item reads reconstruct structural scoped IDs and reject malformed keys',
      () {
    final connection = DynamoConnection.local(port: 1);
    addTearDown(connection.dispose);
    final repo = ScopedIssueDynamoRepositoryImpl(
      connection,
      identityCodecs: identityCodecs(),
    );
    final item = {
      'id': AttributeValue(s: '["org/repo",12]'),
      'label': AttributeValue(s: 'issue'),
      'createdAt': AttributeValue(s: DateTime.utc(2026).toIso8601String()),
      'updatedAt': AttributeValue(s: DateTime.utc(2026).toIso8601String()),
    };
    expect(repo.fromItem(item).id, const ScopedId('org/repo', 12));
    item['id'] = AttributeValue(s: '["org/repo", "12"]');
    expect(() => repo.fromItem(item), throwsA(isA<DeserializationException>()));
    item['id'] = AttributeValue(s: '[ "org/repo",12]');
    expect(() => repo.fromItem(item), throwsA(isA<DeserializationException>()));
  });
}
