/// Abstract interface for SQL database connections.
///
/// Concrete implementations (like SqliteConnection) provide
/// database-specific connection management.
abstract class SqlConnection {
  /// Opens the database connection.
  Future<void> open();

  /// Closes the database connection.
  Future<void> close();

  /// Executes a SQL statement without returning results.
  ///
  /// Use this for INSERT, UPDATE, DELETE, CREATE TABLE, etc.
  Future<void> execute(String sql, [List<Object?>? parameters]);

  /// Executes a SQL query and returns results.
  ///
  /// Use this for SELECT statements.
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]);

  /// Executes multiple statements in a transaction.
  ///
  /// If [action] throws an exception, the transaction is rolled back.
  /// Otherwise, it is committed.
  Future<T> transaction<T>(Future<T> Function() action);

  /// Whether the connection is currently open.
  bool get isOpen;
}
