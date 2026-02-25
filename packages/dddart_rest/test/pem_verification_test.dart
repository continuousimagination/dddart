import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asn1/primitives/asn1_bit_string.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_null.dart';
import 'package:pointycastle/asn1/primitives/asn1_object_identifier.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:test/test.dart';

void main() {
  test('verify PEM generation and JWT verification with real Cognito key',
      () async {
    // Fetch JWKS from Cognito
    final response = await http.get(
      Uri.parse(
        'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm/.well-known/jwks.json',
      ),
    );

    expect(response.statusCode, equals(200));

    final jwks = jsonDecode(response.body) as Map<String, dynamic>;
    final keys = jwks['keys'] as List<dynamic>;

    // Find the key
    final key = keys.firstWhere(
      (k) =>
          k['kid'] == '1NJLVIpov771+nmbt4hbWicx3hvd7Nkoo7qiS5WNrpE=',
    ) as Map<String, dynamic>;

    final n = key['n'] as String;
    final e = key['e'] as String;

    // Convert to PEM
    final pem = _jwkToPem(n, e);

    print('Generated PEM:');
    print(pem);
    print('');

    // Try to create RSAPublicKey from PEM
    try {
      final publicKey = RSAPublicKey(pem);
      print('✓ RSAPublicKey created successfully');
      print('  Type: ${publicKey.runtimeType}');

      // Now try to verify a real token
      final credFile = File('/tmp/silly-sentence-game-player1-credentials.json');
      if (await credFile.exists()) {
        final credJson =
            jsonDecode(await credFile.readAsString()) as Map<String, dynamic>;
        final token = credJson['id_token'] as String?;

        if (token != null) {
          print('');
          print('Token info:');
          print('  Length: ${token.length}');
          print('  Parts: ${token.split('.').length}');
          final tokenTrimmed = token.trim();
          print('  Trimmed length: ${tokenTrimmed.length}');
          print('  Has newlines: ${token.contains('\n')}');
          print('  First 50 chars: ${token.substring(0, 50)}');
          print('');
          
          // Try creating a new RSAPublicKey directly from the PEM
          print('Creating fresh RSAPublicKey from PEM...');
          final freshPublicKey = RSAPublicKey(pem);
          print('✓ Fresh RSAPublicKey created');
          
          print('');
          print('Attempting to verify real token...');
          
          // First, let's check the token header
          try {
            final parts = tokenTrimmed.split('.');
            final header = jsonDecode(
              utf8.decode(base64Url.decode(_addBase64Padding(parts[0]))),
            );
            print('Token header: $header');
            print('  alg: ${header['alg']}');
            print('  kid: ${header['kid']}');
          } catch (e) {
            print('Could not decode header: $e');
          }
          
          try {
            // Try with the fresh publicKey
            print('Trying JWT.verify(tokenTrimmed, freshPublicKey)...');
            final jwt = JWT.verify(tokenTrimmed, freshPublicKey);
            print('✓ Token verified successfully!');
            print('  Subject: ${jwt.payload['sub']}');
          } on JWTExpiredException {
            print('⚠ Token is expired (expected)');
          } on JWTInvalidException catch (e) {
            print('✗ JWTInvalidException: ${e.message}');
            print('  Error type: ${e.runtimeType}');
            
            // The "not a jwt" error might mean the token string itself is invalid
            // Let's check if there are any hidden characters
            print('  Token bytes: ${tokenTrimmed.codeUnits.take(20).toList()}');
            print('  Token runes: ${tokenTrimmed.runes.take(20).toList()}');
            
            // Try to decode without verification
            try {
              final parts = tokenTrimmed.split('.');
              final payload = jsonDecode(
                utf8.decode(base64Url.decode(_addBase64Padding(parts[1]))),
              );
              print('  Token payload (decoded without verification):');
              print('    sub: ${payload['sub']}');
              print('    exp: ${payload['exp']}');
              print('    iss: ${payload['iss']}');
            } catch (e2) {
              print('  Could not decode payload: $e2');
            }
          } on JWTException catch (e) {
            print('✗ JWT verification failed: ${e.message}');
            print('  Error type: ${e.runtimeType}');
            print('  publicKey type: ${freshPublicKey.runtimeType}');
            print('  Stack trace:');
            print(StackTrace.current);
            
            // Try to decode without verification
            try {
              final parts = tokenTrimmed.split('.');
              final payload = jsonDecode(
                utf8.decode(base64Url.decode(_addBase64Padding(parts[1]))),
              );
              print('  Token payload (decoded without verification):');
              print('    sub: ${payload['sub']}');
              print('    exp: ${payload['exp']}');
              print('    iss: ${payload['iss']}');
              print('    alg from header should match key type');
            } catch (e2) {
              print('  Could not decode payload: $e2');
            }
          } catch (e) {
            print('✗ Unexpected error: $e');
            print('  Error type: ${e.runtimeType}');
          }
        }
      }
    } catch (e) {
      print('✗ Failed to create RSAPublicKey: $e');
      rethrow;
    }
  });
}

String _jwkToPem(String n, String e) {
  // Add padding
  final nPadded = _addBase64Padding(n);
  final ePadded = _addBase64Padding(e);

  final nBytes = base64Url.decode(nPadded);
  final eBytes = base64Url.decode(ePadded);

  // Convert bytes to BigInt
  final modulus = BigInt.parse(
    nBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  final exponent = BigInt.parse(
    eBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );

  // Build ASN.1 structure
  final rsaPublicKey = ASN1Sequence();
  rsaPublicKey.add(ASN1Integer(modulus));
  rsaPublicKey.add(ASN1Integer(exponent));

  final rsaPublicKeyBytes = rsaPublicKey.encode();
  final bitString = ASN1BitString(stringValues: rsaPublicKeyBytes);

  final algorithmSeq = ASN1Sequence();
  algorithmSeq.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
  algorithmSeq.add(ASN1Null());

  final topLevelSeq = ASN1Sequence();
  topLevelSeq.add(algorithmSeq);
  topLevelSeq.add(bitString);

  final derBytes = topLevelSeq.encode();
  final base64Der = base64.encode(derBytes);

  final buffer = StringBuffer();
  buffer.writeln('-----BEGIN PUBLIC KEY-----');

  var offset = 0;
  while (offset < base64Der.length) {
    final end =
        (offset + 64 < base64Der.length) ? offset + 64 : base64Der.length;
    buffer.writeln(base64Der.substring(offset, end));
    offset += 64;
  }

  buffer.write('-----END PUBLIC KEY-----');

  return buffer.toString();
}

String _addBase64Padding(String base64url) {
  var padded = base64url;
  while (padded.length % 4 != 0) {
    padded += '=';
  }
  return padded;
}
