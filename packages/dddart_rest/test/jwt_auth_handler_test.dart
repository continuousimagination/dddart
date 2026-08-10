import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/jwt_auth_handler.dart';
import 'package:dddart_rest/src/refresh_token.dart';
import 'package:dddart_rest/src/refresh_token_lifecycle.dart';
import 'package:dddart_rest/src/standard_claims.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('JwtAuthHandler', () {
    late Repository<RefreshToken> refreshTokenRepo;
    late JwtAuthHandler<StandardClaims, RefreshToken> authHandler;
    late StandardClaims? currentClaims;
    late List<String> claimsLoaderCalls;

    setUp(() {
      refreshTokenRepo = InMemoryRepository<RefreshToken>();
      currentClaims = const StandardClaims(
        sub: 'user123',
        email: 'test@example.com',
        name: 'Test User',
      );
      claimsLoaderCalls = [];
      authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
        secret: 'test-secret-key-for-testing',
        refreshTokenRepository: refreshTokenRepo,
        refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
        claimsLoader: (userId) async {
          claimsLoaderCalls.add(userId);
          final claims = currentClaims;
          if (claims == null) {
            return null;
          }
          return StandardClaims(
            sub: userId,
            email: claims.email,
            name: claims.name,
          );
        },
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
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async => StandardClaims(
            sub: userId,
            email: 'test@example.com',
          ),
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          issuer: 'https://test.example.com',
          audience: 'test-app',
          accessTokenDuration: const Duration(seconds: -1), // Already expired
        );

        final tokens = await expiredHandler.issueTokens('user123');

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
        final tokens = await authHandler.issueTokens('user123');

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
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async => StandardClaims(sub: userId),
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          issuer: 'https://different.example.com',
        );

        final tokens = await differentIssuerHandler.issueTokens('user123');

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
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async => StandardClaims(sub: userId),
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          issuer: 'https://test.example.com', // Same issuer
          audience: 'different-app',
        );

        final tokens = await differentAudienceHandler.issueTokens('user123');

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
        final tokens = await authHandler.issueTokens('user123');

        expect(tokens.accessToken, isNotEmpty);
        expect(tokens.refreshToken, isNotEmpty);
        expect(tokens.expiresIn, equals(900)); // 15 minutes
        expect(tokens.tokenType, equals('Bearer'));
      });

      test('should store refresh token in repository', () async {
        final tokens = await authHandler.issueTokens(
          'user123',
          deviceInfo: 'Test Device',
        );

        final repo = refreshTokenRepo as InMemoryRepository<RefreshToken>;
        final allTokens = repo.getAllSync();
        final storedToken = allTokens.firstWhere(
          (token) => token.token == tokens.refreshToken,
        );

        expect(storedToken.userId, equals('user123'));
        expect(storedToken.token, equals(tokens.refreshToken));
        expect(storedToken.revoked, isFalse);
        expect(storedToken.deviceInfo, equals('Test Device'));
      });

      test('should include custom claims in JWT', () async {
        final tokens = await authHandler.issueTokens('user123');

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

      test('server-controlled claims cannot be overridden', () async {
        final maliciousClaims = <String, dynamic>{
          'sub': 'attacker',
          'iat': 1,
          'exp': 2,
          'iss': 'https://attacker.example.com',
          'aud': 'attacker-app',
          'role': 'admin',
        };
        final handler = JwtAuthHandler<Map<String, dynamic>, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: InMemoryRepository<RefreshToken>(),
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async => maliciousClaims,
          parseClaimsFromJson: (_) => maliciousClaims,
          claimsToJson: (claims) => claims,
          issuer: 'https://trusted.example.com',
          audience: 'trusted-app',
        );

        final issued = await handler.issueTokens('real-user');
        final issuedPayload = JWT
            .verify(
              issued.accessToken,
              SecretKey('test-secret-key-for-testing'),
            )
            .payload as Map<String, dynamic>;

        expect(issuedPayload['sub'], 'real-user');
        expect(issuedPayload['iat'], isNot(1));
        expect(issuedPayload['exp'], isNot(2));
        expect(issuedPayload['iss'], 'https://trusted.example.com');
        expect(issuedPayload['aud'], 'trusted-app');
        expect(issuedPayload['role'], 'admin');

        final refreshed = await handler.refresh(issued.refreshToken);
        final refreshedPayload = JWT
            .verify(
              refreshed.accessToken,
              SecretKey('test-secret-key-for-testing'),
            )
            .payload as Map<String, dynamic>;

        expect(refreshedPayload['sub'], 'real-user');
        expect(refreshedPayload['iat'], isNot(1));
        expect(refreshedPayload['exp'], isNot(2));
        expect(refreshedPayload['iss'], 'https://trusted.example.com');
        expect(refreshedPayload['aud'], 'trusted-app');
        expect(refreshedPayload['role'], 'admin');
      });

      test('does not persist a refresh token when claims are unavailable',
          () async {
        currentClaims = null;

        await expectLater(
          authHandler.issueTokens('missing-user'),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('Authentication failed'),
            ),
          ),
        );

        expect(
          (refreshTokenRepo as InMemoryRepository<RefreshToken>).getAllSync(),
          isEmpty,
        );
      });
    });

    group('refresh', () {
      test('reloads current roles, tenants, and profile claims', () async {
        final repository = InMemoryRepository<RefreshToken>();
        var currentClaims = const _ApplicationClaims(
          userId: 'user123',
          roles: ['reader'],
          tenantIds: ['tenant-a'],
          profile: {'displayName': 'Original Name'},
        );
        final loaderCalls = <String>[];
        var parserCalls = 0;
        final handler = JwtAuthHandler<_ApplicationClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: repository,
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async {
            loaderCalls.add(userId);
            return currentClaims;
          },
          parseClaimsFromJson: (json) {
            parserCalls++;
            return _ApplicationClaims.fromJson(json);
          },
          claimsToJson: (claims) => claims.toJson(),
        );

        final originalTokens = await handler.issueTokens('user123');
        final originalPayload = JWT
            .verify(
              originalTokens.accessToken,
              SecretKey('test-secret-key-for-testing'),
            )
            .payload as Map<String, dynamic>;

        currentClaims = const _ApplicationClaims(
          userId: 'user123',
          roles: ['admin', 'auditor'],
          tenantIds: ['tenant-b', 'tenant-c'],
          profile: {'displayName': 'Current Name'},
        );

        final refreshedTokens = await handler.refresh(
          originalTokens.refreshToken,
        );
        final refreshedPayload = JWT
            .verify(
              refreshedTokens.accessToken,
              SecretKey('test-secret-key-for-testing'),
            )
            .payload as Map<String, dynamic>;

        expect(originalPayload['roles'], ['reader']);
        expect(originalPayload['tenantIds'], ['tenant-a']);
        expect(originalPayload['profile'], {'displayName': 'Original Name'});
        expect(refreshedPayload['roles'], ['admin', 'auditor']);
        expect(refreshedPayload['tenantIds'], ['tenant-b', 'tenant-c']);
        expect(refreshedPayload['profile'], {'displayName': 'Current Name'});
        expect(loaderCalls, ['user123', 'user123']);
        expect(parserCalls, 0);

        expect(refreshedTokens.refreshToken, originalTokens.refreshToken);
        expect(originalTokens.refreshToken.split('.'), hasLength(1));
        expect(originalTokens.refreshToken, isNot(contains('tenant-a')));
        final storedToken = repository.getAllSync().single;
        expect(storedToken.userId, 'user123');
        expect(storedToken.token, originalTokens.refreshToken);
      });

      test('should issue new access token with valid refresh token', () async {
        final originalTokens = await authHandler.issueTokens('user123');

        currentClaims = const StandardClaims(
          sub: 'user123',
          email: 'updated@example.com',
          name: 'Updated User',
        );

        final newTokens =
            await authHandler.refresh(originalTokens.refreshToken);

        expect(newTokens.accessToken, isNotEmpty);
        expect(
          newTokens.accessToken,
          isNot(equals(originalTokens.accessToken)),
        );
        expect(newTokens.refreshToken, equals(originalTokens.refreshToken));
      });

      test('should throw exception for invalid refresh token', () async {
        await expectLater(
          authHandler.refresh('invalid-token'),
          throwsA(isA<Exception>()),
        );
        expect(claimsLoaderCalls, isEmpty);
      });

      test('should throw exception for expired refresh token', () async {
        // Create handler with very short refresh token duration
        var shortDurationLoaderCalls = 0;
        final shortDurationHandler =
            JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: refreshTokenRepo,
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async {
            shortDurationLoaderCalls++;
            return StandardClaims(sub: userId);
          },
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
          refreshTokenDuration: const Duration(seconds: -1), // Already expired
        );

        final tokens = await shortDurationHandler.issueTokens('user123');

        await expectLater(
          shortDurationHandler.refresh(tokens.refreshToken),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('expired'),
            ),
          ),
        );
        expect(shortDurationLoaderCalls, 1);
      });

      test('should throw exception for revoked refresh token', () async {
        final tokens = await authHandler.issueTokens('user123');

        // Revoke the token
        await authHandler.revoke(tokens.refreshToken);

        await expectLater(
          authHandler.refresh(tokens.refreshToken),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('revoked'),
            ),
          ),
        );
        expect(claimsLoaderCalls, ['user123']);
      });

      for (final unavailableState in ['missing', 'disabled']) {
        test('$unavailableState users cannot refresh', () async {
          var userExists = true;
          var userEnabled = true;
          final repository = InMemoryRepository<RefreshToken>();
          final handler = JwtAuthHandler<StandardClaims, RefreshToken>(
            secret: 'test-secret-key-for-testing',
            refreshTokenRepository: repository,
            refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
            claimsLoader: (userId) async {
              if (!userExists || !userEnabled) {
                return null;
              }
              return StandardClaims(sub: userId);
            },
            parseClaimsFromJson: StandardClaims.fromJson,
            claimsToJson: (claims) => claims.toJson(),
          );
          final tokens = await handler.issueTokens('user123');

          if (unavailableState == 'missing') {
            userExists = false;
          } else {
            userEnabled = false;
          }

          await expectLater(
            handler.refresh(tokens.refreshToken),
            throwsA(
              isA<Exception>().having(
                (error) => error.toString(),
                'message',
                contains('Authentication failed'),
              ),
            ),
          );
        });
      }
    });

    group('revoke', () {
      test('should mark refresh token as revoked', () async {
        final tokens = await authHandler.issueTokens('user123');

        await authHandler.revoke(tokens.refreshToken);

        final repo = refreshTokenRepo as InMemoryRepository<RefreshToken>;
        final allTokens = repo.getAllSync();
        final storedToken = allTokens.firstWhere(
          (token) => token.token == tokens.refreshToken,
        );

        expect(storedToken.revoked, isTrue);
      });

      test('should not throw exception for non-existent token', () async {
        // Should complete without error
        await authHandler.revoke('non-existent-token');
      });

      test('should propagate repository failures', () async {
        const failure = RepositoryException(
          'refresh token store unavailable',
          type: RepositoryExceptionType.connection,
        );
        final failingHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: const _FailingRefreshTokenRepository(failure),
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async => StandardClaims(sub: userId),
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
        );

        await expectLater(
          failingHandler.revoke('existing-token'),
          throwsA(same(failure)),
        );
      });

      test('should prevent refresh after revocation', () async {
        final tokens = await authHandler.issueTokens('user123');

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

class _ApplicationClaims {
  const _ApplicationClaims({
    required this.userId,
    required this.roles,
    required this.tenantIds,
    required this.profile,
  });

  factory _ApplicationClaims.fromJson(Map<String, dynamic> json) {
    return _ApplicationClaims(
      userId: json['sub'] as String,
      roles: (json['roles'] as List).cast<String>(),
      tenantIds: (json['tenantIds'] as List).cast<String>(),
      profile: (json['profile'] as Map).cast<String, dynamic>(),
    );
  }

  final String userId;
  final List<String> roles;
  final List<String> tenantIds;
  final Map<String, dynamic> profile;

  Map<String, dynamic> toJson() => {
        'sub': userId,
        'roles': roles,
        'tenantIds': tenantIds,
        'profile': profile,
      };
}

class _FailingRefreshTokenRepository
    implements QueryableRepository<RefreshToken> {
  const _FailingRefreshTokenRepository(this.failure);

  final RepositoryException failure;

  @override
  Future<void> deleteById(UuidValue id) => throw UnimplementedError();

  @override
  Future<List<RefreshToken>> getAll() => throw failure;

  @override
  Future<RefreshToken> getById(UuidValue id) => throw UnimplementedError();

  @override
  Future<void> save(RefreshToken aggregate) => throw UnimplementedError();
}
