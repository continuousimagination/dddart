import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import 'lib/custom_user.dart';

Future<void> main() async {
  final connection = SqliteConnection.memory();
  await connection.open();
  try {
    final writer = CustomUserRepositoryImpl(connection);
    await writer.createTables();
    for (final (name, active) in [
      ('Sam', true),
      ('Ari', true),
      ('Jo', false)
    ]) {
      await writer.save(CustomUser(
        name: name,
        email: '${name.toLowerCase()}@example.com',
        isActive: active,
        registeredAt: DateTime.utc(2024, 1, 1),
      ));
    }

    // A separately constructed repository reads the same stored rows.
    final reader = CustomUserRepositoryImpl(connection);
    final active = await reader.findActiveUsers();
    final first = await reader.findActiveUsers(limit: 1);
    final names = active.map((user) => user.name).join(', ');
    if (names != 'Ari, Sam' || first.single.id != active.first.id) {
      throw StateError('Expected the first active users in name order.');
    }
    print('Active users: $names');
  } finally {
    await connection.close();
  }
}
