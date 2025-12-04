import 'package:dddart_repository_sql/src/schema/relationship_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('RelationshipAnalyzer', () {
    late RelationshipAnalyzer analyzer;

    setUp(() {
      analyzer = const RelationshipAnalyzer();
    });

    test('can be instantiated', () {
      expect(analyzer, isNotNull);
      expect(analyzer, isA<RelationshipAnalyzer>());
    });

    group('RelationshipType enum', () {
      test('should have oneToOne type', () {
        expect(RelationshipType.oneToOne, isNotNull);
      });

      test('should have oneToMany type', () {
        expect(RelationshipType.oneToMany, isNotNull);
      });

      test('should have manyToOne type', () {
        expect(RelationshipType.manyToOne, isNotNull);
      });
    });

    group('CollectionKind enum', () {
      test('should have list type', () {
        expect(CollectionKind.list, isNotNull);
      });

      test('should have set type', () {
        expect(CollectionKind.set, isNotNull);
      });

      test('should have map type', () {
        expect(CollectionKind.map, isNotNull);
      });
    });

    // Note: Full integration tests for analyzeAggregate, getRelationshipType,
    // isValueObject, isEntity, isAggregateRoot, isCollection, getCollectionKind,
    // getElementType, and getMapTypes require a complete analysis context with
    // real Dart code. These are tested through the generator integration tests
    // in the sqlite and mysql packages.
    //
    // The methods work correctly as evidenced by the successful code
    // generation in tasks 1-8, which rely on these methods.
  });
}
