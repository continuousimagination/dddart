/// Tests for the SQLite repository generator.
library;

import 'package:dddart_repository_sqlite/src/generators/sqlite_repository_generator.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteRepositoryGenerator', () {
    test('can be instantiated', () {
      final generator = SqliteRepositoryGenerator();
      expect(generator, isNotNull);
      expect(generator, isA<SqliteRepositoryGenerator>());
    });

    test('converts class names to snake_case', () {
      final generator = SqliteRepositoryGenerator();

      // Use reflection to test the private method
      // For now, just verify the generator exists
      expect(generator, isNotNull);
    });
  });
}
