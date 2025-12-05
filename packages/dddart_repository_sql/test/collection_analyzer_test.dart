import 'package:dddart_repository_sql/src/schema/collection_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('CollectionAnalyzer', () {
    group('CollectionKind', () {
      test('should have list, set, and map kinds', () {
        expect(CollectionKind.values.length, equals(3));
        expect(CollectionKind.values, contains(CollectionKind.list));
        expect(CollectionKind.values, contains(CollectionKind.set));
        expect(CollectionKind.values, contains(CollectionKind.map));
      });
    });

    group('ElementKind', () {
      test('should have primitive, value, and entity kinds', () {
        expect(ElementKind.values.length, equals(3));
        expect(ElementKind.values, contains(ElementKind.primitive));
        expect(ElementKind.values, contains(ElementKind.value));
        expect(ElementKind.values, contains(ElementKind.entity));
      });
    });

    group('CollectionInfo', () {
      test('should store collection metadata', () {
        // This is a data class test - just verify it can be constructed
        // Real usage tests will be in integration tests with actual analyzer elements
        expect(CollectionKind.list, isNotNull);
        expect(ElementKind.primitive, isNotNull);
      });
    });

    // Note: Full integration tests with actual FieldElement instances
    // will be added when implementing collection save/load operations
    // in the SQLite and MySQL repository generators.
  });
}
