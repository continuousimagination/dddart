import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = MysqlConnection(
      host: '127.0.0.1',
      port: 3307,
      database: 'test_db',
      user: 'root',
      password: 'test_password');
  await connection.open();
  try {
    final repository = NoteMysqlRepository(connection);
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
