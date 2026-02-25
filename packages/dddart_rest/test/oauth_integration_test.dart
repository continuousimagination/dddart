import 'dart:convert';
import 'dart:io';
import 'package:dddart_rest/src/oauth_jwt_auth_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('OAuthJwtAuthHandler with real Cognito token', () async {
    // Read token
    final credFile = File('/tmp/silly-sentence-game-player1-credentials.json');
    if (!await credFile.exists()) {
      print('Credentials file not found - skipping test');
      return;
    }

    final credJson =
        jsonDecode(await credFile.readAsString()) as Map<String, dynamic>;
    final token = (credJson['id_token'] as String).trim();

    // Create auth handler
    final authHandler = OAuthJwtAuthHandler<Map<String, dynamic>>(
      jwksUri:
          'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm/.well-known/jwks.json',
      parseClaimsFromJson: (json) => json,
      issuer:
          'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm',
      audience: '5odo6bfe2reikrdjieu1f1b060',
    );

    // Create request with token
    final request = Request(
      'GET',
      Uri.parse('http://localhost/test'),
      headers: {'authorization': 'Bearer $token'},
    );

    // Authenticate
    print('Authenticating with Cognito token...');
    final result = await authHandler.authenticate(request);

    if (result.isAuthenticated) {
      print('✓ Authentication succeeded!');
      print('  User ID: ${result.userId}');
      print('  Claims: ${result.claims}');
    } else {
      print('✗ Authentication failed: ${result.errorMessage}');
    }

    expect(result.isAuthenticated, isTrue);
    expect(result.userId, equals('04d8c4f8-80d1-70a7-74c8-82dc165d9d91'));
  });
}
