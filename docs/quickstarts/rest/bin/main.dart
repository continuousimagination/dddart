import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/note.dart';

Future<void> main() async {
  final serializer = NoteJsonSerializer();
  final repository = InMemoryRepository<Note, UuidValue>();
  final note = Note(text: 'public hello');
  await repository.save(note);
  final app = HttpServer()
    ..registerResource(
      CrudResource<Note, UuidValue, Object>(
        path: '/notes', repository: repository, serializer: serializer,
        // No authentication handler: this resource is public by default.
      ),
    );
  final server = await shelf_io.serve(
      app.buildHandler(), io.InternetAddress.loopbackIPv4, 0);
  final client = http.Client();
  final connection = RestConnection(baseUrl: 'http://127.0.0.1:${server.port}');
  try {
    final response = await client.get(
        Uri.parse('http://127.0.0.1:${server.port}/notes/${note.id.uuid}'));
    if (response.statusCode != 200 ||
        serializer.deserialize(response.body).text != note.text) {
      throw StateError(
          'Public read failed: ${response.statusCode} ${response.body}');
    }
    final remote = NoteRestRepository(connection);
    if ((await remote.getById(note.id)).text != note.text) {
      throw StateError('Generated REST repository read failed');
    }
    print('200: public hello');
  } finally {
    connection.dispose();
    client.close();
    await server.close(force: true);
  }
}
