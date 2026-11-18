import 'dart:io';

import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';

import 'lib/user.dart';

/// Uses a token issued by the example API. The caller owns token renewal.
class EnvironmentAuthProvider implements AuthProvider {
  String? _token;

  @override
  Future<void> login() async {
    final token = Platform.environment['EXAMPLE_API_TOKEN'];
    if (token == null || token.isEmpty) {
      throw AuthenticationException('Set EXAMPLE_API_TOKEN to a valid token.');
    }
    _token = token;
  }

  @override
  Future<String> getIdToken() async =>
      _token ?? (throw AuthenticationException('Call login first.'));

  @override
  Future<String> getAccessToken() => getIdToken();

  @override
  Future<bool> isAuthenticated() async => _token != null;

  @override
  Future<void> logout() async {
    _token = null;
  }
}

Future<void> main() async {
  final provider = EnvironmentAuthProvider();
  await provider.login();
  final connection = RestConnection(
    baseUrl: 'http://localhost:8080',
    authProvider: provider,
  );
  try {
    final users = UserRestRepository(connection);
    final user = User(
      firstName: 'Alice',
      lastName: 'Johnson',
      email: 'alice@example.com',
    );
    await users.save(user);
    final loaded = await users.getById(user.id);
    print('Authenticated read: ${loaded.fullName}');
    await users.deleteById(user.id);
  } finally {
    connection.dispose();
    await provider.logout();
  }
}
