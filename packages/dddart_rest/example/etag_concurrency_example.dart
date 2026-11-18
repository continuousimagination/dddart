// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'lib/json_serializer_support.dart';

// Simple User aggregate for demonstration
class User extends AggregateRoot<UuidValue> {
  User({
    required super.id,
    required this.name,
    required this.email,
    required super.createdAt,
    required super.updatedAt,
  });

  final String name;
  final String email;
}

// Simple JSON serializer
class UserSerializer extends ExampleJsonSerializer<User> {
  @override
  String serialize(User user, [SerializationConfig? config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'email': user.email,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    });
  }

  @override
  User deserialize(String data, [SerializationConfig? config]) {
    final json = jsonDecode(data);
    return User(
      id: UuidValue.fromString(json['id']),
      name: json['name'],
      email: json['email'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

/// Runs concurrent edits through real HTTP and the conditional reference store.
/// Production deployments use the same contract with a durable SQL/document adapter.
Future<void> main() async {
  final serializer = UserSerializer();
  final repository = InMemoryConditionalRepository<User, UuidValue>(
    clone: (user) => serializer.deserialize(serializer.serialize(user)),
  );
  final app = HttpServer()
    ..registerResource(
      CrudResource<User, UuidValue, void>(
        path: '/users',
        repository: repository,
        serializer: serializer,
      ),
    );
  final server = await shelf_io.serve(
    app.buildHandler(),
    io.InternetAddress.loopbackIPv4,
    0,
  );
  final client = http.Client();
  try {
    final now = DateTime.now().toUtc();
    final user = User(
      id: UuidValue.generate(),
      name: 'Original',
      email: 'example@example.com',
      createdAt: now,
      updatedAt: now,
    );
    final uri = Uri.parse('http://127.0.0.1:${server.port}/users/${user.id}');
    final created = await client.put(
      uri,
      headers: {'content-type': 'application/json', 'if-none-match': '*'},
      body: serializer.serialize(user),
    );
    if (created.statusCode != 201) {
      throw StateError('Create failed: ${created.statusCode}');
    }
    final snapshots = await Future.wait([client.get(uri), client.get(uri)]);
    Future<http.Response> edit(int index) {
      final changed = serializer
          .toJson(serializer.deserialize(snapshots[index].body))
        ..['name'] = 'Client $index';
      return client.put(
        uri,
        headers: {
          'content-type': 'application/json',
          'if-match': snapshots[index].headers['etag']!,
        },
        body: jsonEncode(changed),
      );
    }

    final updates = await Future.wait([edit(0), edit(1)]);
    final statuses = updates.map((response) => response.statusCode).toList()
      ..sort();
    if (statuses.toString() != '[200, 412]') {
      throw StateError('Expected one winner and one stale conflict: $statuses');
    }
    print('Concurrent edits: one committed, one returned 412.');

    // Reload and deliberately recompute after conflict. Never silently retry a
    // stale payload with a freshly fetched token.
    final latest = await client.get(uri);
    final merged = serializer.toJson(serializer.deserialize(latest.body))
      ..['name'] = 'Reviewed merge';
    final retried = await client.put(
      uri,
      headers: {
        'content-type': 'application/json',
        'if-match': latest.headers['etag']!,
      },
      body: jsonEncode(merged),
    );
    if (retried.statusCode != 200) throw StateError('Reviewed update failed.');
    print('Reloaded, recomputed, and committed the reviewed update.');
    print('New revision ETag: ${retried.headers['etag']}');
  } finally {
    client.close();
    await server.close(force: true);
  }
}
