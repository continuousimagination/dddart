import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

import '../lib/note.dart';

Future<void> main() async {
  final connection = DynamoConnection.local();
  final repository = NoteDynamoRepository(connection);
  try {
    // This demo owns its table in a fresh, disposable DynamoDB Local instance.
    await repository.createTable();
    try {
      final note = Note(text: 'hello');
      await repository.save(note);
      final restored = await repository.getById(note.id);
      if (restored.id != note.id || restored.text != note.text) {
        throw StateError('The saved note did not round trip');
      }
      print('hello: persisted');
    } finally {
      await connection.client.deleteTable(tableName: 'quickstart_notes');
    }
  } finally {
    connection.dispose();
  }
}
