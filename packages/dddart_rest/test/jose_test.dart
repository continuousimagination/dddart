import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:test/test.dart';

void main() {
  test('verify Cognito token with jose package', () async {
    // Read token
    final credFile = File('/tmp/silly-sentence-game-player1-credentials.json');
    if (!await credFile.exists()) {
      print('Credentials file not found');
      return;
    }

    final credJson =
        jsonDecode(await credFile.readAsString()) as Map<String, dynamic>;
    final token = (credJson['id_token'] as String).trim();

    print('Token length: ${token.length}');

    // Fetch JWKS
    final response = await http.get(
      Uri.parse(
        'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm/.well-known/jwks.json',
      ),
    );
    final jwks = jsonDecode(response.body) as Map<String, dynamic>;

    print('Creating JsonWebKeyStore from JWKS...');
    final keyStore = JsonWebKeyStore()
      ..addKeySetUrl(
        Uri.parse(
          'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm/.well-known/jwks.json',
        ),
      );

    print('Parsing JWT...');
    try {
      final jwt = JsonWebToken.unverified(token);
      print('✓ JWT parsed');
      print('  Claims: ${jwt.claims}');

      print('\nVerifying JWT...');
      final verified = await jwt.verify(keyStore);
      if (verified) {
        print('✓ JWT verified successfully!');
        print('  Claims: ${jwt.claims}');
      } else {
        print('✗ JWT verification failed');
      }
    } on JoseException catch (e) {
      print('✗ Jose exception: $e');
    } catch (e) {
      print('✗ Unexpected error: $e');
      print('  Type: ${e.runtimeType}');
    }
  });
}
