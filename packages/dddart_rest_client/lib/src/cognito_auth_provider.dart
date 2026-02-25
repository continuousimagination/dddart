import 'dart:convert';
import 'dart:io';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:dddart_rest_client/src/localhost_callback_strategy.dart';
import 'package:dddart_rest_client/src/oauth_callback_strategy.dart';
import 'package:dddart_rest_client/src/pkce_generator.dart';
import 'package:http/http.dart' as http;

class CognitoAuthProvider implements AuthProvider {
  CognitoAuthProvider({
    required this.cognitoDomain,
    required this.clientId,
    required this.credentialsPath,
    OAuthCallbackStrategy? callbackStrategy,
    List<String>? scopes,
    http.Client? httpClient,
  })  : callbackStrategy = callbackStrategy ?? LocalhostCallbackStrategy(),
        scopes = scopes ?? ['openid', 'email', 'profile'],
        _httpClient = httpClient ?? http.Client();

  final String cognitoDomain;
  final String clientId;
  final String credentialsPath;
  final OAuthCallbackStrategy callbackStrategy;
  final List<String> scopes;
  final http.Client _httpClient;

  @override
  Future<String> getAccessToken() async {
    final creds = await _loadCredentials();
    if (creds != null && !creds.isExpired) {
      return creds.accessToken;
    }
    if (creds?.refreshToken != null) {
      try {
        final newTokens = await _refresh(creds!.refreshToken);
        await _saveCredentials(newTokens);
        return newTokens.accessToken;
      } catch (e) {
        // Refresh failed - rethrow the actual error
        rethrow;
      }
    }
    throw AuthenticationException('Not authenticated. Run login command.');
  }

  @override
  Future<void> login() async {
    final codeVerifier = PKCEGenerator.generateCodeVerifier();
    final codeChallenge = PKCEGenerator.generateCodeChallenge(codeVerifier);
    final state = PKCEGenerator.generateState();

    final authUrl = _buildAuthorizationUrl(
      codeChallenge: codeChallenge,
      state: state,
    );

    final result = await callbackStrategy.waitForCallback(
      authorizationUrl: authUrl,
      expectedState: state,
    );

    if (result.hasError) {
      throw AuthenticationException(
        'OAuth error: ${result.error} - ${result.errorDescription}',
      );
    }

    if (result.state != state) {
      throw AuthenticationException('State mismatch - possible CSRF attack');
    }

    if (result.code.isEmpty) {
      throw AuthenticationException('No authorization code received');
    }

    final tokens = await _exchangeCodeForTokens(result.code, codeVerifier);
    await _saveCredentials(tokens);
    print('✓ Successfully authenticated!');
  }

  String _buildAuthorizationUrl({
    required String codeChallenge,
    required String state,
  }) {
    return Uri.parse('$cognitoDomain/oauth2/authorize').replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': callbackStrategy.getRedirectUri(),
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'prompt': 'select_account', // Force account selection screen
      },
    ).toString();
  }

  Future<_CognitoTokens> _exchangeCodeForTokens(
    String code,
    String codeVerifier,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$cognitoDomain/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': callbackStrategy.getRedirectUri(),
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'Failed to exchange code for tokens: ${response.body}',
      );
    }

    return _CognitoTokens.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
      throw AuthenticationException(
        'Token refresh failed: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final existingCreds = await _loadCredentials();

    return _CognitoTokens(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String? ?? existingCreds!.idToken,
      refreshToken: json['refresh_token'] as String? ?? refreshToken,
      expiresIn: json['expires_in'] as int,
    );
  }

  @override
  Future<void> logout() async {
    await _deleteCredentials();
  }

  /// Deletes the current Cognito user account.
  ///
  /// This permanently deletes the user from AWS Cognito using the DeleteUser API.
  /// The user must be authenticated (have a valid access token) to delete their account.
  ///
  /// After successful deletion, local credentials are automatically cleared.
  ///
  /// Throws [AuthenticationException] if:
  /// - The user is not authenticated
  /// - The access token is invalid or expired
  /// - The Cognito API returns an error
  Future<void> deleteUser() async {
    final accessToken = await getAccessToken();

    // Call Cognito's DeleteUser API
    // This endpoint doesn't require the full domain URL, just the region-specific endpoint
    final response = await _httpClient.post(
      Uri.parse('https://cognito-idp.${_extractRegion()}.amazonaws.com/'),
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.DeleteUser',
      },
      body: jsonEncode({
        'AccessToken': accessToken,
      }),
    );

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'Failed to delete user: ${response.body}',
      );
    }

    // Clear local credentials after successful deletion
    await _deleteCredentials();
  }

  /// Extracts the AWS region from the Cognito domain.
  ///
  /// Cognito domains follow the pattern: https://{domain}.auth.{region}.amazoncognito.com
  String _extractRegion() {
    final uri = Uri.parse(cognitoDomain);
    final parts = uri.host.split('.');
    if (parts.length >= 3 && parts[1] == 'auth') {
      return parts[2]; // e.g., 'us-east-1'
    }
    // Fallback to us-east-1 if we can't parse the region
    return 'us-east-1';
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

  @override
  Future<String> getIdToken() async {
    final creds = await _loadCredentials();
    if (creds != null && !creds.isExpired) {
      return creds.idToken;
    }
    if (creds?.refreshToken != null) {
      try {
        final newTokens = await _refresh(creds!.refreshToken);
        await _saveCredentials(newTokens);
        return newTokens.idToken;
      } catch (e) {
        // Refresh failed - rethrow the actual error
        rethrow;
      }
    }
    throw AuthenticationException('Not authenticated. Run login command.');
  }

  Future<String> getCognitoSub() async {
    final claims = await getIdTokenClaims();
    final sub = claims['sub'] as String?;
    if (sub == null) {
      throw AuthenticationException('ID token missing sub claim');
    }
    return sub;
  }

  Future<Map<String, dynamic>> getIdTokenClaims() async {
    final idToken = await getIdToken();
    final parts = idToken.split('.');
    if (parts.length != 3) {
      throw AuthenticationException('Invalid ID token format');
    }
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return jsonDecode(payload) as Map<String, dynamic>;
  }

  Future<_StoredCredentials?> _loadCredentials() async {
    try {
      final file = File(credentialsPath);
      if (!await file.exists()) return null;
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
      idToken: tokens.idToken,
      refreshToken: tokens.refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
    );
    await file.writeAsString(jsonEncode(creds.toJson()));
  }

  Future<void> _deleteCredentials() async {
    try {
      final file = File(credentialsPath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      // Ignore
    }
  }
}

class _CognitoTokens {
  _CognitoTokens({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory _CognitoTokens.fromJson(Map<String, dynamic> json) {
    return _CognitoTokens(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String accessToken;
  final String idToken;
  final String refreshToken;
  final int expiresIn;
}

class _StoredCredentials {
  _StoredCredentials({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory _StoredCredentials.fromJson(Map<String, dynamic> json) {
    return _StoredCredentials(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String accessToken;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'id_token': idToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };
}
