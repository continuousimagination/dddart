import 'dart:convert';

import 'package:dddart_rest/dddart_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('OAuthJwtAuthHandler', () {
    const issuer = 'https://issuer.example.com';
    const audience = 'test-client';
    const keyId = 'auth-003-test-key';
    final jwksUri = Uri.parse('$issuer/.well-known/jwks.json');

    late JsonWebKey signingKey;
    late JsonWebKey alternateSigningKey;
    late String jwksBody;

    setUpAll(() {
      JsonWebKey keyPairWithId() {
        final generatedKey = JsonWebKey.generate(
          'RS256',
          keyBitLength: 2048,
        );
        return JsonWebKey.fromCryptoKeys(
          publicKey: generatedKey.cryptoKeyPair.publicKey,
          privateKey: generatedKey.cryptoKeyPair.privateKey,
          keyId: keyId,
        );
      }

      signingKey = keyPairWithId();
      alternateSigningKey = keyPairWithId();
      final verificationKey = JsonWebKey.fromCryptoKeys(
        publicKey: signingKey.cryptoKeyPair.publicKey,
        keyId: keyId,
      );
      jwksBody = jsonEncode(
        JsonWebKeySet.fromKeys([verificationKey]).toJson(),
      );
    });

    int epochSeconds(DateTime value) =>
        value.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

    String signToken(
      Map<String, dynamic> claims, {
      JsonWebKey? key,
    }) {
      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims
        ..setProtectedHeader('typ', 'JWT')
        ..addRecipient(key ?? signingKey, algorithm: 'RS256');
      return builder.build().toCompactSerialization();
    }

    Future<AuthenticationResult<Map<String, dynamic>>> authenticate(
      Map<String, dynamic> claims, {
      Duration clockSkewTolerance = Duration.zero,
      JsonWebKey? key,
    }) async {
      final token = signToken(claims, key: key);
      final handler = OAuthJwtAuthHandler<Map<String, dynamic>>(
        jwksUri: jwksUri.toString(),
        issuer: issuer,
        audience: audience,
        clockSkewTolerance: clockSkewTolerance,
        parseClaimsFromJson: Map<String, dynamic>.from,
      );
      final request = Request(
        'GET',
        Uri.parse('https://api.example.com/protected'),
        headers: {'authorization': 'Bearer $token'},
      );
      final loader = DefaultJsonWebKeySetLoader(
        httpClient: MockClient((request) async {
          expect(request.url, jwksUri);
          return http.Response(
            jwksBody,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      return JsonWebKeySetLoader.runZoned(
        () => handler.authenticate(request),
        loader: loader,
      );
    }

    Map<String, dynamic> validClaims({
      DateTime? expiresAt,
      DateTime? notBefore,
      Object? tokenAudience = audience,
      String tokenIssuer = issuer,
    }) {
      final now = DateTime.now();
      return {
        'sub': 'user-123',
        'iss': tokenIssuer,
        'aud': tokenAudience,
        'email': 'user@example.com',
        'exp': epochSeconds(expiresAt ?? now.add(const Duration(minutes: 5))),
        if (notBefore != null) 'nbf': epochSeconds(notBefore),
      };
    }

    test('accepts a valid JWKS-backed token and returns its claims', () async {
      final result = await authenticate(validClaims());

      expect(result.isAuthenticated, isTrue);
      expect(result.userId, 'user-123');
      expect(result.claims?['email'], 'user@example.com');
    });

    test('accepts a matching audience in an audience list', () async {
      final result = await authenticate(
        validClaims(tokenAudience: ['another-client', audience]),
      );

      expect(result.isAuthenticated, isTrue);
    });

    test('rejects an expired token with zero default clock skew', () async {
      final result = await authenticate(
        validClaims(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      );

      expect(result.isAuthenticated, isFalse);
      expect(result.errorMessage, 'Token has expired');
    });

    test('rejects a token whose not-before time is in the future', () async {
      final result = await authenticate(
        validClaims(
          notBefore: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );

      expect(result.isAuthenticated, isFalse);
      expect(result.errorMessage, 'Token is not yet valid');
    });

    test('accepts an expired token inside the configured skew window',
        () async {
      final result = await authenticate(
        validClaims(
          expiresAt: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
        clockSkewTolerance: const Duration(minutes: 1),
      );

      expect(result.isAuthenticated, isTrue);
    });

    test('accepts a future not-before time inside the configured skew window',
        () async {
      final result = await authenticate(
        validClaims(
          notBefore: DateTime.now().add(const Duration(seconds: 30)),
        ),
        clockSkewTolerance: const Duration(minutes: 1),
      );

      expect(result.isAuthenticated, isTrue);
    });

    test('preserves issuer error precedence over expiration', () async {
      final result = await authenticate(
        validClaims(
          tokenIssuer: 'https://other-issuer.example.com',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      );

      expect(result.isAuthenticated, isFalse);
      expect(result.errorMessage, 'Invalid token issuer');
    });

    test('preserves audience error precedence over not-before', () async {
      final result = await authenticate(
        validClaims(
          tokenAudience: 'other-client',
          notBefore: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );

      expect(result.isAuthenticated, isFalse);
      expect(result.errorMessage, 'Invalid token audience');
    });

    test('preserves signature validation and does not expose the token',
        () async {
      final claims = validClaims();
      final token = signToken(claims, key: alternateSigningKey);
      final result = await authenticate(claims, key: alternateSigningKey);

      expect(result.isAuthenticated, isFalse);
      expect(result.errorMessage, 'Invalid token signature');
      expect(result.errorMessage, isNot(contains(token)));
    });

    test('accepts a valid token without optional time claims', () async {
      final result = await authenticate({
        'sub': 'user-123',
        'iss': issuer,
        'aud': audience,
      });

      expect(result.isAuthenticated, isTrue);
    });

    test('rejects negative clock skew tolerance', () {
      expect(
        () => OAuthJwtAuthHandler<Map<String, dynamic>>(
          jwksUri: jwksUri.toString(),
          issuer: issuer,
          audience: audience,
          clockSkewTolerance: const Duration(seconds: -1),
          parseClaimsFromJson: (json) => json,
        ),
        throwsArgumentError,
      );
    });
  });
}
