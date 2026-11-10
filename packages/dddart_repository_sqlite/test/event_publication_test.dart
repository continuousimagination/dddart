import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  late TestSqliteHelper helper;
  late SqliteConnection connection;
  setUp(() {
    helper = createTestHelper();
    connection = helper.connect();
  });
  tearDown(() => helper.disconnect());

  test('generated SQLite publisher sees committed data and cannot undo save',
      () async {
    final user = TestUser(
      name: 'Alice',
      email: 'alice@example.com',
      isActive: true,
    );
    final event = _Changed(user.id);
    user.raiseEvent(event);
    final reader = TestUserSqliteRepository(connection);
    final repository = TestUserSqliteRepository(
      connection,
      eventPublisher: _Publisher((published) async {
        expect(published, same(event));
        expect((await reader.getById(user.id)).name, 'Alice');
        return false;
      }),
    );
    await repository.createTables();

    await repository.save(user);

    expect((await reader.getById(user.id)).name, 'Alice');
    expect(user.getUncommittedEvents(), [event]);
  });

  test('failed SQLite transaction keeps captured events without publishing',
      () async {
    final user = TestUser(
      name: 'Alice',
      email: 'alice@example.com',
      isActive: true,
    );
    final event = _Changed(user.id);
    user.raiseEvent(event);
    var publications = 0;
    final repository = TestUserSqliteRepository(
      connection,
      eventPublisher: _Publisher((_) async {
        publications++;
        return true;
      }),
    );
    // The schema has deliberately not been created.
    await expectLater(
      repository.save(user),
      throwsA(isA<RepositoryException>()),
    );
    expect(publications, 0);
    expect(user.getUncommittedEvents(), [event]);
  });
}

class _Changed extends DomainEvent<UuidValue> {
  _Changed(UuidValue id) : super(aggregateId: id);
}

class _Publisher implements EventPublisher {
  _Publisher(this.callback);
  final Future<bool> Function(DomainEvent<Identity>) callback;
  @override
  Future<bool> publish(DomainEvent<Identity> event) => callback(event);
}
