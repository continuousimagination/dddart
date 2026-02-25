import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:http/http.dart' as http;

/// Auth provider for self-hosted device flow
///
/// Implements device flow authentication for CLI tools and applications.
/// Handles token refresh, credential storage, and automatic token management.
class DeviceFlowAuthProvider implements AuthProvider {
  /// Creates a device flow auth provider
  ///
  /// - [authUrl]: Base URL for auth endpoints (e.g., 'https://api.example.com/auth')
  /// - [clientId]: Client ID for this application
  /// - [credentialsPath]: Path to store credentials file
  /// - [httpClient]: Optional HTTP client (defaults to [http.Client])
  DeviceFlowAuthProvider({
    required this.authUrl,
    required this.clientId,
    required this.credentialsPath,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Base URL for auth endpoints
  final String authUrl;

  /// Client ID for this application
  final String clientId;

  /// Path to credentials file
  final String credentialsPath;

  /// HTTP client
  final http.Client _httpClient;

  @override
  Future<String> getAccessToken() async {
    final creds = await _loadCredentials();

    // Check if access token is still valid
    if (creds != null && !creds.isExpired) {
      return creds.accessToken;
    }

    // Try to refresh
    if (creds?.refreshToken != null) {
      try {
        final newTokens = await _refresh(creds!.refreshToken);
        await _saveCredentials(newTokens);
        return newTokens.accessToken;
      } catch (e) {
        // Refresh failed, need to login again
      }
    }

    throw AuthenticationException('Not authenticated. Run login command.');
  }

  @override
  Future<String> getIdToken() async {
    // For device flow, the access token IS the JWT
    return getAccessToken();
  }

  @override
  Future<void> login() async {
    // 1. Request device code
    final response = await _httpClient.post(
      Uri.parse('$authUrl/device'),
      body: jsonEncode({'client_id': clientId}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'Failed to request device code: ${response.body}',
      );
    }

    final deviceCodeResponse = DeviceCodeResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    // 2. Display to user
    print('Visit: ${deviceCodeResponse.verificationUri}');
    print('Enter code: ${deviceCodeResponse.userCode}');
    print('\nWaiting for authorization...');

    // 3. Poll for tokens
    final tokens = await _pollForTokens(deviceCodeResponse);

    // 4. Save credentials
    await _saveCredentials(tokens);
    print('✓ Successfully authenticated!');
  }

  Future<Tokens> _pollForTokens(DeviceCodeResponse deviceCode) async {
    final deadline = DateTime.now().add(
      Duration(seconds: deviceCode.expiresIn),
    );
    var interval = deviceCode.interval;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: interval));

      final response = await _httpClient.post(
        Uri.parse('$authUrl/token'),
        body: jsonEncode({
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': deviceCode.deviceCode,
          'client_id': clientId,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return Tokens.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final error = errorBody['error'] as String?;

      if (error == 'authorization_pending') {
        continue;
      } else if (error == 'slow_down') {
        interval += 5;
        continue;
      } else {
        throw AuthenticationException('Authentication failed: $error');
      }
    }

    throw AuthenticationException('Authentication timed out');
  }

  Future<Tokens> _refresh(String refreshToken) async {
    final response = await _httpClient.post(
      Uri.parse('$authUrl/refresh'),
      body: jsonEncode({'refresh_token': refreshToken}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw AuthenticationException('Token refresh failed');
    }

    return Tokens.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> logout() async {
    final creds = await _loadCredentials();
    if (creds?.refreshToken != null) {
      try {
        await _httpClient.post(
          Uri.parse('$authUrl/logout'),
          body: jsonEncode({'refresh_token': creds!.refreshToken}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        // Ignore errors during logout
      }
    }
    await _deleteCredentials();
  }

  Future<StoredCredentials?> _loadCredentials() async {
    try {
      final file = File(credentialsPath);
      if (!await file.exists()) {
        return null;
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return StoredCredentials.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveCredentials(Tokens tokens) async {
    final file = File(credentialsPath);
    await file.parent.create(recursive: true);

    final creds = StoredCredentials(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
    );

    await file.writeAsString(jsonEncode(creds.toJson()));
  }

  Future<void> _deleteCredentials() async {
    try {
      final file = File(credentialsPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors during deletion
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      await getAccessToken();
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Device code response from server
class DeviceCodeResponse {
  /// Creates a device code response
  DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  /// Creates from JSON
  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    return DeviceCodeResponse(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int,
    );
  }

  /// Device code (long, random)
  final String deviceCode;

  /// User code (short, human-readable)
  final String userCode;

  /// Verification URI
  final String verificationUri;

  /// Seconds until expiration
  final int expiresIn;

  /// Polling interval in seconds
  final int interval;
}

/// Token response from server
class Tokens {
  /// Creates a tokens response
  Tokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });

  /// Creates from JSON
  factory Tokens.fromJson(Map<String, dynamic> json) {
    return Tokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String? ?? 'Bearer',
    );
  }

  /// Access token (JWT)
  final String accessToken;

  /// Refresh token (opaque)
  final String refreshToken;

  /// Seconds until access token expires
  final int expiresIn;

  /// Token type (always "Bearer")
  final String tokenType;
}

/// Stored credentials
class StoredCredentials {
  /// Creates stored credentials
  StoredCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  /// Creates from JSON
  factory StoredCredentials.fromJson(Map<String, dynamic> json) {
    return StoredCredentials(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Access token
  final String accessToken;

  /// Refresh token
  final String refreshToken;

  /// When access token expires
  final DateTime expiresAt;

  /// Checks if access token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };
}
