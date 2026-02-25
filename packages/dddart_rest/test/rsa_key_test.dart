import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  test('test RSAPublicKey constructors', () {
    final pem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu80jTdiX7LaGqicP7g0F
W6g4REPl1BIpIH7Elzk/NpvqN0t+zIEBmjTaGWEImskK7s9m6Wnflq6eRSeJKrYN
BlDmuDaaRSJVeF3JoClo6K6x4syjlSbW9Wfh2eOzZl4onzQvDX0UvTEm+VqyVuY/
8RonkCYyuz4SDhFM89KiLDtB08Jc2xedtDXQH1TsTTiC2oxfdUWmzab9zJaKHQi7
T1jREviNX0n3th8TA0jmAZME085z+zHIY8D+FCDRXM9H9f13c8aozkzWBWcCoX2K
orGVl0hg0X4TH2t+aZsvWz1bOQxyLt6ASvU9dwTI2O2ggMDErXPyd3mD8bxNjA5h
LQIDAQAB
-----END PUBLIC KEY-----''';

    print('Testing RSAPublicKey constructor...');
    try {
      final key1 = RSAPublicKey(pem);
      print('✓ RSAPublicKey(pem) works');
      print('  Type: ${key1.runtimeType}');
      print('  toString: ${key1.toString()}');
    } catch (e) {
      print('✗ RSAPublicKey(pem) failed: $e');
    }

    // Check if there are other constructors
    print('\nChecking RSAPublicKey type...');
    final key = RSAPublicKey(pem);
    print('  key is JWTKey: ${key is JWTKey}');
    print('  key.runtimeType: ${key.runtimeType}');
    
    // Try to see what methods/properties are available
    print('\nTrying to inspect key...');
    try {
      print('  key.toString(): ${key.toString().length} chars');
    } catch (e) {
      print('  toString() failed: $e');
    }
  });
}
