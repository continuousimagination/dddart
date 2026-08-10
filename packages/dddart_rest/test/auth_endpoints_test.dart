import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('AuthEndpoints', () {
    late InMemoryRepository<RefreshToken> refreshTokenRepo;
    late InMemoryDeviceCodeRepository<DeviceCode> deviceCodeRepo;
    late JwtAuthHandler<StandardClaims, RefreshToken> authHandler;
    late AuthEndpoints<StandardClaims, RefreshToken, DeviceCode> authEndpoints;
    late StandardClaims? currentClaims;

    setUp(() {
      refreshTokenRepo = InMemoryRepository<RefreshToken>();
      deviceCodeRepo = InMemoryDeviceCodeRepository<DeviceCode>(
        lifecycle: const StandardDeviceCodeLifecycle(),
      );
      currentClaims = const StandardClaims(
        sub: 'user123',
        email: 'test@example.com',
        name: 'Test User',
      );

      authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
        secret: 'test-secret-key',
        refreshTokenRepository: refreshTokenRepo,
        refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
        claimsLoader: (userId) async {
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
        parseClaimsFromJson: (json) => StandardClaims(
          sub: json['sub'] as String,
          email: json['email'] as String?,
          name: json['name'] as String?,
        ),
        claimsToJson: (claims) => {
          'sub': claims.sub,
          if (claims.email != null) 'email': claims.email,
          if (claims.name != null) 'name': claims.name,
        },
      );

      authEndpoints = AuthEndpoints<StandardClaims, RefreshToken, DeviceCode>(
        authHandler: authHandler,
        deviceCodeRepository: deviceCodeRepo,
        deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
        userValidator: (username, password) async {
          if (username == 'testuser' && password == 'testpass') {
            return 'user123';
          }
          return null;
        },
      );
    });

    group('handleLogin', () {
      test('should return tokens for valid credentials', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
            'password': 'testpass',
          }),
        );

        final response = await authEndpoints.handleLogin(request);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['access_token'], isNotNull);
        expect(json['refresh_token'], isNotNull);
        expect(json['expires_in'], equals(900)); // 15 minutes
        expect(json['token_type'], equals('Bearer'));

        // Verify refresh token was stored
        final allTokens = refreshTokenRepo.getAllSync();
        expect(allTokens.length, equals(1));
        expect(allTokens.first.userId, equals('user123'));
      });

      test('should return 401 for invalid credentials', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
            'password': 'wrongpass',
          }),
        );

        final response = await authEndpoints.handleLogin(request);

        expect(response.statusCode, equals(401));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['title'], equals('Unauthorized'));
        expect(json['detail'], equals('Invalid credentials'));
      });

      test('should return 400 for missing username', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'password': 'testpass',
          }),
        );

        final response = await authEndpoints.handleLogin(request);

        expect(response.statusCode, equals(400));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['title'], equals('Bad Request'));
        expect(json['detail'], equals('Missing username or password'));
      });

      test('should return 400 for missing password', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
          }),
        );

        final response = await authEndpoints.handleLogin(request);

        expect(response.statusCode, equals(400));
      });

      test('should not disclose internal login errors', () async {
        final leakingEndpoints =
            AuthEndpoints<StandardClaims, RefreshToken, DeviceCode>(
          authHandler: authHandler,
          deviceCodeRepository: deviceCodeRepo,
          deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
          userValidator: (_, __) =>
              throw Exception('sentinel-secret <script>alert(1)</script>'),
        );
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
            'password': 'testpass',
          }),
        );

        final response = await leakingEndpoints.handleLogin(request);
        final body = await response.readAsString();

        expect(response.statusCode, 500);
        expect(body, isNot(contains('sentinel-secret')));
        expect(body, isNot(contains('<script>')));
        expect(body, contains('Failed to process login'));
      });
    });

    group('handleRefresh', () {
      test('should return new access token for valid refresh token', () async {
        // First, login to get tokens
        final loginRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
            'password': 'testpass',
          }),
        );

        final loginResponse = await authEndpoints.handleLogin(loginRequest);
        final loginBody = await loginResponse.readAsString();
        final loginJson = jsonDecode(loginBody) as Map<String, dynamic>;
        final refreshToken = loginJson['refresh_token'] as String;

        // Now refresh
        final refreshRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/refresh'),
          body: jsonEncode({
            'refresh_token': refreshToken,
          }),
        );

        final response = await authEndpoints.handleRefresh(refreshRequest);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['access_token'], isNotNull);
        expect(json['refresh_token'], equals(refreshToken));
        expect(json['expires_in'], equals(900));
      });

      test('should return access token with current application claims',
          () async {
        final loginResponse = await authEndpoints.handleLogin(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/login'),
            body: jsonEncode({
              'username': 'testuser',
              'password': 'testpass',
            }),
          ),
        );
        final loginJson = jsonDecode(await loginResponse.readAsString())
            as Map<String, dynamic>;

        currentClaims = const StandardClaims(
          sub: 'user123',
          email: 'current@example.com',
          name: 'Current Name',
        );

        final refreshResponse = await authEndpoints.handleRefresh(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/refresh'),
            body: jsonEncode({
              'refresh_token': loginJson['refresh_token'],
            }),
          ),
        );
        final refreshJson = jsonDecode(await refreshResponse.readAsString())
            as Map<String, dynamic>;
        final authentication = await authHandler.authenticate(
          Request(
            'GET',
            Uri.parse('http://localhost/protected'),
            headers: {
              'authorization': 'Bearer ${refreshJson['access_token']}',
            },
          ),
        );

        expect(refreshResponse.statusCode, 200);
        expect(authentication.isAuthenticated, isTrue);
        expect(authentication.claims?.email, 'current@example.com');
        expect(authentication.claims?.name, 'Current Name');
      });

      test(
          'should return sanitized 401 when application claims are unavailable',
          () async {
        final loginResponse = await authEndpoints.handleLogin(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/login'),
            body: jsonEncode({
              'username': 'testuser',
              'password': 'testpass',
            }),
          ),
        );
        final loginJson = jsonDecode(await loginResponse.readAsString())
            as Map<String, dynamic>;
        currentClaims = null;

        final response = await authEndpoints.handleRefresh(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/refresh'),
            body: jsonEncode({
              'refresh_token': loginJson['refresh_token'],
            }),
          ),
        );
        final body = await response.readAsString();

        expect(response.statusCode, 401);
        expect(body, contains('Authentication failed'));
        expect(body, isNot(contains('missing')));
        expect(body, isNot(contains('disabled')));
      });

      test('should return 401 for invalid refresh token', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/refresh'),
          body: jsonEncode({
            'refresh_token': 'invalid-token',
          }),
        );

        final response = await authEndpoints.handleRefresh(request);

        expect(response.statusCode, equals(401));
      });

      test('should return 400 for missing refresh token', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/refresh'),
          body: jsonEncode({}),
        );

        final response = await authEndpoints.handleRefresh(request);

        expect(response.statusCode, equals(400));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['detail'], equals('Missing refresh_token'));
      });
    });

    group('handleLogout', () {
      test('should revoke refresh token', () async {
        // First, login to get tokens
        final loginRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
            'password': 'testpass',
          }),
        );

        final loginResponse = await authEndpoints.handleLogin(loginRequest);
        final loginBody = await loginResponse.readAsString();
        final loginJson = jsonDecode(loginBody) as Map<String, dynamic>;
        final refreshToken = loginJson['refresh_token'] as String;

        // Logout
        final logoutRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/logout'),
          body: jsonEncode({
            'refresh_token': refreshToken,
          }),
        );

        final response = await authEndpoints.handleLogout(logoutRequest);

        expect(response.statusCode, equals(204));

        // Verify token was revoked
        final allTokens = refreshTokenRepo.getAllSync();
        expect(allTokens.first.revoked, isTrue);
      });

      test('should return 400 for missing refresh token', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/logout'),
          body: jsonEncode({}),
        );

        final response = await authEndpoints.handleLogout(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('handleDeviceCode', () {
      test('should generate device code and user code', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/device'),
          body: jsonEncode({
            'client_id': 'test-cli',
          }),
        );

        final response = await authEndpoints.handleDeviceCode(request);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['device_code'], isNotNull);
        expect(json['user_code'], isNotNull);
        expect(json['verification_uri'], equals('/auth/device/verify'));
        expect(json['expires_in'], equals(600)); // 10 minutes
        expect(json['interval'], equals(5));

        // Verify user code format (XXXX-XXXX)
        final userCode = json['user_code'] as String;
        expect(userCode.length, equals(9)); // 8 chars + 1 hyphen
        expect(userCode[4], equals('-'));

        // Verify device code was stored
        final allCodes = deviceCodeRepo.getAllSync();
        expect(allCodes.length, equals(1));
        expect(allCodes.first.status, equals(DeviceCodeStatus.pending));
      });

      test('should return 400 for missing client_id', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/device'),
          body: jsonEncode({}),
        );

        final response = await authEndpoints.handleDeviceCode(request);

        expect(response.statusCode, equals(400));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['detail'], equals('Missing client_id'));
      });
    });

    group('handleDeviceVerify', () {
      test('should display HTML form for GET request', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/auth/device/verify'),
        );

        final response = await authEndpoints.handleDeviceVerify(request);

        expect(response.statusCode, equals(200));
        expect(
          response.headers['content-type'],
          equals('text/html'),
        );

        final body = await response.readAsString();
        expect(body, contains('<form'));
        expect(body, contains('user_code'));
        expect(body, contains('username'));
        expect(body, contains('password'));
      });

      test('should approve device code on valid submission', () async {
        // First, create a device code
        final deviceCodeRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device'),
          body: jsonEncode({
            'client_id': 'test-cli',
          }),
        );

        final deviceCodeResponse =
            await authEndpoints.handleDeviceCode(deviceCodeRequest);
        final deviceCodeBody = await deviceCodeResponse.readAsString();
        final deviceCodeJson =
            jsonDecode(deviceCodeBody) as Map<String, dynamic>;
        final userCode = deviceCodeJson['user_code'] as String;

        // Submit verification form
        final verifyRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device/verify'),
          body: 'user_code=$userCode&username=testuser&password=testpass',
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
          },
        );

        final response = await authEndpoints.handleDeviceVerify(verifyRequest);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        expect(body, contains('Device Verified'));

        // Verify device code was approved
        final allCodes = deviceCodeRepo.getAllSync();
        expect(allCodes.first.status, equals(DeviceCodeStatus.approved));
        expect(allCodes.first.userId, equals('user123'));
      });

      test('should reject invalid credentials', () async {
        // First, create a device code
        final deviceCodeRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device'),
          body: jsonEncode({
            'client_id': 'test-cli',
          }),
        );

        final deviceCodeResponse =
            await authEndpoints.handleDeviceCode(deviceCodeRequest);
        final deviceCodeBody = await deviceCodeResponse.readAsString();
        final deviceCodeJson =
            jsonDecode(deviceCodeBody) as Map<String, dynamic>;
        final userCode = deviceCodeJson['user_code'] as String;

        // Submit with wrong password
        final verifyRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device/verify'),
          body: 'user_code=$userCode&username=testuser&password=wrongpass',
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
          },
        );

        final response = await authEndpoints.handleDeviceVerify(verifyRequest);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        expect(body, contains('Invalid credentials'));
      });

      test('should not reflect internal errors into HTML', () async {
        final leakingEndpoints =
            AuthEndpoints<StandardClaims, RefreshToken, DeviceCode>(
          authHandler: authHandler,
          deviceCodeRepository: deviceCodeRepo,
          deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
          userValidator: (_, __) =>
              throw Exception('sentinel-secret <script>alert(1)</script>'),
        );
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/device/verify'),
          body: 'user_code=ABCD-EFGH&username=testuser&password=testpass',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
        );

        final response = await leakingEndpoints.handleDeviceVerify(request);
        final body = await response.readAsString();

        expect(response.statusCode, 200);
        expect(body, contains('Failed to verify device'));
        expect(body, isNot(contains('sentinel-secret')));
        expect(body, isNot(contains('<script>')));
      });
    });

    group('handleToken', () {
      test('should return authorization_pending for pending device code',
          () async {
        // Create a device code
        final deviceCodeRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device'),
          body: jsonEncode({
            'client_id': 'test-cli',
          }),
        );

        final deviceCodeResponse =
            await authEndpoints.handleDeviceCode(deviceCodeRequest);
        final deviceCodeBody = await deviceCodeResponse.readAsString();
        final deviceCodeJson =
            jsonDecode(deviceCodeBody) as Map<String, dynamic>;
        final deviceCode = deviceCodeJson['device_code'] as String;

        // Poll for tokens
        final tokenRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/token'),
          body: jsonEncode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'device_code': deviceCode,
            'client_id': 'test-cli',
          }),
        );

        final response = await authEndpoints.handleToken(tokenRequest);

        expect(response.statusCode, equals(400));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['error'], equals('authorization_pending'));
      });

      test('should return tokens for approved device code', () async {
        // Create a device code
        final deviceCodeRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device'),
          body: jsonEncode({
            'client_id': 'test-cli',
          }),
        );

        final deviceCodeResponse =
            await authEndpoints.handleDeviceCode(deviceCodeRequest);
        final deviceCodeBody = await deviceCodeResponse.readAsString();
        final deviceCodeJson =
            jsonDecode(deviceCodeBody) as Map<String, dynamic>;
        final deviceCode = deviceCodeJson['device_code'] as String;
        final userCode = deviceCodeJson['user_code'] as String;

        // Approve the device code
        final verifyRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/device/verify'),
          body: 'user_code=$userCode&username=testuser&password=testpass',
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
          },
        );

        await authEndpoints.handleDeviceVerify(verifyRequest);

        // Poll for tokens
        final tokenRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/token'),
          body: jsonEncode({
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'device_code': deviceCode,
            'client_id': 'test-cli',
          }),
        );

        final response = await authEndpoints.handleToken(tokenRequest);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['access_token'], isNotNull);
        expect(json['refresh_token'], isNotNull);
        expect(json['expires_in'], equals(900));
        expect(json['token_type'], equals('Bearer'));
      });

      test('should delegate to refresh for refresh_token grant', () async {
        // First, login to get tokens
        final loginRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/login'),
          body: jsonEncode({
            'username': 'testuser',
            'password': 'testpass',
          }),
        );

        final loginResponse = await authEndpoints.handleLogin(loginRequest);
        final loginBody = await loginResponse.readAsString();
        final loginJson = jsonDecode(loginBody) as Map<String, dynamic>;
        final refreshToken = loginJson['refresh_token'] as String;

        // Use token endpoint with refresh_token grant
        final tokenRequest = Request(
          'POST',
          Uri.parse('http://localhost/auth/token'),
          body: jsonEncode({
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          }),
        );

        final response = await authEndpoints.handleToken(tokenRequest);

        expect(response.statusCode, equals(200));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['access_token'], isNotNull);
      });

      test('should return 400 for missing grant_type', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/token'),
          body: jsonEncode({}),
        );

        final response = await authEndpoints.handleToken(request);

        expect(response.statusCode, equals(400));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['detail'], equals('Missing grant_type'));
      });

      test('should return 400 for unsupported grant_type', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/auth/token'),
          body: jsonEncode({
            'grant_type': 'unsupported',
          }),
        );

        final response = await authEndpoints.handleToken(request);

        expect(response.statusCode, equals(400));

        final body = await response.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;

        expect(json['detail'], equals('Unsupported grant_type'));
      });
    });
  });
}
