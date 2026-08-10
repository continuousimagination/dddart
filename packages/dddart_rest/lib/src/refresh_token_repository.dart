import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/refresh_token.dart';

/// Persistence contract for refresh tokens.
///
/// The token-specific lookup avoids requiring full repository enumeration.
abstract interface class RefreshTokenRepository<T extends RefreshToken>
    implements Repository<T> {
  /// Finds a refresh token by its opaque token value.
  ///
  /// Returns `null` when the token is absent. Backend failures must propagate
  /// so callers can distinguish an unavailable store from an invalid token.
  Future<T?> findByToken(String token);
}

/// Instance-local in-memory implementation of [RefreshTokenRepository].
///
/// This implementation is intended for examples and tests. It inherits the
/// concrete inspection conveniences provided by [InMemoryRepository].
final class InMemoryRefreshTokenRepository<T extends RefreshToken>
    extends InMemoryRepository<T> implements RefreshTokenRepository<T> {
  @override
  Future<T?> findByToken(String token) {
    for (final refreshToken in getAllSync()) {
      if (refreshToken.token == token) {
        return Future.value(refreshToken);
      }
    }
    return Future.value();
  }
}
