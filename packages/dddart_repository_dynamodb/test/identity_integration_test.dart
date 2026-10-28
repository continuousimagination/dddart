@Tags(['requires-dynamodb'])
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  late DynamoConnection connection;
  late NativeIssueDynamoRepository native;
  late ScopedIssueDynamoRepositoryImpl scoped;
  setUpAll(() async {
    connection = DynamoConnection.local();
    native = NativeIssueDynamoRepository(
      connection,
      identityCodecs: identityCodecs(),
    );
    scoped = ScopedIssueDynamoRepositoryImpl(
      connection,
      identityCodecs: identityCodecs(),
    );
    await native.createTable();
    await scoped.createTable();
  });
  tearDownAll(() async {
    await connection.client.deleteTable(tableName: native.tableName);
    await connection.client.deleteTable(tableName: scoped.tableName);
    connection.dispose();
  });

  test(
      'native IDs coexist, update and delete without case or whitespace collapse',
      () async {
    for (final value in [
      'IssueA',
      'issuea',
      'native/%, café',
      'trailing ',
      'trailing',
    ]) {
      await native.save(NativeIssue(id: NativeId(value), label: value));
    }
    await native
        .save(NativeIssue(id: const NativeId('IssueA'), label: 'updated'));
    expect((await native.getById(const NativeId('IssueA'))).label, 'updated');
    expect((await native.getById(const NativeId('issuea'))).label, 'issuea');
    for (final value in ['native/%, café', 'trailing ', 'trailing']) {
      expect((await native.getById(NativeId(value))).id, NativeId(value));
    }
    await native.deleteById(const NativeId('IssueA'));
    await expectLater(
      native.getById(const NativeId('IssueA')),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
    expect((await native.getById(const NativeId('issuea'))).label, 'issuea');
  });

  test('scoped IDs retain native numbers through custom typed reads', () async {
    for (final scope in ['org/one', 'org/two']) {
      await scoped.save(ScopedIssue(id: ScopedId(scope, 12), label: scope));
    }
    expect(
      (await scoped.getById(const ScopedId('org/one', 12))).id,
      const ScopedId('org/one', 12),
    );
    expect(
      (await scoped.findScoped(
        const ScopedId('org/two', 12),
        label: 'org/two',
      ))!
          .label,
      'org/two',
    );
    await scoped.deleteById(const ScopedId('org/one', 12));
    expect(
      (await scoped.getById(const ScopedId('org/two', 12))).id,
      const ScopedId('org/two', 12),
    );
  });
}
