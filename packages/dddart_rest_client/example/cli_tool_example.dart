// Example: Complete CLI tool with device flow authentication
//
// This example demonstrates:
// - Building a CLI tool with device flow authentication
// - Automatic token management and refresh
// - Credential storage in user's home directory
// - Making authenticated API requests
// - Error handling
//
// Run: dart run example/cli_tool_example.dart <command>
// Commands: login, logout, list-users, get-user, create-user, me

import 'dart:io';
import 'dart:convert';
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(1);
  }

  final command = args[0];
  final cli = UserCLI();

  try {
    switch (command) {
      case 'login':
        await cli.login();
      case 'logout':
        await cli.logout();
      case 'list-users':
        await cli.listUsers();
      case 'get-user':
        if (args.length < 2) {
          print('Usage: cli_tool_example get-user <user-id>');
          exit(1);
        }
        await cli.getUser(args[1]);
      case 'create-user':
        if (args.length < 3) {
          print('Usage: cli_tool_example create-user <username> <email>');
          exit(1);
        }
        await cli.createUser(args[1], args[2]);
      case 'me':
        await cli.getCurrentUser();
      case 'help':
        _printUsage();
      default:
        print('Unknown command: $command');
        _printUsage();
        exit(1);
    }
  } on AuthenticationException catch (e) {
    print('❌ Authentication error: ${e.message}');
    print('Run "dart run example/cli_tool_example.dart login" to authenticate');
    exit(1);
  } on HttpException catch (e) {
    print('❌ Network error: $e');
    exit(1);
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    if (Platform.environment['DEBUG'] == 'true') {
      print(stackTrace);
    }
    exit(1);
  }
}

void _printUsage() {
  print('User Management CLI Tool');
  print('');
  print('Usage: dart run example/cli_tool_example.dart <command> [args]');
  print('');
  print('Commands:');
  print('  login                      Login with device flow');
  print('  logout                     Logout and clear credentials');
  print('  list-users                 List all users');
  print('  get-user <id>              Get user by ID');
  print('  create-user <name> <email> Create a new user');
  print('  me                         Get current user info');
  print('  help                       Show this help message');
  print('');
  print('Examples:');
  print('  dart run example/cli_tool_example.dart login');
  print('  dart run example/cli_tool_example.dart list-users');
  print('  dart run example/cli_tool_example.dart create-user alice alice@example.com');
  print('  dart run example/cli_tool_example.dart me');
}

class UserCLI {
  late final DeviceFlowAuthProvider authProvider;
  late final RestClient client;

  UserCLI() {
    // Configuration - change these to match your API
    const apiUrl = 'http://localhost:8080';
    const authUrl = '$apiUrl/auth';
    const clientId = 'user-cli-tool';

    // Store credentials in user's home directory
    final credentialsPath = _getCredentialsPath();

    authProvider = DeviceFlowAuthProvider(
      authUrl: authUrl,
      clientId: clientId,
      credentialsPath: credentialsPath,
    );

    client = RestClient(
      baseUrl: apiUrl,
      authProvider: authProvider,
    );
  }

  String _getCredentialsPath() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

    if (home == null) {
      throw Exception('Cannot determine home directory');
    }

    final configDir = path.join(home, '.user-cli');

    // Create directory if it doesn't exist
    Directory(configDir).createSync(recursive: true);

    return path.join(configDir, 'credentials.json');
  }

  Future<void> login() async {
    print('🔐 Logging in...\n');

    if (await authProvider.isAuthenticated()) {
      print('Already logged in!');
      print('Run "logout" first if you want to login with a different account.');
      return;
    }

    await authProvider.login();
    print('\n✓ Successfully authenticated!');
    print('You can now use other commands.');
  }

  Future<void> logout() async {
    print('👋 Logging out...');

    if (!await authProvider.isAuthenticated()) {
      print('Not logged in.');
      return;
    }

    await authProvider.logout();
    print('✓ Logged out successfully');
  }

  Future<void> listUsers() async {
    print('📋 Fetching users...\n');

    final response = await client.get('/users');

    if (response.statusCode == 200) {
      final users = jsonDecode(response.body) as List;

      if (users.isEmpty) {
        print('No users found.');
        return;
      }

      print('Users (${users.length}):');
      for (final user in users) {
        print('  • ${user['username']} (${user['email']}) - ID: ${user['id']}');
      }
    } else {
      _handleErrorResponse(response);
    }
  }

  Future<void> getUser(String userId) async {
    print('🔍 Fetching user $userId...\n');

    final response = await client.get('/users/$userId');

    if (response.statusCode == 200) {
      final user = jsonDecode(response.body) as Map<String, dynamic>;
      _printUser(user);
    } else {
      _handleErrorResponse(response);
    }
  }

  Future<void> createUser(String username, String email) async {
    print('➕ Creating user...\n');

    final response = await client.post(
      '/users',
      body: {
        'username': username,
        'email': email,
        'passwordHash': 'changeme', // In production, handle passwords properly
        'roles': ['user'],
      },
    );

    if (response.statusCode == 201) {
      final user = jsonDecode(response.body) as Map<String, dynamic>;
      print('✓ User created successfully!\n');
      _printUser(user);
    } else {
      _handleErrorResponse(response);
    }
  }

  Future<void> getCurrentUser() async {
    print('👤 Fetching current user info...\n');

    final response = await client.get('/users?me');

    if (response.statusCode == 200) {
      final users = jsonDecode(response.body) as List;

      if (users.isEmpty) {
        print('User not found.');
        return;
      }

      final user = users[0] as Map<String, dynamic>;
      print('Current User:');
      _printUser(user);
    } else {
      _handleErrorResponse(response);
    }
  }

  void _printUser(Map<String, dynamic> user) {
    print('  ID:       ${user['id']}');
    print('  Username: ${user['username']}');
    print('  Email:    ${user['email']}');
    if (user['roles'] != null) {
      print('  Roles:    ${(user['roles'] as List).join(', ')}');
    }
    if (user['createdAt'] != null) {
      print('  Created:  ${user['createdAt']}');
    }
  }

  void _handleErrorResponse(dynamic response) {
    print('❌ Request failed (${response.statusCode})');

    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      if (error['detail'] != null) {
        print('   ${error['detail']}');
      } else {
        print('   ${response.body}');
      }
    } catch (e) {
      print('   ${response.body}');
    }
  }
}
