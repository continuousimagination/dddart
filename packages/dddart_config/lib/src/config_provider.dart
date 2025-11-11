/// Abstract interface for configuration providers.
///
/// Providers read configuration from a specific source (file, environment,
/// cloud service) and make values available through a common interface.
///
/// Implementations must provide methods to retrieve individual configuration
/// values, retrieve configuration sections, and reload configuration from
/// the underlying source.
///
/// Example implementation:
/// ```dart
/// class MyConfigProvider implements ConfigProvider {
///   @override
///   String? getString(String key) {
///     // Retrieve value from source
///   }
///
///   @override
///   Map<String, String> getSection(String prefix) {
///     // Retrieve all keys with prefix
///   }
///
///   @override
///   Future<void> reload() async {
///     // Reload from source
///   }
/// }
/// ```
abstract interface class ConfigProvider {
  /// Retrieves a configuration value by key.
  ///
  /// Returns the string value associated with [key], or null if the key
  /// does not exist or has an explicit null value.
  ///
  /// Keys typically use dot notation for hierarchical organization:
  /// - `database.host`
  /// - `database.port`
  /// - `logging.level`
  ///
  /// Example:
  /// ```dart
  /// final host = provider.getString('database.host');
  /// if (host != null) {
  ///   print('Database host: $host');
  /// }
  /// ```
  ///
  /// Returns null if the key does not exist in this provider.
  String? getString(String key);

  /// Retrieves all configuration keys with a given prefix.
  ///
  /// Returns a map of all keys starting with [prefix], with the prefix
  /// removed from the returned keys. This is useful for retrieving
  /// configuration sections or groups of related settings.
  ///
  /// For example, if the configuration contains:
  /// - `database.host` = "localhost"
  /// - `database.port` = "5432"
  /// - `database.name` = "mydb"
  ///
  /// Then `getSection('database')` returns:
  /// ```dart
  /// {
  ///   'host': 'localhost',
  ///   'port': '5432',
  ///   'name': 'mydb'
  /// }
  /// ```
  ///
  /// Returns an empty map if no keys match the prefix.
  Map<String, String> getSection(String prefix);

  /// Reloads configuration from the underlying source.
  ///
  /// Re-reads all configuration values from the source (file, environment,
  /// cloud service, etc.). This allows configuration changes to be picked
  /// up at runtime without restarting the application.
  ///
  /// Example:
  /// ```dart
  /// // Configuration file has been updated
  /// await provider.reload();
  /// // New values are now available
  /// final newValue = provider.getString('some.key');
  /// ```
  ///
  /// Throws an exception if the reload operation fails (e.g., file cannot
  /// be read, network error, parse error). The specific exception type
  /// depends on the provider implementation.
  Future<void> reload();
}
