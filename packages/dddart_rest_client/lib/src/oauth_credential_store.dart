/// Platform-owned persistence for OAuth credentials.
///
/// Providers own refresh and token parsing. Consumers decide which credential
/// fields may persist, such as refresh-only tab storage in browser clients.
abstract class OAuthCredentialStore {
  /// Loads retained fields, or null when signed out.
  Future<Map<String, dynamic>?> load();

  /// Persists the fields this platform permits retaining.
  Future<void> save(Map<String, dynamic> credentials);

  /// Removes retained credentials.
  Future<void> clear();
}
