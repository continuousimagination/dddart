// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:http/http.dart' as http;

// Simple User aggregate for demonstration
class User extends AggregateRoot {
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
class UserSerializer implements Serializer<User> {
  @override
  String serialize(User user, [dynamic config]) {
    return jsonEncode({
      'id': user.id.toString(),
      'name': user.name,
      'email': user.email,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    });
  }

  @override
  User deserialize(String data, [dynamic config]) {
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

/// Example demonstrating ETag-based optimistic concurrency control
///
/// This example shows how ETags prevent lost updates when multiple clients
/// modify the same resource concurrently.
///
/// Run this example:
/// ```bash
/// dart run example/etag_concurrency_example.dart
/// ```
void main() async {
  print('=== ETag Concurrency Control Example ===\n');

  // Create repository and server
  final repository = InMemoryRepository<User>();
  final server = HttpServer(port: 8080);

  server.registerResource(
    CrudResource<User, dynamic>(
      path: '/users',
      repository: repository,
      serializers: {'application/json': UserSerializer()},
      etagStrategy: ETagStrategy.timestamp, // Use timestamp-based ETags
    ),
  );

  await server.start();
  print('Server started on http://localhost:8080\n');

  try {
    await _runConcurrencyDemo();
  } finally {
    await server.stop();
    print('\nServer stopped');
  }
}

Future<void> _runConcurrencyDemo() async {
  final client = http.Client();

  try {
    // Step 1: Create a user
    print('Step 1: Creating a user...');
    final createResponse = await client.post(
      Uri.parse('http://localhost:8080/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'name': 'John Doe',
        'email': 'john@example.com',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    if (createResponse.statusCode != 201) {
      print('Failed to create user: ${createResponse.statusCode}');
      return;
    }

    final userId = jsonDecode(createResponse.body)['id'];
    print('✓ User created with ID: $userId');
    print('  ETag: ${createResponse.headers['etag']}\n');

    // Step 2: Client A fetches the user
    print('Step 2: Client A fetches the user...');
    final clientAGet = await client.get(
      Uri.parse('http://localhost:8080/users/$userId'),
    );
    final clientAETag = clientAGet.headers['etag']!;
    final clientAData = jsonDecode(clientAGet.body);
    print('✓ Client A received user');
    print('  Name: ${clientAData['name']}');
    print('  ETag: $clientAETag\n');

    // Step 3: Client B fetches the user (gets same ETag)
    print('Step 3: Client B fetches the user...');
    final clientBGet = await client.get(
      Uri.parse('http://localhost:8080/users/$userId'),
    );
    final clientBETag = clientBGet.headers['etag']!;
    final clientBData = jsonDecode(clientBGet.body);
    print('✓ Client B received user');
    print('  Name: ${clientBData['name']}');
    print('  ETag: $clientBETag\n');

    // Step 4: Client A updates the user (with If-Match header)
    print('Step 4: Client A updates the user with If-Match header...');
    clientAData['name'] = 'Jane Doe';
    clientAData['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    final clientAUpdate = await client.put(
      Uri.parse('http://localhost:8080/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'If-Match': clientAETag,
      },
      body: jsonEncode(clientAData),
    );

    if (clientAUpdate.statusCode == 200) {
      final newETag = clientAUpdate.headers['etag']!;
      print('✓ Client A update succeeded');
      print('  New name: Jane Doe');
      print('  New ETag: $newETag\n');
    } else {
      print('✗ Client A update failed: ${clientAUpdate.statusCode}\n');
    }

    // Step 5: Client B tries to update with stale ETag
    print('Step 5: Client B tries to update with stale ETag...');
    clientBData['name'] = 'John Smith';
    clientBData['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    final clientBUpdate = await client.put(
      Uri.parse('http://localhost:8080/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'If-Match': clientBETag, // Stale ETag!
      },
      body: jsonEncode(clientBData),
    );

    if (clientBUpdate.statusCode == 412) {
      print('✓ Client B update rejected with 412 Precondition Failed');
      print('  Current ETag: ${clientBUpdate.headers['etag']}');
      final errorBody = jsonDecode(clientBUpdate.body);
      print('  Error: ${errorBody['detail']}\n');
    } else {
      print('✗ Expected 412 but got: ${clientBUpdate.statusCode}\n');
    }

    // Step 6: Client B fetches latest version and retries
    print('Step 6: Client B fetches latest version and retries...');
    final clientBRefresh = await client.get(
      Uri.parse('http://localhost:8080/users/$userId'),
    );
    final latestETag = clientBRefresh.headers['etag']!;
    final latestData = jsonDecode(clientBRefresh.body);
    print('✓ Client B fetched latest version');
    print('  Current name: ${latestData['name']}');
    print('  Latest ETag: $latestETag');

    // Apply Client B's change to the latest version
    latestData['name'] = 'Jane Smith';
    latestData['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    final clientBRetry = await client.put(
      Uri.parse('http://localhost:8080/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'If-Match': latestETag,
      },
      body: jsonEncode(latestData),
    );

    if (clientBRetry.statusCode == 200) {
      print('✓ Client B retry succeeded');
      final finalData = jsonDecode(clientBRetry.body);
      print('  Final name: ${finalData['name']}\n');
    } else {
      print('✗ Client B retry failed: ${clientBRetry.statusCode}\n');
    }

    // Step 7: Demonstrate update without If-Match (backward compatible)
    print('Step 7: Update without If-Match (backward compatible)...');
    final noETagData = jsonDecode(clientBRetry.body);
    noETagData['email'] = 'jane.smith@example.com';
    noETagData['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    final noETagUpdate = await client.put(
      Uri.parse('http://localhost:8080/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      // No If-Match header
      body: jsonEncode(noETagData),
    );

    if (noETagUpdate.statusCode == 200) {
      print('✓ Update without If-Match succeeded (backward compatible)');
      print(
          '  ETag still included in response: ${noETagUpdate.headers['etag']}\n');
    } else {
      print('✗ Update failed: ${noETagUpdate.statusCode}\n');
    }

    print('=== Summary ===');
    print('✓ ETags prevent lost updates from concurrent modifications');
    print('✓ 412 Precondition Failed returned when ETag mismatches');
    print('✓ Current ETag included in 412 response for client retry');
    print('✓ Backward compatible - If-Match header is optional');
  } finally {
    client.close();
  }
}
