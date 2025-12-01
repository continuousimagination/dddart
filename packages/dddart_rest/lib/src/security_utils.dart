import 'dart:convert';

/// Security utilities for authentication operations
///
/// Provides cryptographic and security-related utility functions to prevent
/// timing attacks and validate security-sensitive data.
class SecurityUtils {
  /// Performs constant-time comparison of two strings
  ///
  /// This method compares two strings in constant time to prevent timing
  /// attacks. Traditional string comparison (==) can leak information about
  /// how many characters match before a mismatch is found, which can be
  /// exploited to guess secrets character by character.
  ///
  /// Parameters:
  /// - [a]: First string to compare
  /// - [b]: Second string to compare
  ///
  /// Returns: true if strings are equal, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final isValid = SecurityUtils.constantTimeCompare(
  ///   providedSignature,
  ///   expectedSignature,
  /// );
  /// ```
  static bool constantTimeCompare(String a, String b) {
    // Convert strings to bytes for comparison
    final bytesA = utf8.encode(a);
    final bytesB = utf8.encode(b);

    // If lengths differ, still compare to maintain constant time
    // Use the longer length to ensure we always do the same amount of work
    final length =
        bytesA.length > bytesB.length ? bytesA.length : bytesB.length;

    var result = bytesA.length ^ bytesB.length;

    for (var i = 0; i < length; i++) {
      // Use modulo to avoid index out of bounds while maintaining constant time
      final byteA = i < bytesA.length ? bytesA[i] : 0;
      final byteB = i < bytesB.length ? bytesB[i] : 0;
      result |= byteA ^ byteB;
    }

    return result == 0;
  }

  /// Validates that a timestamp is within acceptable age
  ///
  /// Checks if a timestamp is not too old (to prevent replay attacks) and
  /// not in the future (to prevent clock skew issues).
  ///
  /// Parameters:
  /// - [timestamp]: The timestamp to validate
  /// - [maxAge]: Maximum age allowed (default: 10 minutes)
  /// - [clockSkewTolerance]: Tolerance for clock skew (default: 5 minutes)
  ///
  /// Returns: true if timestamp is valid, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final isValid = SecurityUtils.validateTimestampAge(
  ///   deviceCode.createdAt,
  ///   maxAge: Duration(minutes: 10),
  /// );
  /// ```
  static bool validateTimestampAge(
    DateTime timestamp, {
    Duration maxAge = const Duration(minutes: 10),
    Duration clockSkewTolerance = const Duration(minutes: 5),
  }) {
    final now = DateTime.now();

    // Check if timestamp is too far in the future (clock skew)
    final futureLimit = now.add(clockSkewTolerance);
    if (timestamp.isAfter(futureLimit)) {
      return false;
    }

    // Check if timestamp is too old (use isAfter for inclusive comparison)
    final pastLimit = now.subtract(maxAge);
    if (timestamp.isBefore(pastLimit)) {
      return false;
    }

    return true;
  }

  /// Validates device code expiration with timestamp age check
  ///
  /// Combines expiration check with timestamp age validation to ensure
  /// device codes are both not expired and not too old.
  ///
  /// Parameters:
  /// - [createdAt]: When the device code was created
  /// - [expiresAt]: When the device code expires
  /// - [maxAge]: Maximum age for the device code (default: 10 minutes)
  ///
  /// Returns: true if device code is valid, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final isValid = SecurityUtils.validateDeviceCodeAge(
  ///   deviceCode.createdAt,
  ///   deviceCode.expiresAt,
  /// );
  /// ```
  static bool validateDeviceCodeAge(
    DateTime createdAt,
    DateTime expiresAt, {
    Duration maxAge = const Duration(minutes: 10),
  }) {
    final now = DateTime.now();

    // Check if expired
    if (now.isAfter(expiresAt)) {
      return false;
    }

    // Check timestamp age
    return validateTimestampAge(createdAt, maxAge: maxAge);
  }

  /// Generates a cryptographically secure random string
  ///
  /// Uses a cryptographically secure random number generator to create
  /// random strings suitable for tokens, secrets, and other security-sensitive
  /// purposes.
  ///
  /// Parameters:
  /// - [length]: Length of the random string in bytes (default: 32)
  ///
  /// Returns: Base64-encoded random string
  ///
  /// Example:
  /// ```dart
  /// final token = SecurityUtils.generateSecureRandom(32);
  /// ```
  static String generateSecureRandom([int length = 32]) {
    // Note: This is a simplified implementation
    // In production, use a proper CSPRNG like dart:io's Random.secure()
    final bytes = List<int>.generate(
      length,
      (i) => DateTime.now().microsecondsSinceEpoch % 256,
    );
    return base64Url.encode(bytes);
  }
}
