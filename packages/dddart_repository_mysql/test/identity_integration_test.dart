@Tags(['requires-mysql'])
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

import 'integration_test_models.dart';

void main() {
  late MysqlConnection connection;
  late NativeIssueMysqlRepositoryImpl native;
  late ScopedIssueMysqlRepository scoped;
  const dialect = MysqlDialect();
  const childTable = 'native_comment';
  const parentColumn = 'workynativeissues_id';
  setUpAll(() async {
    connection = MysqlConnection(
      host: '127.0.0.1',
      port: 3307,
      database: 'test_db',
      user: 'root',
      password: 'test_password',
    );
    await connection.open();
    await connection.execute("SET SESSION sql_mode = ''");
    native = NativeIssueMysqlRepositoryImpl(
      connection,
      identityCodecs: identityCodecs(),
    );
    scoped = ScopedIssueMysqlRepository(
      connection,
      identityCodecs: identityCodecs(),
    );
    await native.createTables();
    await scoped.createTables();
  });
  tearDownAll(() async {
    for (final table in ['worky_native_issues', 'worky_scoped_issues']) {
      await connection.execute('DELETE FROM $table');
    }
    await connection.close();
  });

  test('legacy padded identity columns fail before writes in non-strict mode',
      () async {
    await connection.execute('CREATE TABLE worky_legacy_identity ( '
        'id BINARY(16) PRIMARY KEY NOT NULL, createdAt DATETIME NOT NULL, updatedAt DATETIME NOT NULL)');
    try {
      final repository = LegacyIdentityMysqlRepository(connection);
      await expectLater(
        repository.save(LegacyIdentity()),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.constraint,
          ),
        ),
      );
      final rows = await connection
          .query('SELECT COUNT(*) AS count FROM worky_legacy_identity');
      expect(rows.single['count'], 0);
    } finally {
      await connection.execute('DROP TABLE worky_legacy_identity');
    }
  });

  test('UUID text case remains significant through SQL CRUD', () async {
    final repository = SimpleProductMysqlRepository(connection);
    await repository.createTables();
    final lower = UuidValue.fromString('a0b1c2d3-e4f5-4a6b-8c7d-0123456789ab');
    final upper = UuidValue.fromString(lower.uuid.toUpperCase());
    for (final id in [lower, upper]) {
      await repository.save(SimpleProduct(id: id, name: id.uuid, price: 1));
      expect((await repository.getById(id)).id, id);
    }
    await repository.deleteById(lower);
    expect((await repository.getById(upper)).id, upper);
    await repository.deleteById(upper);
  });

  test(
      'MySQL rejects oversized keys before truncation even outside strict mode',
      () async {
    final key = List.filled(513, 'é').join();
    final constraint = throwsA(
      isA<RepositoryException>()
          .having((e) => e.type, 'type', RepositoryExceptionType.constraint),
    );
    await expectLater(
      native.save(
        NativeIssue(
          id: NativeId(key),
          label: 'oversized',
          reference: const NativeId('ref'),
        ),
      ),
      constraint,
    );
    await expectLater(native.getById(NativeId(key)), constraint);
    await expectLater(native.deleteById(NativeId(key)), constraint);
  });

  NativeIssue nativeIssue(
    String value, {
    String? label,
    bool clearOptional = false,
    bool invalidChild = false,
  }) =>
      NativeIssue(
        id: NativeId(value),
        label: label ?? value,
        reference: NativeId('reference/$value'),
        optionalReference: clearOptional ? null : NativeId('optional/$value'),
        history: [
          NativeId('history/$value'),
          null,
          const NativeId('2026-10-28'),
        ],
        labelsById: {
          const NativeId('IssueA'): const NativeId('mapped/%, café'),
          const NativeId('issuea'): null,
        },
        holder: clearOptional
            ? null
            : SqlIdentityHolder(owner: ScopedId('holder/$value', 12)),
        comments: [
          NativeComment(
            id: ScopedId('comment/$value', 1),
            authorId: NativeId(
              invalidChild ? String.fromCharCode(0xd800) : 'author/$value',
            ),
            message: 'comment',
          ),
        ],
      );

  test(
      'native IDs preserve exact equality through inherited fields and collection FKs',
      () async {
    for (final key in [
      'IssueA',
      'issuea',
      '12',
      '0012',
      'trailing',
      'trailing ',
      'native/%, café',
    ]) {
      final original = nativeIssue(key);
      await native.save(original);
      final restored = await native.getById(original.id);
      expect(restored.id, original.id);
      expect(restored.reference, original.reference);
      expect(restored.history, original.history);
      expect(restored.labelsById, original.labelsById);
      expect(restored.holder, original.holder);
      expect(restored.comments.single.id, original.comments.single.id);
      expect(
        restored.comments.single.authorId,
        original.comments.single.authorId,
      );
    }
    await native
        .save(nativeIssue('IssueA', label: 'updated', clearOptional: true));
    final updated =
        await native.lookupLabel(const NativeId('IssueA'), label: 'updated');
    expect(updated!.optionalReference, isNull);
    expect(updated.holder, isNull);
    expect((await native.getById(const NativeId('issuea'))).label, 'issuea');
    for (final key in ['IssueA', 'issuea']) {
      final rows = await connection.query(
        'SELECT $parentColumn FROM $childTable WHERE $parentColumn = ?',
        [dialect.encodeIdentityKey(key)],
      );
      expect(rows.length, 1);
      expect(dialect.decodeIdentityKey(rows.single[parentColumn]), key);
    }
    await native.deleteById(const NativeId('IssueA'));
    await expectLater(
      native.getById(const NativeId('IssueA')),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
    expect(
      (await native.getById(const NativeId('issuea'))).comments.single.id,
      const ScopedId('comment/issuea', 1),
    );
    expect(
      await connection.query(
        'SELECT $parentColumn FROM $childTable WHERE $parentColumn = ?',
        [dialect.encodeIdentityKey('IssueA')],
      ),
      isEmpty,
    );
  });

  test(
      'scoped IDs with equal local numbers survive typed keys, maps and nested entities',
      () async {
    for (final scope in ['org/one', 'org/two']) {
      final original = ScopedIssue(
        id: ScopedId(scope, 12),
        label: scope,
        reference: ScopedId('reference/$scope', 12),
        optionalReference: ScopedId('optional/$scope', 12),
        history: [ScopedId(scope, 13), null],
        labelsById: {
          const ScopedId('map/one', 12): const ScopedId('map/two', 12),
          const ScopedId('map/two', 12): null,
        },
        holder: SqlIdentityHolder(owner: ScopedId('holder/$scope', 12)),
        comments: [
          ScopedComment(
            id: ScopedId('comment/$scope', 1),
            authorId: NativeId('author/$scope'),
            message: 'comment',
          ),
        ],
      );
      await scoped.save(original);
      final restored = await scoped.getById(original.id);
      expect(restored.id, original.id);
      expect(restored.reference, original.reference);
      expect(restored.history, original.history);
      expect(restored.labelsById, original.labelsById);
      expect(restored.comments.single.id, original.comments.single.id);
      expect(
        restored.comments.single.authorId,
        original.comments.single.authorId,
      );
    }
    await scoped.deleteById(const ScopedId('org/one', 12));
    expect(
      (await scoped.getById(const ScopedId('org/two', 12))).id,
      const ScopedId('org/two', 12),
    );
  });

  test(
      'malformed native keys reject operations and nested failure rolls back changes',
      () async {
    final bad = NativeId(String.fromCharCode(0xd800));
    final constraint = throwsA(
      isA<RepositoryException>()
          .having((e) => e.type, 'type', RepositoryExceptionType.constraint),
    );
    await expectLater(native.save(nativeIssue(bad.value)), constraint);
    await expectLater(native.getById(bad), constraint);
    await expectLater(native.deleteById(bad), constraint);
    final original = nativeIssue('rollback', label: 'original');
    await native.save(original);
    await expectLater(
      native.save(
        nativeIssue('rollback', label: 'changed', invalidChild: true),
      ),
      constraint,
    );
    final restored = await native.getById(original.id);
    expect(restored.label, 'original');
    expect(
      restored.comments.single.authorId,
      original.comments.single.authorId,
    );
  });
}
