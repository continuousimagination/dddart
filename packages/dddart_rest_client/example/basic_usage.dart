import 'dart:io';

import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:path/path.dart' as path;

/// Example CLI tool using device flow authentication
void main() async {
  // Create auth provider
  final authProvider = DeviceFlowAuthProvider(
    authUrl: 'https://api.example.com/auth',
    clientId: 'my-cli-app',
    credentialsPath: path.join(
      Platform.environment['HOME']!,
      '.my-app',
      'credentials.json',
    ),
  );

  // Login if not authenticated
  if (!await authProvider.isAuthenticated()) {
    print('Not authenticated. Starting login flow...\n');
    await authProvider.login();
  } else {
    print('Already authenticated!');
  }

  // Create REST client
  final client = RestClient(
    baseUrl: 'https://api.example.com',
    authProvider: authProvider,
  );

  try {
    // Make authenticated requests
    print('\nFetching users...');
    final response = await client.get('/users');
    print('Response: ${response.statusCode}');
    print(response.body);

    // Create a new user
    print('\nCreating user...');
    final createResponse = await client.post(
      '/users',
      body: {'name': 'Alice', 'email': 'alice@example.com'},
    );
    print('Response: ${createResponse.statusCode}');
    print(createResponse.body);
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }

  // Logout (optional)
  print('\nLogout? (y/n)');
  final input = stdin.readLineSync();
  if (input?.toLowerCase() == 'y') {
    await authProvider.logout();
    print('Logged out successfully!');
  }
}
