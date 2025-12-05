/// Property-based tests for SQL generation consistency.
///
/// **Feature: mysql-driver-migration, Property 7: SQL generation consistency**
/// **Validates: Requirements 4.3, 8.3**
@Tags(['property-test'])
library;

import 'dart:math';

import 'package:dddart_repository_mysql/src/dialect/mysql_dialect.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:test/test.dart';

void main() {
  group('SQL Generation Consistency Property Tests', () {
    late MysqlDialect dialect;

    setUp(() {
      dialect = const MysqlDialect();
    });

    // **Feature: mysql-driver-migration, Property 7: SQL generation consistency**
    // **Validates: Requirements 4.3, 8.3**
    group('Property 7: SQL generation consistency', () {
      test(
        'should generate consistent CREATE TABLE statements for any table definition',
        () {
          final random = Random(100);

          for (var i = 0; i < 100; i++) {
            // Generate random table definition
            final table = _generateRandomTableDefinition(random);

            // Generate SQL twice
            final sql1 = dialect.createTableIfNotExists(table);
            final sql2 = dialect.createTableIfNotExists(table);

            // Verify consistency
            expect(
              sql1,
              equals(sql2),
              reason: 'Iteration $i: SQL generation should be deterministic',
            );

            // Verify required MySQL syntax elements
            expect(
              sql1,
              contains('CREATE TABLE IF NOT EXISTS'),
              reason: 'Iteration $i: Should use IF NOT EXISTS',
            );
            expect(
              sql1,
              contains('ENGINE=InnoDB'),
              reason: 'Iteration $i: Should specify InnoDB engine',
            );
            expect(
              sql1,
              contains('DEFAULT CHARSET=utf8mb4'),
              reason: 'Iteration $i: Should specify utf8mb4 charset',
            );

            // Verify all columns are present
            for (final column in table.columns) {
              expect(
                sql1,
                contains('`${column.name}`'),
                reason: 'Iteration $i: Should include column ${column.name}',
              );
              expect(
                sql1,
                contains(column.sqlType),
                reason: 'Iteration $i: Should include type ${column.sqlType}',
              );
            }

            // Verify primary key constraint
            final pkColumns =
                table.columns.where((c) => c.isPrimaryKey).toList();
            for (final _ in pkColumns) {
              expect(
                sql1,
                contains('PRIMARY KEY'),
                reason: 'Iteration $i: Should include PRIMARY KEY constraint',
              );
            }

            // Verify foreign key constraints
            for (final fk in table.foreignKeys) {
              expect(
                sql1,
                contains('FOREIGN KEY'),
                reason: 'Iteration $i: Should include FOREIGN KEY constraint',
              );
              expect(
                sql1,
                contains('REFERENCES `${fk.referencedTable}`'),
                reason: 'Iteration $i: Should reference ${fk.referencedTable}',
              );
            }
          }
        },
      );

      test(
        'should generate consistent INSERT statements for any table and columns',
        () {
          final random = Random(101);

          for (var i = 0; i < 100; i++) {
            // Generate random table name and columns
            final tableName = _generateRandomTableName(random);
            final columns = _generateRandomColumns(random);

            // Generate SQL twice
            final sql1 = dialect.insertOrReplace(tableName, columns);
            final sql2 = dialect.insertOrReplace(tableName, columns);

            // Verify consistency
            expect(
              sql1,
              equals(sql2),
              reason: 'Iteration $i: SQL generation should be deterministic',
            );

            // Verify required MySQL syntax elements
            expect(
              sql1,
              contains('INSERT INTO `$tableName`'),
              reason: 'Iteration $i: Should insert into correct table',
            );
            expect(
              sql1,
              contains('ON DUPLICATE KEY UPDATE'),
              reason: 'Iteration $i: Should use ON DUPLICATE KEY UPDATE',
            );

            // Verify all columns are present
            for (final column in columns) {
              expect(
                sql1,
                contains('`$column`'),
                reason: 'Iteration $i: Should include column $column',
              );
            }

            // Verify correct number of placeholders
            final expectedPlaceholders =
                List.filled(columns.length, '?').join(', ');
            expect(
              sql1,
              contains('VALUES ($expectedPlaceholders)'),
              reason:
                  'Iteration $i: Should have correct number of placeholders',
            );

            // Verify update clauses for all columns
            for (final column in columns) {
              expect(
                sql1,
                contains('`$column` = VALUES(`$column`)'),
                reason: 'Iteration $i: Should update $column on duplicate',
              );
            }
          }
        },
      );

      test(
        'should generate consistent DELETE statements for any table',
        () {
          final random = Random(102);

          for (var i = 0; i < 100; i++) {
            // Generate random table name
            final tableName = _generateRandomTableName(random);

            // Generate SQL twice
            final sql1 = dialect.delete(tableName);
            final sql2 = dialect.delete(tableName);

            // Verify consistency
            expect(
              sql1,
              equals(sql2),
              reason: 'Iteration $i: SQL generation should be deterministic',
            );

            // Verify required syntax elements
            expect(
              sql1,
              equals('DELETE FROM `$tableName` WHERE `id` = ?'),
              reason: 'Iteration $i: Should generate correct DELETE statement',
            );
          }
        },
      );

      test(
        'should generate consistent SELECT with JOIN statements',
        () {
          final random = Random(103);

          for (var i = 0; i < 100; i++) {
            // Generate random table and joins
            final rootTable = _generateRandomTableDefinition(random);
            final joins = _generateRandomJoins(random);

            // Generate SQL twice
            final sql1 = dialect.selectWithJoins(rootTable, joins);
            final sql2 = dialect.selectWithJoins(rootTable, joins);

            // Verify consistency
            expect(
              sql1,
              equals(sql2),
              reason: 'Iteration $i: SQL generation should be deterministic',
            );

            // Verify SELECT clause
            expect(
              sql1,
              startsWith('SELECT'),
              reason: 'Iteration $i: Should start with SELECT',
            );
            expect(
              sql1,
              contains('FROM `${rootTable.tableName}`'),
              reason: 'Iteration $i: Should select from correct table',
            );

            // Verify all columns are selected
            for (final column in rootTable.columns) {
              if (column.sqlType == 'BINARY(16)') {
                // UUID columns should use BIN_TO_UUID
                expect(
                  sql1,
                  contains('BIN_TO_UUID'),
                  reason: 'Iteration $i: Should convert BINARY UUID columns',
                );
              } else {
                expect(
                  sql1,
                  contains('`${rootTable.tableName}`.`${column.name}`'),
                  reason: 'Iteration $i: Should include column ${column.name}',
                );
              }
            }

            // Verify JOIN clauses
            for (final join in joins) {
              expect(
                sql1,
                contains('JOIN `${join.table}`'),
                reason: 'Iteration $i: Should include JOIN for ${join.table}',
              );
              expect(
                sql1,
                contains('ON ${join.onCondition}'),
                reason: 'Iteration $i: Should include ON condition',
              );
            }
          }
        },
      );

      test(
        'should maintain SQL syntax compatibility across driver changes',
        () {
          // This test verifies that the SQL generated is standard MySQL syntax
          // that works with both mysql1 and mysql_client drivers
          final random = Random(104);

          for (var i = 0; i < 100; i++) {
            final table = _generateRandomTableDefinition(random);
            final sql = dialect.createTableIfNotExists(table);

            // Verify no driver-specific syntax that might break compatibility
            expect(
              sql,
              isNot(contains('mysql1')),
              reason: 'Iteration $i: Should not contain driver-specific syntax',
            );
            expect(
              sql,
              isNot(contains('mysql_client')),
              reason: 'Iteration $i: Should not contain driver-specific syntax',
            );

            // Verify standard MySQL syntax elements
            expect(
              sql,
              matches(RegExp(r'CREATE TABLE IF NOT EXISTS `\w+`')),
              reason: 'Iteration $i: Should use standard CREATE TABLE syntax',
            );
            expect(
              sql,
              matches(RegExp('ENGINE=InnoDB')),
              reason: 'Iteration $i: Should use standard ENGINE syntax',
            );
            expect(
              sql,
              matches(RegExp('DEFAULT CHARSET=utf8mb4')),
              reason: 'Iteration $i: Should use standard CHARSET syntax',
            );
          }
        },
      );
    });
  });
}

// Generator functions

/// Generates a random table definition.
TableDefinition _generateRandomTableDefinition(Random random) {
  final tableName = _generateRandomTableName(random);
  final columnCount = random.nextInt(5) + 2; // 2-6 columns

  final columns = <ColumnDefinition>[
    // Always add ID column
    const ColumnDefinition(
      name: 'id',
      sqlType: 'BINARY(16)',
      dartType: 'UuidValue',
      isNullable: false,
      isPrimaryKey: true,
      isForeignKey: false,
    ),
  ];

  // Add random columns
  for (var i = 1; i < columnCount; i++) {
    columns.add(
      ColumnDefinition(
        name: 'field$i',
        sqlType: _getRandomSqlType(random),
        dartType: _getRandomDartType(random),
        isNullable: random.nextBool(),
        isPrimaryKey: false,
        isForeignKey: false,
      ),
    );
  }

  // Optionally add foreign keys
  final foreignKeys = <ForeignKeyDefinition>[];
  if (random.nextBool()) {
    final fkCount = random.nextInt(2) + 1; // 1-2 foreign keys
    for (var i = 0; i < fkCount; i++) {
      foreignKeys.add(
        ForeignKeyDefinition(
          columnName: 'fk_field$i',
          referencedTable: 'ref_table$i',
          referencedColumn: 'id',
          onDelete: _getRandomCascadeAction(random),
        ),
      );
    }
  }

  return TableDefinition(
    tableName: tableName,
    className: _toPascalCase(tableName),
    columns: columns,
    foreignKeys: foreignKeys,
    isAggregateRoot: true,
  );
}

/// Generates a random table name.
String _generateRandomTableName(Random random) {
  final prefixes = ['users', 'products', 'orders', 'accounts', 'items'];
  final suffixes = ['', '_data', '_info', '_records'];

  final prefix = prefixes[random.nextInt(prefixes.length)];
  final suffix = suffixes[random.nextInt(suffixes.length)];

  return '$prefix$suffix';
}

/// Generates a random list of column names.
List<String> _generateRandomColumns(Random random) {
  final count = random.nextInt(5) + 2; // 2-6 columns
  return List.generate(count, (i) => 'column$i');
}

/// Gets a random SQL type.
String _getRandomSqlType(Random random) {
  final types = [
    'VARCHAR(255)',
    'BIGINT',
    'DOUBLE',
    'TINYINT(1)',
    'TEXT',
    'BINARY(16)',
  ];
  return types[random.nextInt(types.length)];
}

/// Gets a random Dart type.
String _getRandomDartType(Random random) {
  final types = ['String', 'int', 'double', 'bool', 'DateTime', 'UuidValue'];
  return types[random.nextInt(types.length)];
}

/// Gets a random cascade action.
CascadeAction _getRandomCascadeAction(Random random) {
  final actions = [
    CascadeAction.cascade,
    CascadeAction.setNull,
    CascadeAction.restrict,
  ];
  return actions[random.nextInt(actions.length)];
}

/// Generates random JOIN clauses.
List<JoinClause> _generateRandomJoins(Random random) {
  final count = random.nextInt(3); // 0-2 joins
  return List.generate(count, (i) {
    return JoinClause(
      type: _getRandomJoinType(random),
      table: 'join_table$i',
      onCondition: '`join_table$i`.`id` = `root`.`fk$i`',
    );
  });
}

/// Gets a random JOIN type.
JoinType _getRandomJoinType(Random random) {
  final types = [
    JoinType.inner,
    JoinType.left,
    JoinType.right,
  ];
  return types[random.nextInt(types.length)];
}

/// Converts snake_case to PascalCase.
String _toPascalCase(String snakeCase) {
  return snakeCase
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
}
