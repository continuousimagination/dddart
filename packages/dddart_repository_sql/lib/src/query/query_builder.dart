/// Builds SQL queries.
///
/// This class provides utility methods for constructing common SQL queries
/// (SELECT, INSERT, UPDATE, DELETE) with parameterized placeholders.
///
/// Bind values through the generated `?` placeholders. Table/column names and
/// WHERE text are interpolated SQL and must come from trusted application schema;
/// this builder does not sanitize arbitrary identifiers or SQL fragments.
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_sql/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_sql/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_sql/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_sql/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_sql/README.md).
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
