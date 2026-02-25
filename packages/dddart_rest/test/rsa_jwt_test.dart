import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  test('test JWT.verify with string token', () {
    // Create a simple HMAC token first to test the API
    final jwt = JWT({'sub': 'test-user'});
    final token = jwt.sign(SecretKey('secret'));
    
    print('HMAC Token: $token');
    print('Token type: ${token.runtimeType}');
    print('Token is String: ${token is String}');
    
    // Verify with string
    try {
      final verified = JWT.verify(token, SecretKey('secret'));
      print('✓ HMAC verification succeeded');
      print('  Payload: ${verified.payload}');
    } catch (e) {
      print('✗ HMAC verification failed: $e');
    }
    
    // Now test what happens if we pass something that's not a string
    print('\nTesting with non-string:');
    try {
      final verified = JWT.verify(123 as dynamic, SecretKey('secret'));
      print('✓ Verification succeeded (unexpected)');
    } on JWTInvalidException catch (e) {
      print('✓ Got JWTInvalidException as expected: ${e.message}');
    } catch (e) {
      print('✗ Got unexpected error: $e');
    }
    
    // Test with a token that has extra whitespace
    print('\nTesting with whitespace:');
    final tokenWithSpace = ' $token ';
    try {
      final verified = JWT.verify(tokenWithSpace, SecretKey('secret'));
      print('✓ Verification with whitespace succeeded');
    } on JWTInvalidException catch (e) {
      print('Got JWTInvalidException: ${e.message}');
    } catch (e) {
      print('Got error: $e');
    }
    
    // Test with token that has newline
    print('\nTesting with newline:');
    final tokenWithNewline = '$token\n';
    try {
      final verified = JWT.verify(tokenWithNewline, SecretKey('secret'));
      print('✓ Verification with newline succeeded');
    } on JWTInvalidException catch (e) {
      print('Got JWTInvalidException: ${e.message}');
    } catch (e) {
      print('Got error: $e');
    }
  });
}
