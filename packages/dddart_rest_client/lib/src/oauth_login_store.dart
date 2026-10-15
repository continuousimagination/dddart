/// Persisted authorization transaction across a browser navigation/reload.
/// Never put this state in a URL, shared persistent storage, or logs.
abstract class OAuthLoginStore {
  /// Loads the pending authorization transaction, if any.
  Future<Map<String, dynamic>?> load();

  /// Retains the private transaction before navigation.
  Future<void> save(Map<String, dynamic> transaction);

  /// Consumes the transaction so a callback cannot replay it.
  Future<void> clear();
}
