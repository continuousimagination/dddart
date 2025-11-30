import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:http/http.dart' as http;

/// Auth provider for AWS Cognito device flow
///
/// Implements device flow authentication using AWS Cognito endpoints.
/// Handles token refresh, credential storage, and automatic token management.
class CognitoAuthProvider implements AuthProvider {
  /// Creates a Cognito auth provider
  ///
  /// - [cognitoDomain]: Cognito domain (e.g., 'https://mydomain.auth.us-east-1.amazoncognito.com')
  /// - [clientId]: Cognito app client ID
  /// - [credentialsPath]: Path to store credentials file
  /// - [httpClient]: Optional HTTP client (defaults to [http.Client])
  CognitoAuthProvider({
    required this.cognitoDomain,
    required this.clientId,
    required this.credentialsPath,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Cognito domain
  final String cognitoDomain;

  /// Cognito app client ID
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
  Future<void> login() async {
    // 1. Request device code from Cognito
    final response = await _httpClient.post(
      Uri.parse('$cognitoDomain/oauth2/device'),
      body: 'client_id=$clientId',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'Failed to request device code: ${response.body}',
      );
    }

    final deviceCodeResponse = _CognitoDeviceCodeResponse.fromJson(
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

  Future<_CognitoTokens> _pollForTokens(
    _CognitoDeviceCodeResponse deviceCode,
  ) async {
    final deadline = DateTime.now().add(
      Duration(seconds: deviceCode.expiresIn),
    );
    var interval = deviceCode.interval;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: interval));

      final response = await _httpClient.post(
        Uri.parse('$cognitoDomain/oauth2/token'),
        body: 'grant_type=urn:ietf:params:oauth:grant-type:device_code'
            '&device_code=${deviceCode.deviceCode}'
            '&client_id=$clientId',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      if (response.statusCode == 200) {
        return _CognitoTokens.fromJson(
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

  Future<_CognitoTokens> _refresh(String refreshToken) async {
    final response = await _httpClient.post(
      Uri.parse('$cognitoDomain/oauth2/token'),
      body: 'grant_type=refresh_token'
          '&refresh_token=$refreshToken'
          '&client_id=$clientId',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    if (response.statusCode != 200) {
      throw AuthenticationException('Token refresh failed');
    }

    return _CognitoTokens.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> logout() async {
    // Cognito doesn't have a logout endpoint for device flow
    // Just delete local credentials
    await _deleteCredentials();
  }

  Future<_StoredCredentials?> _loadCredentials() async {
    try {
      final file = File(credentialsPath);
      if (!await file.exists()) {
        return null;
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return _StoredCredentials.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveCredentials(_CognitoTokens tokens) async {
    final file = File(credentialsPath);
    await file.parent.create(recursive: true);

    final creds = _StoredCredentials(
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

/// Cognito device code response
class _CognitoDeviceCodeResponse {
  _CognitoDeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory _CognitoDeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    return _CognitoDeviceCodeResponse(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int,
    );
  }

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;
}

/// Cognito token response
class _CognitoTokens {
  _CognitoTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory _CognitoTokens.fromJson(Map<String, dynamic> json) {
    return _CognitoTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

/// Stored credentials
class _StoredCredentials {
  _StoredCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory _StoredCredentials.fromJson(Map<String, dynamic> json) {
    return _StoredCredentials(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };
}
