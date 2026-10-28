@Tags(['requires-mongo'])
library;

import 'package:dddart/dddart.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  late Db database;
  setUpAll(() async {
    database = Db('mongodb://127.0.0.1:27017/worky_identity_roundtrip');
    await database.open();
    await database.collection('worky_native_identities').drop();
    await database.runCommand({
      'create': 'worky_native_identities',
      'collation': {'locale': 'en', 'strength': 2},
    });
  });
  tearDownAll(() async {
    await database.collection('worky_native_identities').drop();
    await database.collection('worky_scoped_identities').drop();
    await database.close();
  });

  test(
      'native IDs coexist, update and delete under insensitive collection collation',
      () async {
    final repository =
        NativeIssueMongoRepository(database, identityCodecs: identityCodecs());
    for (final value in [
      'IssueA',
      'issuea',
      'native/%, café',
      'trailing ',
      'trailing',
    ]) {
      await repository.save(NativeIssue(id: NativeId(value), label: value));
    }
    await repository
        .save(NativeIssue(id: const NativeId('IssueA'), label: 'updated'));
    expect(
      (await repository.getById(const NativeId('IssueA'))).label,
      'updated',
    );
    expect(
      (await repository.getById(const NativeId('issuea'))).label,
      'issuea',
    );
    for (final value in ['native/%, café', 'trailing ', 'trailing']) {
      expect((await repository.getById(NativeId(value))).id, NativeId(value));
    }
    await repository.deleteById(const NativeId('IssueA'));
    await expectLater(
      repository.getById(const NativeId('IssueA')),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
    expect(
      (await repository.getById(const NativeId('issuea'))).label,
      'issuea',
    );
  });

  test('scoped IDs keep native numbers and custom typed repository reads',
      () async {
    final repository = ScopedIssueMongoRepositoryImpl(
      database,
      identityCodecs: identityCodecs(),
    );
    for (final scope in ['org/one', 'org/two']) {
      await repository.save(ScopedIssue(id: ScopedId(scope, 12), label: scope));
    }
    final original = await repository.getById(const ScopedId('org/one', 12));
    expect(original.id, const ScopedId('org/one', 12));
    expect(
      (await repository.findScoped(
        const ScopedId('org/two', 12),
        label: 'org/two',
      ))!
          .label,
      'org/two',
    );
    await repository.deleteById(const ScopedId('org/one', 12));
    expect(
      (await repository.getById(const ScopedId('org/two', 12))).id,
      const ScopedId('org/two', 12),
    );
  });
}
