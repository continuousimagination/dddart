import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dddart_rest/src/auth_handler.dart';
import 'package:dddart_rest/src/auth_result.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

/// Handles JWT validation for OAuth2/OIDC providers
///
/// Validates JWTs issued by external OAuth providers (like AWS Cognito, Auth0,
/// Okta) by fetching and caching the provider's public keys (JWKS) and
/// verifying JWT signatures.
///
/// Generic over [TClaims] to support strongly-typed custom claims.
///
/// Example:
/// ```dart
/// final authHandler = OAuthJwtAuthHandler<UserClaims>(
///   jwksUri: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxx/.well-known/jwks.json',
///   parseClaimsFromJson: (json) => UserClaims.fromJson(json),
///   issuer: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxx',
///   audience: 'my-client-id',
/// );
/// ```
class OAuthJwtAuthHandler<TClaims> extends AuthHandler<TClaims> {
  /// Creates an OAuth JWT authentication handler
  OAuthJwtAuthHandler({
    required this.jwksUri,
    required TClaims Function(Map<String, dynamic>) parseClaimsFromJson,
    this.issuer,
    this.audience,
    this.cacheDuration = const Duration(hours: 1),
    http.Client? httpClient,
  })  : _parseClaimsFromJson = parseClaimsFromJson,
        _httpClient = httpClient ?? http.Client();

  /// URI to fetch JSON Web Key Set (public keys)
  final String jwksUri;

  /// Expected issuer claim
  final String? issuer;

  /// Expected audience claim
  final String? audience;

  /// How long to cache JWKS before refetching
  final Duration cacheDuration;

  /// HTTP client for fetching JWKS
  final http.Client _httpClient;

  /// Function to parse claims from JSON
  final TClaims Function(Map<String, dynamic>) _parseClaimsFromJson;

  /// Cached JWKS
  Map<String, dynamic>? _cachedJwks;

  /// When JWKS was cached
  DateTime? _jwksCachedAt;

  @override
  Future<AuthResult<TClaims>> authenticate(Request request) async {
    try {
      // Extract Bearer token from Authorization header
      final authHeader = request.headers['authorization'];
      if (authHeader == null) {
        return AuthResult.failure('Missing authorization header');
      }

      if (!authHeader.startsWith('Bearer ')) {
        return AuthResult.failure('Invalid token format');
      }

      final token = authHeader.substring(7);

      // Decode JWT without verification to extract kid
      final parts = token.split('.');
      if (parts.length != 3) {
        return AuthResult.failure('Invalid token format');
      }

      // Decode header to get kid (key ID)
      final headerJson = _decodeBase64(parts[0]);
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      final kid = header['kid'] as String?;

      if (kid == null) {
        return AuthResult.failure('Token missing key ID');
      }

      // Fetch JWKS if not cached or expired
      final jwks = await _getJwks();

      // Find matching public key
      final keys = jwks['keys'] as List<dynamic>?;
      if (keys == null || keys.isEmpty) {
        return AuthResult.failure('No keys found in JWKS');
      }

      Map<String, dynamic>? matchingKey;
      for (final key in keys) {
        if (key is Map<String, dynamic> && key['kid'] == kid) {
          matchingKey = key;
          break;
        }
      }

      if (matchingKey == null) {
        return AuthResult.failure('No matching key found for token');
      }

      // Verify signature using public key
      JWT? jwt;
      try {
        // Convert JWK to public key and verify
        final publicKey = _jwkToPublicKey(matchingKey);
        jwt = JWT.verify(token, publicKey);
      } on JWTExpiredException {
        return AuthResult.failure('Token has expired');
      } on JWTException {
        return AuthResult.failure('Invalid token signature');
      }

      // Verify issuer if configured
      if (issuer != null) {
        final tokenIssuer = jwt.payload['iss'] as String?;
        if (tokenIssuer != issuer) {
          return AuthResult.failure('Invalid token issuer');
        }
      }

      // Verify audience if configured
      if (audience != null) {
        final tokenAudience = jwt.payload['aud'];
        // Audience can be a string or array of strings
        if (tokenAudience is String) {
          if (tokenAudience != audience) {
            return AuthResult.failure('Invalid token audience');
          }
        } else if (tokenAudience is List) {
          if (!tokenAudience.contains(audience)) {
            return AuthResult.failure('Invalid token audience');
          }
        } else {
          return AuthResult.failure('Invalid token audience');
        }
      }

      // Extract user ID from sub claim
      final userId = jwt.payload['sub'] as String?;
      if (userId == null) {
        return AuthResult.failure('Token missing subject');
      }

      // Parse claims using provided callback
      final claims = _parseClaimsFromJson(jwt.payload as Map<String, dynamic>);

      return AuthResult.success(
        userId: userId,
        claims: claims,
      );
    } catch (e) {
      return AuthResult.failure('Invalid token: $e');
    }
  }

  /// Fetches JWKS from provider, using cache if available and not expired
  Future<Map<String, dynamic>> _getJwks() async {
    // Check if cache is valid
    if (_cachedJwks != null && _jwksCachedAt != null) {
      final cacheAge = DateTime.now().difference(_jwksCachedAt!);
      if (cacheAge < cacheDuration) {
        return _cachedJwks!;
      }
    }

    // Fetch fresh JWKS
    return _fetchJwks();
  }

  /// Fetches JWKS from provider's endpoint
  Future<Map<String, dynamic>> _fetchJwks() async {
    try {
      final response = await _httpClient.get(Uri.parse(jwksUri));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch JWKS: ${response.statusCode}');
      }

      final jwks = jsonDecode(response.body) as Map<String, dynamic>;

      // Cache the result
      _cachedJwks = jwks;
      _jwksCachedAt = DateTime.now();

      return jwks;
    } catch (e) {
      throw Exception('Failed to fetch JWKS: $e');
    }
  }

  /// Converts a JWK (JSON Web Key) to a public key for verification
  ///
  /// Supports RSA keys (RS256, RS384, RS512) which are commonly used by
  /// OAuth providers like Cognito, Auth0, and Okta.
  ///
  /// This converts the JWK format (with n and e components) to PEM format
  /// which is required by the dart_jsonwebtoken library.
  dynamic _jwkToPublicKey(Map<String, dynamic> jwk) {
    final kty = jwk['kty'] as String?;

    if (kty == 'RSA') {
      // RSA public key
      final n = jwk['n'] as String?;
      final e = jwk['e'] as String?;

      if (n == null || e == null) {
        throw Exception('Invalid RSA key: missing n or e');
      }

      // Convert JWK to PEM format
      final pem = _jwkToPem(n, e);
      return RSAPublicKey(pem);
    } else {
      throw Exception('Unsupported key type: $kty');
    }
  }

  /// Converts JWK RSA components (n, e) to PEM format
  ///
  /// This creates a DER-encoded RSA public key and wraps it in PEM format.
  /// The format follows the PKCS#1 RSAPublicKey structure.
  String _jwkToPem(String n, String e) {
    // Decode base64url to bytes
    final nBytes = base64Url.decode(_addBase64Padding(n));
    final eBytes = base64Url.decode(_addBase64Padding(e));

    // Build ASN.1 DER structure for RSA public key
    // SubjectPublicKeyInfo ::= SEQUENCE {
    //   algorithm AlgorithmIdentifier,
    //   subjectPublicKey BIT STRING
    // }

    // First, build the inner RSAPublicKey structure
    // RSAPublicKey ::= SEQUENCE {
    //   modulus INTEGER,
    //   publicExponent INTEGER
    // }
    final modulusInt = _buildDerInteger(nBytes);
    final exponentInt = _buildDerInteger(eBytes);
    final innerSequence = _buildDerSequence([...modulusInt, ...exponentInt]);

    // Wrap in BIT STRING (with 0 unused bits)
    final bitString = [
      0x03,
      ..._buildDerLength(innerSequence.length + 1),
      0x00,
      ...innerSequence,
    ];

    // Algorithm identifier for RSA encryption
    final algorithmId = [
      0x30, 0x0D, // SEQUENCE
      0x06, 0x09, // OID
      0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01,
      0x01, // RSA encryption OID
      0x05, 0x00, // NULL
    ];

    // Build outer SEQUENCE
    final outerSequence = _buildDerSequence([...algorithmId, ...bitString]);

    // Encode as base64 and wrap in PEM format
    final base64Der = base64.encode(outerSequence);

    // Split into 64-character lines
    final lines = <String>[];
    for (var i = 0; i < base64Der.length; i += 64) {
      final end = (i + 64 < base64Der.length) ? i + 64 : base64Der.length;
      lines.add(base64Der.substring(i, end));
    }

    return '-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----';
  }

  /// Builds a DER SEQUENCE from a list of bytes
  List<int> _buildDerSequence(List<int> contents) {
    return [0x30, ..._buildDerLength(contents.length), ...contents];
  }

  /// Builds a DER INTEGER from bytes
  List<int> _buildDerInteger(List<int> bytes) {
    // Add leading zero if high bit is set (to indicate positive number)
    final needsLeadingZero = bytes.isNotEmpty && bytes[0] >= 0x80;
    final intBytes = needsLeadingZero ? [0x00, ...bytes] : bytes;
    return [0x02, ..._buildDerLength(intBytes.length), ...intBytes];
  }

  /// Builds DER length encoding
  List<int> _buildDerLength(int length) {
    if (length < 128) {
      return [length];
    } else if (length < 256) {
      return [0x81, length];
    } else {
      return [0x82, (length >> 8) & 0xFF, length & 0xFF];
    }
  }

  /// Adds padding to base64url string
  String _addBase64Padding(String str) {
    switch (str.length % 4) {
      case 0:
        return str;
      case 2:
        return '$str==';
      case 3:
        return '$str=';
      default:
        throw Exception('Invalid base64 string');
    }
  }

  /// Decodes base64url encoded string
  String _decodeBase64(String str) {
    // Add padding if needed
    var output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
      case 3:
        output += '=';
      default:
        throw Exception('Invalid base64 string');
    }
    return utf8.decode(base64.decode(output));
  }
}
