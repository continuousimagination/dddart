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
  test('debug Cognito token verification', () async {
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
    print('Token has 3 parts: ${token.split('.').length == 3}');

    // Decode header
    final parts = token.split('.');
    final header = jsonDecode(
      utf8.decode(base64Url.decode(_addBase64Padding(parts[0]))),
    ) as Map<String, dynamic>;
    print('Header: $header');

    // Fetch JWKS
    final response = await http.get(
      Uri.parse(
        'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm/.well-known/jwks.json',
      ),
    );
    final jwks = jsonDecode(response.body) as Map<String, dynamic>;
    final keys = jwks['keys'] as List<dynamic>;
    final key = keys.firstWhere(
      (k) => k['kid'] == header['kid'],
    ) as Map<String, dynamic>;

    print('Found key with kid: ${key['kid']}');
    print('Key type: ${key['kty']}');
    print('Key alg: ${key['alg']}');

    // Generate PEM
    final pem = _jwkToPem(key['n'] as String, key['e'] as String);
    print('\nGenerated PEM (first 100 chars):');
    print(pem.substring(0, 100));

    // Try creating RSAPublicKey
    print('\nCreating RSAPublicKey...');
    try {
      final publicKey = RSAPublicKey(pem);
      print('✓ RSAPublicKey created');
      print('  Type: ${publicKey.runtimeType}');

      // Try verification
      print('\nAttempting verification...');
      print('  Token type: ${token.runtimeType}');
      print('  Token is String: ${token is String}');
      print('  PublicKey type: ${publicKey.runtimeType}');

      // Try with explicit String cast
      final tokenString = token as String;
      print('  After cast - Token type: ${tokenString.runtimeType}');

      // First, try decoding to get a JWT object
      print('\n  Decoding token first...');
      final decodedJwt = JWT.decode(tokenString);
      print('  Decoded JWT type: ${decodedJwt.runtimeType}');
      print('  Decoded JWT is JWT: ${decodedJwt is JWT}');

      try {
        final jwt = JWT.verify(tokenString, publicKey);
        print('✓ Verification succeeded!');
        print('  Payload: ${jwt.payload}');
      } on JWTExpiredException {
        print('⚠ Token expired (this is OK)');
      } on JWTInvalidException catch (e) {
        print('✗ JWTInvalidException: ${e.message}');
        
        // Maybe the issue is that we need to pass the decoded JWT?
        print('\n  Trying to verify the decoded JWT object...');
        try {
          // This probably won't work, but let's try
          final jwt2 = JWT.verify(decodedJwt as dynamic, publicKey);
          print('✓ Verification with decoded JWT succeeded!');
        } catch (e3) {
          print('✗ That did not work either: $e3');
        }
        
        // Check if maybe the issue is with the key
        print('\n  Trying with a fresh RSAPublicKey instance...');
        try {
          final freshKey = RSAPublicKey(pem);
          final jwt2 = JWT.verify(tokenString, freshKey);
          print('✓ Verification with fresh key succeeded!');
        } on JWTInvalidException catch (e2) {
          print('✗ Still failed: ${e2.message}');
        }
        
        // Try JWT.decode to see if token is valid
        try {
          final decoded = JWT.decode(tokenString);
          print('\n  But JWT.decode works fine:');
          print('    Payload: ${decoded.payload}');
          print('    Header: ${decoded.header}');
        } catch (e2) {
          print('  JWT.decode also failed: $e2');
        }
      } catch (e) {
        print('✗ Unexpected error: $e');
        print('  Type: ${e.runtimeType}');
      }
    } catch (e) {
      print('✗ Failed to create RSAPublicKey: $e');
    }
  });
}

String _jwkToPem(String n, String e) {
  final nPadded = _addBase64Padding(n);
  final ePadded = _addBase64Padding(e);

  final nBytes = base64Url.decode(nPadded);
  final eBytes = base64Url.decode(ePadded);

  final modulus = BigInt.parse(
    nBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );
  final exponent = BigInt.parse(
    eBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );

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
  final buffer = StringBuffer(base64url);
  while (buffer.length % 4 != 0) {
    buffer.write('=');
  }
  return buffer.toString();
}
