import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = SqliteConnection.memory();
  await connection.open();
  try {
    final repository = NoteSqliteRepository(connection);
    await repository.createTables();
    final note = Note(text: 'hello');
    await repository.save(note);
    final restored = await repository.getById(note.id);
    if (restored.id != note.id || restored.text != note.text) {
      throw StateError('The saved note did not round trip');
    }
    print('hello: persisted');
    await repository.deleteById(note.id);
  } finally {
    await connection.close();
  }
}
