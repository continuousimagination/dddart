import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  late SqliteConnection connection;
  late NativeIssueSqliteRepositoryImpl native;
  late ScopedIssueSqliteRepository scoped;
  const dialect = SqliteDialect();
  const childTable = 'worky_native_issues_comments';
  const parentColumn = 'worky_native_issues_id';
  setUpAll(() async {
    connection = SqliteConnection.memory();
    await connection.open();
    native = NativeIssueSqliteRepositoryImpl(
      connection,
      identityCodecs: identityCodecs(),
    );
    scoped = ScopedIssueSqliteRepository(
      connection,
      identityCodecs: identityCodecs(),
    );
    await native.createTables();
    await scoped.createTables();
  });
  tearDownAll(() async => connection.close());

  test('UUID text case remains significant through SQL CRUD', () async {
    final repository = TestUserSqliteRepository(connection);
    await repository.createTables();
    final lower = UuidValue.fromString('a0b1c2d3-e4f5-4a6b-8c7d-0123456789ab');
    final upper = UuidValue.fromString(lower.uuid.toUpperCase());
    for (final id in [lower, upper]) {
      await repository.save(
        TestUser(
          id: id,
          name: id.uuid,
          email: 'test@example.com',
          isActive: true,
        ),
      );
      expect((await repository.getById(id)).id, id);
    }
    await repository.deleteById(lower);
    expect((await repository.getById(upper)).id, upper);
    await repository.deleteById(upper);
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
