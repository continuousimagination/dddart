@Tags(['requires-mysql'])
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

import 'integration_test_models.dart';

void main() {
  late MysqlConnection connection;
  late NativeIssueMysqlRepositoryImpl repository;
  const dialect = MysqlDialect();
  const childTable = 'native_comment';
  const parentColumn = 'workynativeissues_id';
  const positionColumn = '_list_position';
  const firstId = NativeId('generic/IssueA %, café');
  const secondId = NativeId('generic/issuea %, café');

  setUpAll(() async {
    connection = MysqlConnection(
      host: '127.0.0.1',
      port: 3307,
      database: 'test_db',
      user: 'root',
      password: 'test_password',
    );
    await connection.open();
    repository = NativeIssueMysqlRepositoryImpl(
      connection,
      identityCodecs: identityCodecs(),
    );
    await repository.createTables();
  });
  tearDownAll(() async {
    for (final id in [firstId, secondId]) {
      try {
        await repository.deleteById(id);
      } on RepositoryException catch (error) {
        if (error.type != RepositoryExceptionType.notFound) rethrow;
      }
    }
    await connection.close();
  });

  NativeComment comment(NativeId parent, int number, String message) =>
      NativeComment(
        id: ScopedId('comments/${parent.value}', number),
        authorId: const NativeId('author/%, café'),
        message: message,
      );
  NativeIssue issue(NativeId id, List<NativeComment> comments) => NativeIssue(
        id: id,
        label: id.value,
        reference: const NativeId('ref'),
        comments: comments,
      );

  test(
      'inherited generic entity lists preserve scoped IDs, parent FKs, order and deletion isolation',
      () async {
    // SqlIssueBase<I, C extends Entity<ScopedId>> owns List<C> comments.
    final first = issue(
      firstId,
      [comment(firstId, 20, 'first'), comment(firstId, 10, 'second')],
    );
    final second = issue(secondId, [comment(secondId, 20, 'other parent')]);
    await repository.save(first);
    await repository.save(second);
    final restored = await repository.getById(firstId);
    expect(
      restored.comments.map((item) => item.id),
      first.comments.map((item) => item.id),
    );
    expect(restored.comments.map((item) => item.message), ['first', 'second']);
    expect(
      restored.comments.map((item) => item.authorId),
      first.comments.map((item) => item.authorId),
    );

    final rows = await connection.query(
      'SELECT id, $parentColumn, $positionColumn FROM $childTable WHERE $parentColumn = ? ORDER BY $positionColumn',
      [dialect.encodeIdentityKey(firstId.value)],
    );
    expect(rows, hasLength(2));
    expect(
      rows.map((row) => dialect.decodeIdentityKey(row[parentColumn])),
      [firstId.value, firstId.value],
    );
    expect(rows.map((row) => row[positionColumn]), [0, 1]);
    final codecs = identityCodecs();
    expect(
      rows.map(
        (row) => codecs.fromKey<ScopedId>(dialect.decodeIdentityKey(row['id'])),
      ),
      first.comments.map((item) => item.id),
    );

    final updated = issue(
      firstId,
      [comment(firstId, 10, 'changed'), comment(firstId, 30, 'new')],
    );
    await repository.save(updated);
    final reloaded = await repository.getById(firstId);
    expect(
      reloaded.comments.map((item) => item.id),
      updated.comments.map((item) => item.id),
    );
    expect(reloaded.comments.map((item) => item.message), ['changed', 'new']);
    expect(
      (await repository.getById(secondId)).comments.single.id,
      second.comments.single.id,
    );
    expect(
      (await repository.getById(secondId)).comments.single.message,
      'other parent',
    );
    await repository.deleteById(firstId);
    expect(
      await connection.query(
        'SELECT id FROM $childTable WHERE $parentColumn = ?',
        [dialect.encodeIdentityKey(firstId.value)],
      ),
      isEmpty,
    );
    expect(
      (await repository.getById(secondId)).comments.single.id,
      second.comments.single.id,
    );
    await repository.deleteById(secondId);
  });
}
