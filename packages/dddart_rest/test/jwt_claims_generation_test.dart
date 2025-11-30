import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

void main() {
  group('JWT Claims Generation', () {
    test('StandardClaims extension methods are generated', () {
      // This test verifies that the code generation worked correctly
      // by checking that we can use the generated extension methods

      // Create a mock JWT auth handler (we'll implement the real one later)
      final handler = _MockJwtAuthHandler();

      // Test parseClaimsFromJson
      final json = {
        'sub': 'user123',
        'email': 'test@example.com',
        'name': 'Test User',
      };

      final claims = handler.parseClaimsFromJson(json);
      expect(claims.sub, equals('user123'));
      expect(claims.email, equals('test@example.com'));
      expect(claims.name, equals('Test User'));

      // Test claimsToJson
      const claimsToSerialize = StandardClaims(
        sub: 'user456',
        email: 'another@example.com',
        name: 'Another User',
      );

      final serialized = handler.claimsToJson(claimsToSerialize);
      expect(serialized['sub'], equals('user456'));
      expect(serialized['email'], equals('another@example.com'));
      expect(serialized['name'], equals('Another User'));
    });

    test('StandardClaims handles null optional fields', () {
      final handler = _MockJwtAuthHandler();

      // Test with null optional fields
      final json = {
        'sub': 'user789',
      };

      final claims = handler.parseClaimsFromJson(json);
      expect(claims.sub, equals('user789'));
      expect(claims.email, isNull);
      expect(claims.name, isNull);

      // Test serialization with null fields
      const claimsToSerialize = StandardClaims(sub: 'user000');
      final serialized = handler.claimsToJson(claimsToSerialize);
      expect(serialized['sub'], equals('user000'));
      expect(serialized.containsKey('email'), isFalse);
      expect(serialized.containsKey('name'), isFalse);
    });
  });
}

// Mock implementation for testing
class _MockJwtAuthHandler extends JwtAuthHandler<StandardClaims, RefreshToken> {
  _MockJwtAuthHandler()
      : super(
          secret: 'test-secret',
          refreshTokenRepository: InMemoryRepository<RefreshToken>(),
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
        );
}
