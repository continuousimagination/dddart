/// MySQL-specific SQL dialect implementation.
library;

import 'dart:typed_data';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';

/// MySQL SQL dialect implementation.
///
/// Provides MySQL-specific SQL syntax and type mappings.
class MysqlDialect implements SqlDialect {
  /// Creates a MySQL dialect instance.
  const MysqlDialect();

  @override
  String get uuidColumnType => 'BINARY(16)';

  @override
  String get textColumnType => 'VARCHAR(255)';

  @override
  String get integerColumnType => 'BIGINT';

  @override
  String get realColumnType => 'DOUBLE';

  @override
  String get booleanColumnType => 'TINYINT(1)';

  @override
  Object? encodeUuid(UuidValue uuid) {
    // Convert UUID string to 16-byte BINARY for efficient storage
    final uuidString = uuid.uuid.replaceAll('-', '');
    final bytes = Uint8List(16);

    for (var i = 0; i < 16; i++) {
      final hex = uuidString.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(hex, radix: 16);
    }

    return bytes;
  }

  @override
  UuidValue decodeUuid(Object? value) {
    if (value == null) {
      throw ArgumentError('Cannot decode null as UuidValue');
    }

    if (value is! Uint8List && value is! List<int>) {
      throw ArgumentError(
        'Expected Uint8List or List<int>, got ${value.runtimeType}',
      );
    }

    final bytes =
        value is Uint8List ? value : Uint8List.fromList(value as List<int>);

    if (bytes.length != 16) {
      throw ArgumentError(
        'UUID BLOB must be exactly 16 bytes, got ${bytes.length}',
      );
    }

    // Convert 16 bytes back to UUID string format
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuidString = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';

    return UuidValue.fromString(uuidString);
  }

  @override
  Object? encodeDateTime(DateTime dateTime) {
    // Store as milliseconds since epoch (INTEGER in MySQL)
    return dateTime.millisecondsSinceEpoch;
  }

  @override
  DateTime decodeDateTime(Object? value) {
    if (value == null) {
      throw ArgumentError('Cannot decode null as DateTime');
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is DateTime) {
      return value;
    }

    throw ArgumentError(
      'Expected int or DateTime for DateTime, got ${value.runtimeType}',
    );
  }

  @override
  String createTableIfNotExists(TableDefinition table) {
    final buffer = StringBuffer()
      ..writeln('CREATE TABLE IF NOT EXISTS `${table.tableName}` (');

    // Add columns
    final columnDefs = <String>[];
    for (final column in table.columns) {
      final parts = <String>[
        '`${column.name}`',
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

    buffer.write(columnDefs.join(',\n'));

    // Add foreign key constraints
    if (table.foreignKeys.isNotEmpty) {
      final fkDefs = <String>[];
      for (final fk in table.foreignKeys) {
        final onDelete = _cascadeActionToSql(fk.onDelete);
        fkDefs.add(
          '  FOREIGN KEY (`${fk.columnName}`) '
          'REFERENCES `${fk.referencedTable}`(`${fk.referencedColumn}`) '
          'ON DELETE $onDelete',
        );
      }
      buffer
        ..writeln(',')
        ..write(fkDefs.join(',\n'));
    }

    // Add MySQL-specific table options
    buffer.write('\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

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
    final escapedColumns = columns.map((col) => '`$col`').toList();
    final updateClauses =
        escapedColumns.map((col) => '$col = VALUES($col)').join(', ');

    return 'INSERT INTO `$tableName` (${escapedColumns.join(', ')}) '
        'VALUES ($placeholders) '
        'ON DUPLICATE KEY UPDATE $updateClauses';
  }

  @override
  String selectWithJoins(
    TableDefinition rootTable,
    List<JoinClause> joins,
  ) {
    final buffer = StringBuffer();

    // Build column list with table prefixes
    // Convert BINARY UUID columns to strings using BIN_TO_UUID
    final columns = <String>[];
    for (final column in rootTable.columns) {
      if (column.sqlType == 'BINARY(16)') {
        // Convert binary UUID to string format
        columns.add(
          'BIN_TO_UUID(`${rootTable.tableName}`.`${column.name}`) as `${column.name}`',
        );
      } else {
        columns.add('`${rootTable.tableName}`.`${column.name}`');
      }
    }

    buffer.write('SELECT ${columns.join(', ')} FROM `${rootTable.tableName}`');

    // Add JOIN clauses
    for (final join in joins) {
      final joinType = _joinTypeToSql(join.type);
      buffer.write(' $joinType `${join.table}` ON ${join.onCondition}');
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
    return 'DELETE FROM `$tableName` WHERE `id` = ?';
  }
}
