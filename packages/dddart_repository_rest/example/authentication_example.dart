/// Authentication example for dddart_repository_rest.
///
/// This example demonstrates:
/// - Setting up a REST connection with authentication
/// - Using an AuthProvider for token management
/// - Making authenticated requests
/// - Handling authentication errors
///
/// To run this example, you need a REST API server with authentication
/// running at http://localhost:8080.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';

import 'lib/user.dart';

/// Example AuthProvider that provides a static token.
///
/// In a real application, this would:
/// - Authenticate with the server
/// - Store and refresh tokens
/// - Handle token expiration
class ExampleAuthProvider implements AuthProvider {
  ExampleAuthProvider(this._token);

  final String _token;

  @override
  Future<String> getAccessToken() async {
    // In a real app, this might:
    // 1. Check if the current token is expired
    // 2. Refresh the token if needed
    // 3. Return the valid access token
    return _token;
  }

  @override
  Future<void> login() async {
    // In a real app, this would initiate the login flow
    print('   (Login flow would happen here)');
  }

  @override
  Future<void> logout() async {
    // In a real app, this would clear credentials
    print('   (Logout would happen here)');
  }

  @override
  Future<bool> isAuthenticated() async {
    // In a real app, check if we have valid credentials
    return _token.isNotEmpty;
  }
}

/// Example of using device flow authentication.
///
/// This is useful for CLI tools and applications without a browser.
class DeviceFlowAuthExample {
  static Future<void> run() async {
    print('=== Device Flow Authentication Example ===\n');

    // Create a device flow auth provider
    final authProvider = DeviceFlowAuthProvider(
      authUrl: 'https://api.example.com/auth',
      clientId: 'your-client-id',
      credentialsPath: '.credentials.json',
    );

    print('1. Initiating device flow authentication...');
    print('   Please visit the URL displayed and enter the code.\n');

    try {
      // This will display the verification URL and user code
      // The user needs to visit the URL and enter the code
      // The method will poll until the user completes authentication
      await authProvider.login();
      print('   ✓ Authentication successful!\n');

      // Create connection with authenticated provider
      final connection = RestConnection(
        baseUrl: 'http://localhost:8080',
        authProvider: authProvider,
      );

      final userRepository = UserRestRepository(connection);

      // Now all requests will include the authentication token
      print('2. Making authenticated request...');
      final user = User(
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane.doe@example.com',
      );

      await userRepository.save(user);
      print('   ✓ User created with authentication: ${user.fullName}\n');

      connection.dispose();
    } on AuthenticationException catch (e) {
      print('   ✗ Authentication failed: ${e.message}');
    }
  }
}

Future<void> main() async {
  print('=== Authentication Example ===\n');

  // Example 1: Static token authentication
  print('Example 1: Static Token Authentication\n');

  // In a real application, you would obtain this token through
  // an authentication flow (OAuth, JWT, etc.)
  final authProvider = ExampleAuthProvider('your-api-token-here');

  // Create a REST connection with authentication
  final connection = RestConnection(
    baseUrl: 'http://localhost:8080',
    authProvider: authProvider,
  );

  final userRepository = UserRestRepository(connection);

  try {
    print('1. Creating user with authenticated request...');
    final user = User(
      firstName: 'Alice',
      lastName: 'Johnson',
      email: 'alice.johnson@example.com',
    );

    // This request will automatically include the Authorization header
    // with the token from the AuthProvider
    await userRepository.save(user);
    print('   ✓ User created: ${user.fullName}');
    print('   ID: ${user.id}\n');

    print('2. Retrieving user with authenticated request...');
    final retrievedUser = await userRepository.getById(user.id);
    print('   ✓ User retrieved: ${retrievedUser.fullName}\n');

    print('3. Deleting user...');
    await userRepository.deleteById(user.id);
    print('   ✓ User deleted\n');

    print('=== Example 1 completed successfully! ===\n');
  } on RepositoryException catch (e) {
    if (e.type == RepositoryExceptionType.connection) {
      print('\n✗ Connection error (possibly authentication failure)');
      print('  Message: ${e.message}');
      print('  Make sure your token is valid and the server is running.');
    } else {
      print('\n✗ Repository error: ${e.message}');
      print('  Type: ${e.type}');
    }
  } catch (e) {
    print('\n✗ Unexpected error: $e');
  } finally {
    connection.dispose();
  }

  // Example 2: Device flow authentication (commented out)
  // Uncomment to try device flow authentication
  // await DeviceFlowAuthExample.run();

  print('\n=== Authentication Examples Complete ===');
  print('\nKey Points:');
  print('- AuthProvider handles token management automatically');
  print('- All repository operations include authentication headers');
  print('- Token refresh happens transparently when needed');
  print('- Authentication errors are mapped to RepositoryException');
}
