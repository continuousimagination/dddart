/// SQLite-specific SQL dialect implementation.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';

/// SQLite SQL dialect implementation.
///
/// Provides SQLite-specific SQL syntax and type mappings.
class SqliteDialect extends SqlDialect {
  /// Creates a SQLite dialect instance.
  const SqliteDialect();

  @override
  String get uuidColumnType => 'BLOB';

  @override
  String get textColumnType => 'TEXT';

  @override
  String get integerColumnType => 'INTEGER';

  @override
  String get realColumnType => 'REAL';

  @override
  String get booleanColumnType => 'INTEGER';

  @override
  String get dateTimeColumnType => 'TEXT';

  @override
  Object? encodeUuid(UuidValue uuid) => encodeIdentityKey(uuid.uuid);

  @override
  UuidValue decodeUuid(Object? value) {
    try {
      return UuidValue.fromString(decodeIdentityKey(value));
    } catch (_) {
      throw ArgumentError('Expected a canonical UUID identity key');
    }
  }

  @override
  Object? encodeDateTime(DateTime dateTime) {
    // Store as ISO8601 string in UTC for SQLite TEXT column
    return dateTime.toUtc().toIso8601String();
  }

  @override
  DateTime decodeDateTime(Object? value) {
    if (value == null) {
      throw ArgumentError('Cannot decode null as DateTime');
    }

    if (value is! String) {
      throw ArgumentError(
        'Expected String for DateTime, got ${value.runtimeType}',
      );
    }

    return DateTime.parse(value).toUtc();
  }

  @override
  String createTableIfNotExists(TableDefinition table) {
    final buffer = StringBuffer();
    buffer.writeln('CREATE TABLE IF NOT EXISTS "${table.tableName}" (');

    // Add columns
    final columnDefs = <String>[];
    for (final column in table.columns) {
      final parts = <String>[
        '"${column.name}"',
        column.sqlType,
      ];

      if (column.isPrimaryKey) {
        parts.add('PRIMARY KEY');
      }

      if (!column.isNullable) {
        parts.add('NOT NULL');
      }

      columnDefs.add('  ${parts.join(' ')}');
    }

    buffer.writeln(columnDefs.join(',\n'));

    // Add foreign key constraints
    if (table.foreignKeys.isNotEmpty) {
      buffer.writeln(',');
      final fkDefs = <String>[];
      for (final fk in table.foreignKeys) {
        final onDelete = _cascadeActionToSql(fk.onDelete);
        fkDefs.add(
          '  FOREIGN KEY ("${fk.columnName}") '
          'REFERENCES "${fk.referencedTable}"("${fk.referencedColumn}") '
          'ON DELETE $onDelete',
        );
      }
      buffer.writeln(fkDefs.join(',\n'));
    }

    buffer.write(')');

    return buffer.toString();
  }

  String _cascadeActionToSql(CascadeAction action) {
    switch (action) {
      case CascadeAction.cascade:
        return 'CASCADE';
      case CascadeAction.setNull:
        return 'SET NULL';
      case CascadeAction.restrict:
        return 'RESTRICT';
    }
  }

  @override
  String insertOrReplace(String tableName, List<String> columns) {
    final placeholders = List.filled(columns.length, '?').join(', ');
    final quotedColumns = columns.map((c) => '"$c"').join(', ');
    return 'INSERT OR REPLACE INTO "$tableName" ($quotedColumns) '
        'VALUES ($placeholders)';
  }

  @override
  String selectWithJoins(
    TableDefinition rootTable,
    List<JoinClause> joins,
  ) {
    final buffer = StringBuffer();

    // Build column list with table prefixes
    final columns = <String>[];
    for (final column in rootTable.columns) {
      columns.add('"${rootTable.tableName}"."${column.name}"');
    }

    buffer.write('SELECT ${columns.join(', ')} FROM "${rootTable.tableName}"');

    // Add JOIN clauses
    for (final join in joins) {
      final joinType = _joinTypeToSql(join.type);
      buffer.write(' $joinType "${join.table}" ON ${join.onCondition}');
    }

    return buffer.toString();
  }

  String _joinTypeToSql(JoinType type) {
    switch (type) {
      case JoinType.inner:
        return 'INNER JOIN';
      case JoinType.left:
        return 'LEFT JOIN';
      case JoinType.right:
        return 'RIGHT JOIN';
      case JoinType.fullOuter:
        return 'FULL OUTER JOIN';
    }
  }

  @override
  String delete(String tableName) {
    return 'DELETE FROM "$tableName" WHERE "id" = ?';
  }
}
