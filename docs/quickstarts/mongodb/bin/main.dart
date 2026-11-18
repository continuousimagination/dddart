import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = MongoConnection(
      host: '127.0.0.1', port: 27017, databaseName: 'dddart_quickstart');
  await connection.open();
  try {
    final repository = NoteMongoRepository(connection.database);
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
