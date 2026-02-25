import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  test('simple JWT sign and verify with HMAC', () {
    // Create a simple JWT
    final jwt = JWT({'sub': 'test-user', 'name': 'Test User'});
    
    // Sign with HMAC
    final token = jwt.sign(SecretKey('my-secret'));
    
    print('Token: $token');
    print('Token length: ${token.length}');
    print('Token parts: ${token.split('.').length}');
    
    // Verify
    try {
      final verified = JWT.verify(token, SecretKey('my-secret'));
      print('✓ Verified successfully');
      print('  Payload: ${verified.payload}');
    } catch (e) {
      print('✗ Verification failed: $e');
      rethrow;
    }
  });
}
