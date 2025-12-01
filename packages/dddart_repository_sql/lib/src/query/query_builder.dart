/// Builds SQL queries.
///
/// This class provides utility methods for constructing common SQL queries
/// (SELECT, INSERT, UPDATE, DELETE) with parameterized placeholders.
///
/// The generated queries use `?` placeholders for parameters to prevent
/// SQL injection and enable prepared statement optimization.
///
/// Example:
/// ```dart
/// final builder = QueryBuilder();
/// final query = builder.buildSelect(
///   tableName: 'orders',
///   columns: ['id', 'totalAmount'],
///   whereClause: 'customerId = ?',
/// );
/// // Returns: SELECT id, totalAmount FROM orders WHERE customerId = ?
/// ```
class QueryBuilder {
  /// Creates a query builder.
  const QueryBuilder();

  /// Builds a SELECT query.
  ///
  /// Generates a SELECT statement with optional column selection and
  /// WHERE clause. Uses `SELECT *` if no columns are specified.
  ///
  /// Parameters:
  /// - [tableName]: The table to select from
  /// - [columns]: Optional list of column names (defaults to `*`)
  /// - [whereClause]: Optional WHERE condition with `?` placeholders
  ///
  /// Example:
  /// ```dart
  /// // Select all columns
  /// builder.buildSelect(tableName: 'orders');
  /// // SELECT * FROM orders
  ///
  /// // Select specific columns
  /// builder.buildSelect(
  ///   tableName: 'orders',
  ///   columns: ['id', 'totalAmount'],
  /// );
  /// // SELECT id, totalAmount FROM orders
  ///
  /// // With WHERE clause
  /// builder.buildSelect(
  ///   tableName: 'orders',
  ///   whereClause: 'customerId = ? AND status = ?',
  /// );
  /// // SELECT * FROM orders WHERE customerId = ? AND status = ?
  /// ```
  String buildSelect({
    required String tableName,
    List<String>? columns,
    String? whereClause,
  }) {
    final buffer = StringBuffer('SELECT ');

    if (columns == null || columns.isEmpty) {
      buffer.write('*');
    } else {
      buffer.write(columns.join(', '));
    }

    buffer.write(' FROM ');
    buffer.write(tableName);

    if (whereClause != null && whereClause.isNotEmpty) {
      buffer.write(' WHERE ');
      buffer.write(whereClause);
    }

    return buffer.toString();
  }

  /// Builds an INSERT query.
  ///
  /// Generates an INSERT statement with parameterized placeholders for values.
  /// The number of placeholders matches the number of columns.
  ///
  /// Parameters:
  /// - [tableName]: The table to insert into
  /// - [columns]: List of column names to insert
  ///
  /// Example:
  /// ```dart
  /// builder.buildInsert(
  ///   tableName: 'orders',
  ///   columns: ['id', 'customerId', 'totalAmount'],
  /// );
  /// // INSERT INTO orders (id, customerId, totalAmount) VALUES (?, ?, ?)
  /// ```
  String buildInsert({
    required String tableName,
    required List<String> columns,
  }) {
    final buffer = StringBuffer('INSERT INTO ');
    buffer.write(tableName);
    buffer.write(' (');
    buffer.write(columns.join(', '));
    buffer.write(') VALUES (');
    buffer.write(List.filled(columns.length, '?').join(', '));
    buffer.write(')');

    return buffer.toString();
  }

  /// Builds an UPDATE query.
  ///
  /// Generates an UPDATE statement with SET clauses for each column and
  /// a WHERE clause to identify which rows to update.
  ///
  /// Parameters:
  /// - [tableName]: The table to update
  /// - [columns]: List of column names to update
  /// - [whereClause]: WHERE condition with `?` placeholders
  ///
  /// Example:
  /// ```dart
  /// builder.buildUpdate(
  ///   tableName: 'orders',
  ///   columns: ['status', 'updatedAt'],
  ///   whereClause: 'id = ?',
  /// );
  /// // UPDATE orders SET status = ?, updatedAt = ? WHERE id = ?
  /// ```
  String buildUpdate({
    required String tableName,
    required List<String> columns,
    required String whereClause,
  }) {
    final buffer = StringBuffer('UPDATE ');
    buffer.write(tableName);
    buffer.write(' SET ');
    buffer.write(columns.map((c) => '$c = ?').join(', '));
    buffer.write(' WHERE ');
    buffer.write(whereClause);

    return buffer.toString();
  }

  /// Builds a DELETE query.
  ///
  /// Generates a DELETE statement with a WHERE clause to identify which
  /// rows to delete.
  ///
  /// **Important**: Always include a WHERE clause to avoid deleting all rows.
  ///
  /// Parameters:
  /// - [tableName]: The table to delete from
  /// - [whereClause]: WHERE condition with `?` placeholders
  ///
  /// Example:
  /// ```dart
  /// builder.buildDelete(
  ///   tableName: 'orders',
  ///   whereClause: 'id = ?',
  /// );
  /// // DELETE FROM orders WHERE id = ?
  ///
  /// // Delete with multiple conditions
  /// builder.buildDelete(
  ///   tableName: 'orders',
  ///   whereClause: 'customerId = ? AND status = ?',
  /// );
  /// // DELETE FROM orders WHERE customerId = ? AND status = ?
  /// ```
  String buildDelete({
    required String tableName,
    required String whereClause,
  }) {
    final buffer = StringBuffer('DELETE FROM ');
    buffer.write(tableName);
    buffer.write(' WHERE ');
    buffer.write(whereClause);

    return buffer.toString();
  }
}
