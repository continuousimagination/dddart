/// Property-based tests for MySQL dialect operations.
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/src/dialect/mysql_dialect.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:test/test.dart';

void main() {
  group('MysqlDialect Property Tests', () {
    late MysqlDialect dialect;

    setUp(() {
      dialect = const MysqlDialect();
    });

    // **Feature: mysql-repository, Property 5: UUID encoding round-trip**
    // **Validates: Requirements 3.1, 3.2**
    group('Property 5: UUID encoding round-trip', () {
      test('should preserve UUID value when encoding then decoding', () {
        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          // Generate random UUID
          final originalUuid = _generateRandomUuid(random);

          // Encode the UUID
          final encoded = dialect.encodeUuid(originalUuid);

          // Decode the UUID
          final decoded = dialect.decodeUuid(encoded);

          // Verify equivalence
          expect(
            decoded.uuid,
            equals(originalUuid.uuid),
            reason: 'Iteration $i: UUID should round-trip correctly',
          );
        }
      });

      test('should handle all possible UUID formats', () {
        // Test specific UUID patterns
        final testUuids = [
          UuidValue.fromString('00000000-0000-0000-0000-000000000000'),
          UuidValue.fromString('ffffffff-ffff-ffff-ffff-ffffffffffff'),
          UuidValue.fromString('12345678-1234-5678-1234-567812345678'),
          UuidValue.fromString('abcdef01-2345-6789-abcd-ef0123456789'),
          UuidValue.generate(),
          UuidValue.generate(),
          UuidValue.generate(),
        ];

        for (var i = 0; i < testUuids.length; i++) {
          final originalUuid = testUuids[i];

          // Encode then decode
          final encoded = dialect.encodeUuid(originalUuid);
          final decoded = dialect.decodeUuid(encoded);

          // Verify equivalence
          expect(
            decoded.uuid,
            equals(originalUuid.uuid),
            reason: 'Test case $i: UUID should round-trip correctly',
          );
        }
      });
    });

    // **Feature: mysql-repository, Property 6: DateTime encoding round-trip**
    // **Validates: Requirements 3.3, 3.4**
    group('Property 6: DateTime encoding round-trip', () {
      test('should preserve DateTime value when encoding then decoding', () {
        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          // Generate random DateTime
          final originalDateTime = _generateRandomDateTime(random);

          // Encode the DateTime
          final encoded = dialect.encodeDateTime(originalDateTime);

          // Decode the DateTime
          final decoded = dialect.decodeDateTime(encoded);

          // Verify equivalence (within millisecond precision)
          expect(
            decoded.millisecondsSinceEpoch,
            equals(originalDateTime.millisecondsSinceEpoch),
            reason: 'Iteration $i: DateTime should round-trip correctly',
          );
        }
      });

      test('should handle edge case DateTimes', () {
        // Test specific DateTime patterns
        final testDateTimes = [
          DateTime(1970, 1, 1, 0, 0, 1), // Near epoch start
          DateTime(2038, 1, 19, 3, 14, 7), // Near TIMESTAMP limit
          DateTime(2000),
          DateTime(2024, 12, 31, 23, 59, 59),
          DateTime.now(),
          DateTime.now().toUtc(),
        ];

        for (var i = 0; i < testDateTimes.length; i++) {
          final originalDateTime = testDateTimes[i];

          // Encode then decode
          final encoded = dialect.encodeDateTime(originalDateTime);
          final decoded = dialect.decodeDateTime(encoded);

          // Verify equivalence (within millisecond precision)
          expect(
            decoded.millisecondsSinceEpoch,
            equals(originalDateTime.millisecondsSinceEpoch),
            reason: 'Test case $i: DateTime should round-trip correctly',
          );
        }
      });
    });

    // **Feature: mysql-repository, Property 7: MySQL-specific SQL syntax**
    // **Validates: Requirements 3.5, 4.5, 4.6**
    group('Property 7: MySQL-specific SQL syntax', () {
      test('should include ENGINE=InnoDB in CREATE TABLE statements', () {
        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          // Generate random table definition
          final table = _generateRandomTableDefinition(random);

          // Generate CREATE TABLE statement
          final sql = dialect.createTableIfNotExists(table);

          // Verify MySQL-specific syntax
          expect(
            sql,
            contains('ENGINE=InnoDB'),
            reason: 'Iteration $i: Should include ENGINE=InnoDB',
          );
        }
      });

      test(
        'should include DEFAULT CHARSET=utf8mb4 in CREATE TABLE statements',
        () {
          final random = Random(45);

          for (var i = 0; i < 100; i++) {
            // Generate random table definition
            final table = _generateRandomTableDefinition(random);

            // Generate CREATE TABLE statement
            final sql = dialect.createTableIfNotExists(table);

            // Verify MySQL-specific syntax
            expect(
              sql,
              contains('DEFAULT CHARSET=utf8mb4'),
              reason: 'Iteration $i: Should include DEFAULT CHARSET=utf8mb4',
            );
          }
        },
      );

      test('should use CREATE TABLE IF NOT EXISTS syntax', () {
        final random = Random(46);

        for (var i = 0; i < 100; i++) {
          // Generate random table definition
          final table = _generateRandomTableDefinition(random);

          // Generate CREATE TABLE statement
          final sql = dialect.createTableIfNotExists(table);

          // Verify IF NOT EXISTS syntax
          expect(
            sql,
            contains('CREATE TABLE IF NOT EXISTS'),
            reason: 'Iteration $i: Should use IF NOT EXISTS',
          );
        }
      });
    });

    // **Feature: mysql-repository, Property 8: MySQL INSERT syntax**
    // **Validates: Requirements 3.6**
    group('Property 8: MySQL INSERT syntax', () {
      test('should use ON DUPLICATE KEY UPDATE syntax', () {
        final random = Random(47);

        for (var i = 0; i < 100; i++) {
          // Generate random table name and columns
          final tableName = _generateRandomTableName(random);
          final columns = _generateRandomColumns(random);

          // Generate INSERT statement
          final sql = dialect.insertOrReplace(tableName, columns);

          // Verify MySQL-specific syntax
          expect(
            sql,
            contains('ON DUPLICATE KEY UPDATE'),
            reason: 'Iteration $i: Should use ON DUPLICATE KEY UPDATE',
          );
        }
      });

      test('should include VALUES clause for each column', () {
        final random = Random(48);

        for (var i = 0; i < 100; i++) {
          // Generate random table name and columns
          final tableName = _generateRandomTableName(random);
          final columns = _generateRandomColumns(random);

          // Generate INSERT statement
          final sql = dialect.insertOrReplace(tableName, columns);

          // Verify VALUES clause with correct number of placeholders
          final expectedPlaceholders =
              List.filled(columns.length, '?').join(', ');
          expect(
            sql,
            contains('VALUES ($expectedPlaceholders)'),
            reason: 'Iteration $i: Should have correct number of '
                'value placeholders',
          );
        }
      });

      test('should update all columns on duplicate key', () {
        final random = Random(49);

        for (var i = 0; i < 100; i++) {
          // Generate random table name and columns
          final tableName = _generateRandomTableName(random);
          final columns = _generateRandomColumns(random);

          // Generate INSERT statement
          final sql = dialect.insertOrReplace(tableName, columns);

          // Verify each column has an update clause (with backtick escaping)
          for (final column in columns) {
            expect(
              sql,
              contains('`$column` = VALUES(`$column`)'),
              reason: 'Iteration $i: Should update $column on duplicate key',
            );
          }
        }
      });
    });

    // **Feature: mysql-repository, Property 9: Type mapping correctness**
    // **Validates: Requirements 3.7**
    group('Property 9: Type mapping correctness', () {
      test('should map UuidValue to BINARY(16)', () {
        expect(dialect.uuidColumnType, equals('BINARY(16)'));
      });

      test('should map String to VARCHAR(255)', () {
        expect(dialect.textColumnType, equals('VARCHAR(255)'));
      });

      test('should map int to BIGINT', () {
        expect(dialect.integerColumnType, equals('BIGINT'));
      });

      test('should map double to DOUBLE', () {
        expect(dialect.realColumnType, equals('DOUBLE'));
      });

      test('should map bool to TINYINT(1)', () {
        expect(dialect.booleanColumnType, equals('TINYINT(1)'));
      });
    });
  });
}

// Generator functions

/// Generates a random UUID.
UuidValue _generateRandomUuid(Random random) {
  // Generate random bytes for UUID
  final bytes = List.generate(16, (_) => random.nextInt(256));

  // Convert to hex string with proper UUID format
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final uuidString = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';

  return UuidValue.fromString(uuidString);
}

/// Generates a random DateTime within a reasonable range.
DateTime _generateRandomDateTime(Random random) {
  // Generate DateTime between 2000 and 2030 (safe TIMESTAMP range)
  final minMillis = DateTime(2000).millisecondsSinceEpoch;
  final maxMillis = DateTime(2030).millisecondsSinceEpoch;
  final range = maxMillis - minMillis;

  // Use double to avoid overflow, then convert to int
  final randomOffset = (random.nextDouble() * range).toInt();
  final randomMillis = minMillis + randomOffset;

  return DateTime.fromMillisecondsSinceEpoch(randomMillis);
}

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
        dartType: 'String',
        isNullable: random.nextBool(),
        isPrimaryKey: false,
        isForeignKey: false,
      ),
    );
  }

  return TableDefinition(
    tableName: tableName,
    className: _toPascalCase(tableName),
    columns: columns,
    foreignKeys: [],
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
  final types = ['VARCHAR(255)', 'BIGINT', 'DOUBLE', 'TINYINT(1)', 'TEXT'];
  return types[random.nextInt(types.length)];
}

/// Converts snake_case to PascalCase.
String _toPascalCase(String snakeCase) {
  return snakeCase
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
}
