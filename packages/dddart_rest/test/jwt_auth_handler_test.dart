import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/jwt_auth_handler.dart';
import 'package:dddart_rest/src/refresh_token.dart';
import 'package:dddart_rest/src/standard_claims.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('JwtAuthHandler', () {
    late Repository<RefreshToken> refreshTokenRepo;
    late JwtAuthHandler<StandardClaims, RefreshToken> authHandler;

    setUp(() {
      refreshTokenRepo = InMemoryRepository<RefreshToken>();
      authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
        secret: 'test-secret-key-for-testing',
        refreshTokenRepository: refreshTokenRepo,
        parseClaimsFromJson: StandardClaims.fromJson,
        claimsToJson: (claims) => claims.toJson(),
        issuer: 'https://test.example.com',
        audience: 'test-app',
      );
    });

    group('authenticate', () {
      test('should return failure when Authorization header is missing',
          () async {
        final request = Request('GET', Uri.parse('http://localhost/test'));

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Missing authorization header'));
      });

      test('should return failure when token format is invalid', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'InvalidFormat token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Invalid token format'));
      });

      test('should return failure when token signature is invalid', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer invalid.jwt.token'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, contains('Invalid token'));
      });

      test('should return failure when token has expired', () async {
        // Create a token that's already expired using the same handler
        final expiredHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: refreshTokenRepo,
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          issuer: 'https://test.example.com',
          audience: 'test-app',
          accessTokenDuration: const Duration(seconds: -1), // Already expired
        );

        final tokens = await expiredHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123', email: 'test@example.com'),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${tokens.accessToken}'},
        );

        // Use the same handler to authenticate
        final result = await expiredHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Token has expired'));
      });

      test('should return success with valid token', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(
            sub: 'user123',
            email: 'test@example.com',
            name: 'Test User',
          ),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${tokens.accessToken}'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isTrue);
        expect(result.userId, equals('user123'));
        expect(result.claims, isNotNull);
        expect(result.claims!.sub, equals('user123'));
        expect(result.claims!.email, equals('test@example.com'));
        expect(result.claims!.name, equals('Test User'));
      });

      test('should validate issuer claim when configured', () async {
        // Create handler with different issuer
        final differentIssuerHandler =
            JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: refreshTokenRepo,
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          issuer: 'https://different.example.com',
        );

        final tokens = await differentIssuerHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123'),
        );

        // Try to authenticate with handler expecting different issuer
        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${tokens.accessToken}'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Invalid token issuer'));
      });

      test('should validate audience claim when configured', () async {
        // Create handler with different audience
        final differentAudienceHandler =
            JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: refreshTokenRepo,
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          issuer: 'https://test.example.com', // Same issuer
          audience: 'different-app',
        );

        final tokens = await differentAudienceHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123'),
        );

        // Try to authenticate with handler expecting different audience
        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${tokens.accessToken}'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isFalse);
        expect(result.errorMessage, equals('Invalid token audience'));
      });
    });

    group('issueTokens', () {
      test('should generate access and refresh tokens', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123', email: 'test@example.com'),
        );

        expect(tokens.accessToken, isNotEmpty);
        expect(tokens.refreshToken, isNotEmpty);
        expect(tokens.expiresIn, equals(900)); // 15 minutes
        expect(tokens.tokenType, equals('Bearer'));
      });

      test('should store refresh token in repository', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123', email: 'test@example.com'),
          deviceInfo: 'Test Device',
        );

        final repo = refreshTokenRepo as InMemoryRepository<RefreshToken>;
        final allTokens = repo.getAll();
        final storedToken = allTokens.firstWhere(
          (token) => token.token == tokens.refreshToken,
        );

        expect(storedToken.userId, equals('user123'));
        expect(storedToken.token, equals(tokens.refreshToken));
        expect(storedToken.revoked, isFalse);
        expect(storedToken.deviceInfo, equals('Test Device'));
      });

      test('should include custom claims in JWT', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(
            sub: 'user123',
            email: 'test@example.com',
            name: 'Test User',
          ),
        );

        // Verify by authenticating with the token
        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${tokens.accessToken}'},
        );

        final result = await authHandler.authenticate(request);

        expect(result.isAuthenticated, isTrue);
        expect(result.claims!.email, equals('test@example.com'));
        expect(result.claims!.name, equals('Test User'));
      });
    });

    group('refresh', () {
      test('should issue new access token with valid refresh token', () async {
        final originalTokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123', email: 'test@example.com'),
        );

        final newTokens =
            await authHandler.refresh(originalTokens.refreshToken);

        expect(newTokens.accessToken, isNotEmpty);
        expect(
            newTokens.accessToken, isNot(equals(originalTokens.accessToken)),);
        expect(newTokens.refreshToken, equals(originalTokens.refreshToken));
      });

      test('should throw exception for invalid refresh token', () async {
        expect(
          () => authHandler.refresh('invalid-token'),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception for expired refresh token', () async {
        // Create handler with very short refresh token duration
        final shortDurationHandler =
            JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: refreshTokenRepo,
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          refreshTokenDuration: const Duration(seconds: -1), // Already expired
        );

        final tokens = await shortDurationHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123'),
        );

        expect(
          () => authHandler.refresh(tokens.refreshToken),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('expired'),
            ),
          ),
        );
      });

      test('should throw exception for revoked refresh token', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123'),
        );

        // Revoke the token
        await authHandler.revoke(tokens.refreshToken);

        expect(
          () => authHandler.refresh(tokens.refreshToken),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('revoked'),
            ),
          ),
        );
      });
    });

    group('revoke', () {
      test('should mark refresh token as revoked', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123'),
        );

        await authHandler.revoke(tokens.refreshToken);

        final repo = refreshTokenRepo as InMemoryRepository<RefreshToken>;
        final allTokens = repo.getAll();
        final storedToken = allTokens.firstWhere(
          (token) => token.token == tokens.refreshToken,
        );

        expect(storedToken.revoked, isTrue);
      });

      test('should not throw exception for non-existent token', () async {
        // Should complete without error
        await authHandler.revoke('non-existent-token');
      });

      test('should prevent refresh after revocation', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(sub: 'user123'),
        );

        await authHandler.revoke(tokens.refreshToken);

        expect(
          () => authHandler.refresh(tokens.refreshToken),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('token lifecycle', () {
      test('should support complete authentication flow', () async {
        // 1. Issue tokens
        final tokens = await authHandler.issueTokens(
          'user123',
          const StandardClaims(
            sub: 'user123',
            email: 'test@example.com',
            name: 'Test User',
          ),
          deviceInfo: 'Test Device',
        );

        // 2. Authenticate with access token
        var request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${tokens.accessToken}'},
        );

        var result = await authHandler.authenticate(request);
        expect(result.isAuthenticated, isTrue);
        expect(result.userId, equals('user123'));

        // 3. Refresh access token
        final newTokens = await authHandler.refresh(tokens.refreshToken);
        expect(newTokens.accessToken, isNotEmpty);

        // 4. Authenticate with new access token
        request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'authorization': 'Bearer ${newTokens.accessToken}'},
        );

        result = await authHandler.authenticate(request);
        expect(result.isAuthenticated, isTrue);

        // 5. Revoke refresh token
        await authHandler.revoke(tokens.refreshToken);

        // 6. Verify refresh no longer works
        expect(
          () => authHandler.refresh(tokens.refreshToken),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
