import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart/dddart.dart' hide UuidValue;
import 'package:dddart/dddart.dart' as dddart show UuidValue;
import 'package:dddart_rest/src/auth_error_mapper.dart';
import 'package:dddart_rest/src/device_code.dart';
import 'package:dddart_rest/src/jwt_auth_handler.dart';
import 'package:dddart_rest/src/refresh_token.dart';
import 'package:dddart_rest/src/security_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

/// Provides authentication endpoints for self-hosted mode
///
/// This class creates HTTP endpoints for login, refresh, logout, and device
/// flow authentication. It works with [JwtAuthHandler] to issue and validate
/// tokens.
///
/// Example:
/// ```dart
/// final authEndpoints = AuthEndpoints<UserClaims, RefreshToken, DeviceCode>(
///   authHandler: jwtAuthHandler,
///   deviceCodeRepository: deviceCodeRepo,
///   userValidator: (username, password) async {
///     // Validate credentials and return user ID
///     if (username == 'admin' && password == 'secret') {
///       return 'user123';
///     }
///     return null;
///   },
///   claimsBuilder: (userId) async {
///     // Build claims for the user
///     return UserClaims(userId: userId, email: 'user@example.com');
///   },
/// );
/// ```
class AuthEndpoints<TClaims, TRefreshToken extends RefreshToken,
    TDeviceCode extends DeviceCode> {
  /// Creates authentication endpoints
  AuthEndpoints({
    required this.authHandler,
    required this.deviceCodeRepository,
    required this.userValidator,
    required this.claimsBuilder,
    this.verificationUri = '/auth/device/verify',
    this.deviceCodeExpiration = const Duration(minutes: 10),
    this.pollingInterval = 5,
  });

  /// JWT auth handler for issuing/validating tokens
  final JwtAuthHandler<TClaims, TRefreshToken> authHandler;

  /// Repository for storing device codes
  final Repository<TDeviceCode> deviceCodeRepository;

  /// Callback to validate username/password and return user ID
  /// Returns user ID if valid, null if invalid
  final Future<String?> Function(String username, String password)
      userValidator;

  /// Callback to build claims for a user ID
  final Future<TClaims> Function(String userId) claimsBuilder;

  /// Verification URI for device flow
  final String verificationUri;

  /// How long device codes are valid
  final Duration deviceCodeExpiration;

  /// Polling interval in seconds for device flow
  final int pollingInterval;

  final _uuid = const Uuid();

  /// POST /auth/login - Username/password login
  ///
  /// Request body:
  /// ```json
  /// {
  ///   "username": "alice",
  ///   "password": "secret"
  /// }
  /// ```
  ///
  /// Response (200):
  /// ```json
  /// {
  ///   "access_token": "eyJhbGc...",
  ///   "refresh_token": "def50200...",
  ///   "expires_in": 900,
  ///   "token_type": "Bearer"
  /// }
  /// ```
  Future<Response> handleLogin(Request request) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final username = json['username'] as String?;
      final password = json['password'] as String?;

      if (username == null || password == null) {
        return _problemResponse(
          status: 400,
          title: 'Bad Request',
          detail: 'Missing username or password',
        );
      }

      // Validate credentials
      final userId = await userValidator(username, password);
      if (userId == null) {
        return _problemResponse(
          status: 401,
          title: 'Unauthorized',
          detail: 'Invalid credentials',
        );
      }

      // Build claims
      final claims = await claimsBuilder(userId);

      // Issue tokens
      final tokens = await authHandler.issueTokens(
        userId,
        claims,
        deviceInfo: request.headers['user-agent'],
      );

      return _jsonResponse(tokens.toJson());
    } catch (e) {
      return _problemResponse(
        status: 500,
        title: 'Internal Server Error',
        detail: 'Failed to process login: $e',
      );
    }
  }

  /// POST /auth/refresh - Refresh access token
  ///
  /// Request body:
  /// ```json
  /// {
  ///   "refresh_token": "def50200..."
  /// }
  /// ```
  ///
  /// Response (200):
  /// ```json
  /// {
  ///   "access_token": "eyJhbGc...",
  ///   "refresh_token": "def50200...",
  ///   "expires_in": 900,
  ///   "token_type": "Bearer"
  /// }
  /// ```
  Future<Response> handleRefresh(Request request) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final refreshToken = json['refresh_token'] as String?;

      if (refreshToken == null) {
        return _problemResponse(
          status: 400,
          title: 'Bad Request',
          detail: 'Missing refresh_token',
        );
      }

      // Refresh tokens
      final tokens = await authHandler.refresh(refreshToken);

      return _jsonResponse(tokens.toJson());
    } on Exception catch (e) {
      // Use AuthErrorMapper for consistent error handling
      return AuthErrorMapper.mapToResponse(e);
    } catch (e) {
      return _problemResponse(
        status: 500,
        title: 'Internal Server Error',
        detail: 'Failed to refresh token',
      );
    }
  }

  /// POST /auth/logout - Revoke refresh token
  ///
  /// Request body:
  /// ```json
  /// {
  ///   "refresh_token": "def50200..."
  /// }
  /// ```
  ///
  /// Response: 204 No Content
  Future<Response> handleLogout(Request request) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final refreshToken = json['refresh_token'] as String?;

      if (refreshToken == null) {
        return _problemResponse(
          status: 400,
          title: 'Bad Request',
          detail: 'Missing refresh_token',
        );
      }

      // Revoke token
      await authHandler.revoke(refreshToken);

      return Response(204);
    } catch (e) {
      return _problemResponse(
        status: 500,
        title: 'Internal Server Error',
        detail: 'Failed to logout: $e',
      );
    }
  }

  /// POST /auth/device - Initiate device flow
  ///
  /// Request body:
  /// ```json
  /// {
  ///   "client_id": "my-cli-app"
  /// }
  /// ```
  ///
  /// Response (200):
  /// ```json
  /// {
  ///   "device_code": "abc123...",
  ///   "user_code": "WDJB-MJHT",
  ///   "verification_uri": "https://api.example.com/auth/device/verify",
  ///   "expires_in": 600,
  ///   "interval": 5
  /// }
  /// ```
  Future<Response> handleDeviceCode(Request request) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final clientId = json['client_id'] as String?;

      if (clientId == null) {
        return _problemResponse(
          status: 400,
          title: 'Bad Request',
          detail: 'Missing client_id',
        );
      }

      // Generate device code (random UUID)
      final deviceCodeString = _uuid.v4();

      // Generate user code (8-10 chars, uppercase, hyphen separator)
      final userCode = _generateUserCode();

      // Create DeviceCode aggregate
      final now = DateTime.now();
      final expiresAt = now.add(deviceCodeExpiration);

      final deviceCode = DeviceCode(
        id: dddart.UuidValue.generate(),
        deviceCode: deviceCodeString,
        userCode: userCode,
        clientId: clientId,
        expiresAt: expiresAt,
      ) as TDeviceCode;

      // Store in repository
      await deviceCodeRepository.save(deviceCode);

      // Return response
      return _jsonResponse({
        'device_code': deviceCodeString,
        'user_code': userCode,
        'verification_uri': verificationUri,
        'expires_in': deviceCodeExpiration.inSeconds,
        'interval': pollingInterval,
      });
    } catch (e) {
      return _problemResponse(
        status: 500,
        title: 'Internal Server Error',
        detail: 'Failed to create device code: $e',
      );
    }
  }

  /// GET /auth/device/verify - Verification page for user
  ///
  /// Displays an HTML form for entering the user code. On submit,
  /// authenticates the user and approves the device code.
  Future<Response> handleDeviceVerify(Request request) async {
    // Check if this is a form submission
    if (request.method == 'POST') {
      return _handleDeviceVerifySubmit(request);
    }

    // Display HTML form
    const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Device Verification</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 500px;
      margin: 50px auto;
      padding: 20px;
    }
    h1 {
      color: #333;
    }
    form {
      margin-top: 20px;
    }
    label {
      display: block;
      margin-bottom: 5px;
      font-weight: bold;
    }
    input {
      width: 100%;
      padding: 8px;
      margin-bottom: 15px;
      border: 1px solid #ddd;
      border-radius: 4px;
      box-sizing: border-box;
    }
    button {
      background-color: #007bff;
      color: white;
      padding: 10px 20px;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    button:hover {
      background-color: #0056b3;
    }
    .error {
      color: red;
      margin-top: 10px;
    }
    .success {
      color: green;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <h1>Device Verification</h1>
  <p>Enter the code displayed on your device:</p>
  <form method="POST" action="/auth/device/verify">
    <label for="user_code">User Code:</label>
    <input type="text" id="user_code" name="user_code" placeholder="XXXX-XXXX" required>
    
    <label for="username">Username:</label>
    <input type="text" id="username" name="username" required>
    
    <label for="password">Password:</label>
    <input type="password" id="password" name="password" required>
    
    <button type="submit">Verify</button>
  </form>
</body>
</html>
''';

    return Response.ok(
      html,
      headers: {'Content-Type': 'text/html'},
    );
  }

  /// Handles device verification form submission
  Future<Response> _handleDeviceVerifySubmit(Request request) async {
    try {
      // Parse form data
      final body = await request.readAsString();
      final params = Uri.splitQueryString(body);

      final userCode = params['user_code'];
      final username = params['username'];
      final password = params['password'];

      if (userCode == null || username == null || password == null) {
        return _deviceVerifyError('Missing required fields');
      }

      // Validate credentials
      final userId = await userValidator(username, password);
      if (userId == null) {
        return _deviceVerifyError('Invalid credentials');
      }

      // Look up device code by user code
      DeviceCode? deviceCode;
      if (deviceCodeRepository is InMemoryRepository<TDeviceCode>) {
        final repo = deviceCodeRepository as InMemoryRepository<TDeviceCode>;
        final all = repo.getAll();
        try {
          deviceCode = all.firstWhere((code) => code.userCode == userCode);
        } catch (e) {
          return _deviceVerifyError('Invalid user code');
        }
      } else {
        throw UnsupportedError(
          'Device code lookup requires InMemoryRepository or custom repository with query support',
        );
      }

      // Check if expired
      if (deviceCode.isExpired) {
        return _deviceVerifyError('Device code has expired');
      }

      // Check if already approved
      if (deviceCode.status != DeviceCodeStatus.pending) {
        return _deviceVerifyError('Device code already processed');
      }

      // Approve device code
      final approvedCode = deviceCode.approve(userId) as TDeviceCode;
      await deviceCodeRepository.save(approvedCode);

      // Return success page
      const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Device Verified</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 500px;
      margin: 50px auto;
      padding: 20px;
      text-align: center;
    }
    h1 {
      color: #28a745;
    }
  </style>
</head>
<body>
  <h1>✓ Device Verified</h1>
  <p>You can now close this window and return to your device.</p>
</body>
</html>
''';

      return Response.ok(
        html,
        headers: {'Content-Type': 'text/html'},
      );
    } catch (e) {
      return _deviceVerifyError('Failed to verify device: $e');
    }
  }

  /// Returns an error page for device verification
  Response _deviceVerifyError(String message) {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Verification Error</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 500px;
      margin: 50px auto;
      padding: 20px;
    }
    h1 {
      color: #dc3545;
    }
    .error {
      color: #dc3545;
      margin-top: 10px;
    }
    a {
      color: #007bff;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <h1>Verification Error</h1>
  <p class="error">$message</p>
  <p><a href="/auth/device/verify">Try again</a></p>
</body>
</html>
''';

    return Response.ok(
      html,
      headers: {'Content-Type': 'text/html'},
    );
  }

  /// POST /auth/token - Poll for device flow tokens
  ///
  /// Request body (device flow):
  /// ```json
  /// {
  ///   "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
  ///   "device_code": "abc123...",
  ///   "client_id": "my-cli-app"
  /// }
  /// ```
  ///
  /// Request body (refresh token):
  /// ```json
  /// {
  ///   "grant_type": "refresh_token",
  ///   "refresh_token": "def50200..."
  /// }
  /// ```
  ///
  /// Response (pending):
  /// ```json
  /// {
  ///   "error": "authorization_pending"
  /// }
  /// ```
  ///
  /// Response (approved):
  /// ```json
  /// {
  ///   "access_token": "eyJhbGc...",
  ///   "refresh_token": "def50200...",
  ///   "expires_in": 900,
  ///   "token_type": "Bearer"
  /// }
  /// ```
  Future<Response> handleToken(Request request) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final grantType = json['grant_type'] as String?;

      if (grantType == null) {
        return _problemResponse(
          status: 400,
          title: 'Bad Request',
          detail: 'Missing grant_type',
        );
      }

      // Handle refresh token grant
      if (grantType == 'refresh_token') {
        final refreshToken = json['refresh_token'] as String?;

        if (refreshToken == null) {
          return _problemResponse(
            status: 400,
            title: 'Bad Request',
            detail: 'Missing refresh_token',
          );
        }

        try {
          final tokens = await authHandler.refresh(refreshToken);
          return _jsonResponse(tokens.toJson());
        } on Exception catch (e) {
          // Use AuthErrorMapper for consistent error handling
          return AuthErrorMapper.mapToResponse(e);
        }
      }

      // Handle device code grant
      if (grantType == 'urn:ietf:params:oauth:grant-type:device_code') {
        final deviceCodeString = json['device_code'] as String?;
        final clientId = json['client_id'] as String?;

        if (deviceCodeString == null || clientId == null) {
          return _problemResponse(
            status: 400,
            title: 'Bad Request',
            detail: 'Missing device_code or client_id',
          );
        }

        // Look up device code
        DeviceCode? deviceCode;
        if (deviceCodeRepository is InMemoryRepository<TDeviceCode>) {
          final repo = deviceCodeRepository as InMemoryRepository<TDeviceCode>;
          final all = repo.getAll();
          try {
            deviceCode = all.firstWhere(
              (code) => code.deviceCode == deviceCodeString,
            );
          } catch (e) {
            return _jsonResponse(
              {'error': 'invalid_grant'},
              statusCode: 400,
            );
          }
        } else {
          throw UnsupportedError(
            'Device code lookup requires InMemoryRepository or custom repository with query support',
          );
        }

        // Check if expired
        if (deviceCode.isExpired) {
          return _jsonResponse(
            {'error': 'expired_token'},
            statusCode: 400,
          );
        }

        // Validate timestamp age to prevent replay attacks
        if (!SecurityUtils.validateDeviceCodeAge(
          deviceCode.createdAt,
          deviceCode.expiresAt,
          maxAge: deviceCodeExpiration,
        )) {
          return _jsonResponse(
            {'error': 'expired_token'},
            statusCode: 400,
          );
        }

        // Check status
        if (deviceCode.status == DeviceCodeStatus.pending) {
          return _jsonResponse(
            {'error': 'authorization_pending'},
            statusCode: 400,
          );
        }

        if (deviceCode.status == DeviceCodeStatus.denied) {
          return _jsonResponse(
            {'error': 'access_denied'},
            statusCode: 400,
          );
        }

        if (deviceCode.status == DeviceCodeStatus.approved &&
            deviceCode.userId != null) {
          // Build claims
          final claims = await claimsBuilder(deviceCode.userId!);

          // Issue tokens
          final tokens = await authHandler.issueTokens(
            deviceCode.userId!,
            claims,
            deviceInfo: 'Device Code Flow',
          );

          return _jsonResponse(tokens.toJson());
        }

        return _jsonResponse(
          {'error': 'invalid_grant'},
          statusCode: 400,
        );
      }

      return _problemResponse(
        status: 400,
        title: 'Bad Request',
        detail: 'Unsupported grant_type',
      );
    } catch (e) {
      return _problemResponse(
        status: 500,
        title: 'Internal Server Error',
        detail: 'Failed to process token request: $e',
      );
    }
  }

  /// Generates a human-readable user code
  ///
  /// Format: XXXX-XXXX (8 characters, uppercase letters and digits)
  /// Avoids ambiguous characters (0, O, 1, I, l)
  String _generateUserCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final bytes = utf8.encode('$random');
    final hash = sha256.convert(bytes);

    final code = StringBuffer();
    for (var i = 0; i < 8; i++) {
      final index = hash.bytes[i] % chars.length;
      code.write(chars[index]);
      if (i == 3) {
        code.write('-');
      }
    }

    return code.toString();
  }

  /// Creates a JSON response
  Response _jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    return Response(
      statusCode,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  /// Creates an RFC 7807 problem response
  Response _problemResponse({
    required int status,
    required String title,
    required String detail,
  }) {
    return Response(
      status,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': title,
        'status': status,
        'detail': detail,
      }),
    );
  }
}
