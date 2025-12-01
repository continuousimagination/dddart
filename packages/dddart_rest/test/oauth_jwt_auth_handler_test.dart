import 'dart:convert';

import 'package:dddart_rest/src/oauth_jwt_auth_handler.dart';
import 'package:dddart_rest/src/standard_claims.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('OAuthJwtAuthHandler', () {
    // Helper function to create a mock JWKS response
    Map<String, dynamic> createMockJwks() {
      return {
        'keys': [
          {
            'kty': 'RSA',
            'kid': 'test-key-id',
            'use': 'sig',
            'alg': 'RS256',
            'n': 'test-modulus',
            'e': 'AQAB',
          }
        ],
      };
    }

    group('authenticate - basic validation', () {
      test('should return failure when Authorization header is missing',
          () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        final request = Request('GET', Uri.parse('http://localhost/test'));

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Missing authorization header'));
      });

      test('should return failure when token format is invalid', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'InvalidFormat token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Invalid token format'));
      });

      test('should return failure when token has wrong number of parts',
          () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer invalid.token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Invalid token format'));
      });

      test('should return failure when token is missing kid', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        // Create a JWT-like token without kid in header
        final header = base64Url
            .encode(utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})));
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Token missing key ID'));
      });
    });

    group('JWKS fetching and caching', () {
      test('should fetch JWKS from provider', () async {
        var jwksFetchCount = 0;
        final mockClient = MockClient((request) async {
          jwksFetchCount++;
          expect(request.url.toString(),
              equals('https://example.com/.well-known/jwks.json'),);
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        // Create a token with kid
        final header = base64Url.encode(utf8.encode(
            jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),),);
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        // This will fail signature verification, but should fetch JWKS
        await authHandler.authenticate(request);

        expect(jwksFetchCount, equals(1));
      });

      test('should cache JWKS and not refetch on subsequent requests',
          () async {
        var jwksFetchCount = 0;
        final mockClient = MockClient((request) async {
          jwksFetchCount++;
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        // Create a token with kid
        final header = base64Url.encode(utf8.encode(
            jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),),);
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        // First request - should fetch JWKS
        var request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        await authHandler.authenticate(request);
        expect(jwksFetchCount, equals(1));

        // Second request - should use cached JWKS
        request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        await authHandler.authenticate(request);
        expect(jwksFetchCount, equals(1)); // Still 1, not 2
      });

      test('should refetch JWKS after cache expiration', () async {
        var jwksFetchCount = 0;
        final mockClient = MockClient((request) async {
          jwksFetchCount++;
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
          cacheDuration: const Duration(milliseconds: 100),
        );

        // Create a token with kid
        final header = base64Url.encode(utf8.encode(
            jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),),);
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        // First request - should fetch JWKS
        var request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        await authHandler.authenticate(request);
        expect(jwksFetchCount, equals(1));

        // Wait for cache to expire
        await Future.delayed(const Duration(milliseconds: 150));

        // Second request - should refetch JWKS
        request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        await authHandler.authenticate(request);
        expect(jwksFetchCount, equals(2)); // Refetched
      });

      test('should return failure when JWKS fetch fails', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        // Create a token with kid
        final header = base64Url.encode(utf8.encode(
            jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),),);
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, contains('Invalid token'));
      });

      test('should return failure when no matching key found in JWKS',
          () async {
        final mockClient = MockClient((request) async {
          // Return JWKS with different kid
          return http.Response(
            jsonEncode({
              'keys': [
                {
                  'kty': 'RSA',
                  'kid': 'different-key-id',
                  'use': 'sig',
                  'alg': 'RS256',
                  'n': 'some-modulus',
                  'e': 'AQAB',
                }
              ],
            }),
            200,
          );
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        // Create a token with kid that doesn't match
        final header = base64Url.encode(utf8.encode(
            jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),),);
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('No matching key found for token'));
      });

      test('should return failure when JWKS has no keys', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'keys': []}), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          httpClient: mockClient,
        );

        // Create a token with kid
        final header = base64Url.encode(utf8.encode(
            jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),),);
        final payload =
            base64Url.encode(utf8.encode(jsonEncode({'sub': 'user123'})));
        final signature = base64Url.encode(utf8.encode('fake-signature'));
        final token = '$header.$payload.$signature';

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer $token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('No keys found in JWKS'));
      });
    });

    group('configuration', () {
      test('should accept issuer configuration', () {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          issuer: 'https://expected-issuer.com',
          httpClient: mockClient,
        );

        expect(authHandler.issuer, equals('https://expected-issuer.com'));
      });

      test('should accept audience configuration', () {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          audience: 'expected-client-id',
          httpClient: mockClient,
        );

        expect(authHandler.audience, equals('expected-client-id'));
      });

      test('should accept custom cache duration', () {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(createMockJwks()), 200);
        });

        final authHandler = OAuthJwtAuthHandler<StandardClaims>(
          jwksUri: 'https://example.com/.well-known/jwks.json',
          parseClaimsFromJson: StandardClaims.fromJson,
          cacheDuration: const Duration(hours: 24),
          httpClient: mockClient,
        );

        expect(authHandler.cacheDuration, equals(const Duration(hours: 24)));
      });
    });
  });
}
