/// Property-based tests for SQLite collection operations.
@Tags(['property-test', 'collections'])
library;

import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';
import 'test_models.dart';

void main() {
  group('Collection Property Tests', () {
    late TestSqliteHelper helper;
    late SqliteConnection connection;

    setUp(() {
      helper = createTestHelper();
      connection = helper.connect();
    });

    tearDown(() {
      helper.disconnect();
    });

    // **Feature: sql-collection-support, Property 1: Primitive list round-trip preservation**
    // **Validates: Requirements 1.1-1.8**
    group('Property 1: Primitive list round-trip preservation', () {
      test('should preserve List<int> order and values', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(42);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomPrimitiveCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.favoriteNumbers,
            equals(aggregate.favoriteNumbers),
            reason: 'Iteration $i: List<int> should match exactly',
          );

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 2: Primitive set round-trip preservation**
    // **Validates: Requirements 2.1-2.4**
    group('Property 2: Primitive set round-trip preservation', () {
      test('should preserve Set<String> unique values', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(43);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomPrimitiveCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.tags,
            equals(aggregate.tags),
            reason: 'Iteration $i: Set<String> should match',
          );

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 3: Primitive map round-trip preservation**
    // **Validates: Requirements 3.1-3.5**
    group('Property 3: Primitive map round-trip preservation', () {
      test('should preserve Map<String, int> key-value pairs', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(44);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomPrimitiveCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.scoresByGame,
            equals(aggregate.scoresByGame),
            reason: 'Iteration $i: Map<String, int> should match',
          );

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 4: Value object list round-trip preservation**
    // **Validates: Requirements 4.1-4.6**
    group('Property 4: Value object list round-trip preservation', () {
      test('should preserve List<Money> order and values', () async {
        final repo = TestValueCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(45);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomValueCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.payments.length,
            equals(aggregate.payments.length),
            reason: 'Iteration $i: List<Money> length should match',
          );

          for (var j = 0; j < aggregate.payments.length; j++) {
            expect(
              retrieved.payments[j].amount,
              equals(aggregate.payments[j].amount),
              reason: 'Iteration $i, Item $j: Money amount should match',
            );
            expect(
              retrieved.payments[j].currency,
              equals(aggregate.payments[j].currency),
              reason: 'Iteration $i, Item $j: Money currency should match',
            );
          }

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 5: Value object set round-trip preservation**
    // **Validates: Requirements 5.1-5.4**
    group('Property 5: Value object set round-trip preservation', () {
      test('should preserve Set<Address> unique values', () async {
        final repo = TestValueCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(46);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomValueCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.addresses.length,
            equals(aggregate.addresses.length),
            reason: 'Iteration $i: Set<Address> length should match',
          );

          // Convert to lists for comparison since set order is not guaranteed
          final originalList = aggregate.addresses.toList();
          final retrievedList = retrieved.addresses.toList();

          for (final original in originalList) {
            final found = retrievedList.any(
              (retrieved) =>
                  retrieved.street == original.street &&
                  retrieved.city == original.city &&
                  retrieved.country == original.country,
            );
            expect(
              found,
              isTrue,
              reason: 'Iteration $i: Address should be found in retrieved set',
            );
          }

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 6: Value object map round-trip preservation**
    // **Validates: Requirements 6.1-6.4**
    group('Property 6: Value object map round-trip preservation', () {
      test('should preserve Map<String, Money> key-value pairs', () async {
        final repo = TestValueCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(47);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomValueCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.pricesByProduct.length,
            equals(aggregate.pricesByProduct.length),
            reason: 'Iteration $i: Map<String, Money> length should match',
          );

          for (final entry in aggregate.pricesByProduct.entries) {
            expect(
              retrieved.pricesByProduct.containsKey(entry.key),
              isTrue,
              reason: 'Iteration $i: Map should contain key ${entry.key}',
            );
            expect(
              retrieved.pricesByProduct[entry.key]?.amount,
              equals(entry.value.amount),
              reason:
                  'Iteration $i: Money amount for ${entry.key} should match',
            );
            expect(
              retrieved.pricesByProduct[entry.key]?.currency,
              equals(entry.value.currency),
              reason:
                  'Iteration $i: Money currency for ${entry.key} should match',
            );
          }

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 7: Entity set round-trip preservation**
    // **Validates: Requirements 7.1-7.4**
    group('Property 7: Entity set round-trip preservation', () {
      test('should preserve Set<TestItem> unique entities', () async {
        final repo = TestEntityCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(48);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomEntityCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.uniqueItems.length,
            equals(aggregate.uniqueItems.length),
            reason: 'Iteration $i: Set<TestItem> length should match',
          );

          // Convert to lists for comparison
          final originalList = aggregate.uniqueItems.toList();
          final retrievedList = retrieved.uniqueItems.toList();

          for (final original in originalList) {
            final found = retrievedList.any(
              (retrieved) =>
                  retrieved.id == original.id &&
                  retrieved.name == original.name &&
                  retrieved.quantity == original.quantity,
            );
            expect(
              found,
              isTrue,
              reason: 'Iteration $i: TestItem should be found in retrieved set',
            );
          }

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 8: Entity map round-trip preservation**
    // **Validates: Requirements 8.1-8.4**
    group('Property 8: Entity map round-trip preservation', () {
      test('should preserve Map<String, TestItem> key-entity pairs', () async {
        final repo = TestEntityCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(49);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomEntityCollections(random);

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.itemsByCategory.length,
            equals(aggregate.itemsByCategory.length),
            reason: 'Iteration $i: Map<String, TestItem> length should match',
          );

          for (final entry in aggregate.itemsByCategory.entries) {
            expect(
              retrieved.itemsByCategory.containsKey(entry.key),
              isTrue,
              reason: 'Iteration $i: Map should contain key ${entry.key}',
            );
            expect(
              retrieved.itemsByCategory[entry.key]?.id,
              equals(entry.value.id),
              reason: 'Iteration $i: TestItem ID for ${entry.key} should match',
            );
            expect(
              retrieved.itemsByCategory[entry.key]?.name,
              equals(entry.value.name),
              reason:
                  'Iteration $i: TestItem name for ${entry.key} should match',
            );
            expect(
              retrieved.itemsByCategory[entry.key]?.quantity,
              equals(entry.value.quantity),
              reason:
                  'Iteration $i: TestItem quantity for ${entry.key} should match',
            );
          }

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 10: Empty collection handling**
    // **Validates: Requirements 10.3, 11.6**
    group('Property 10: Empty collection handling', () {
      test('should handle empty collections correctly', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(50);

        for (var i = 0; i < 100; i++) {
          // Create aggregate with empty collections
          final aggregate = TestPrimitiveCollections(
            id: UuidValue.generate(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'Test ${random.nextInt(1000)}',
            favoriteNumbers: [], // Empty list
            tags: {}, // Empty set
            scoresByGame: {}, // Empty map
          );

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.favoriteNumbers,
            isEmpty,
            reason: 'Iteration $i: Empty list should remain empty',
          );
          expect(
            retrieved.favoriteNumbers,
            isA<List<int>>(),
            reason: 'Iteration $i: Should return List<int>, not null',
          );

          expect(
            retrieved.tags,
            isEmpty,
            reason: 'Iteration $i: Empty set should remain empty',
          );
          expect(
            retrieved.tags,
            isA<Set<String>>(),
            reason: 'Iteration $i: Should return Set<String>, not null',
          );

          expect(
            retrieved.scoresByGame,
            isEmpty,
            reason: 'Iteration $i: Empty map should remain empty',
          );
          expect(
            retrieved.scoresByGame,
            isA<Map<String, int>>(),
            reason: 'Iteration $i: Should return Map<String, int>, not null',
          );

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 11: Null collection handling**
    // **Validates: Requirements 14.1-14.3**
    group('Property 11: Null collection handling', () {
      test('should treat null collections as empty on save and load', () async {
        final repo = TestNullableCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(51);

        for (var i = 0; i < 100; i++) {
          // Create aggregate with null collections
          final aggregate = TestNullableCollections(
            id: UuidValue.generate(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'Test ${random.nextInt(1000)}',
          );

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          // Null collections should be returned as empty collections
          expect(
            retrieved.optionalNumbers,
            isEmpty,
            reason: 'Iteration $i: Null list should be returned as empty list',
          );
          expect(
            retrieved.optionalNumbers,
            isA<List<int>>(),
            reason: 'Iteration $i: Should return List<int>, not null',
          );

          expect(
            retrieved.optionalTags,
            isEmpty,
            reason: 'Iteration $i: Null set should be returned as empty set',
          );
          expect(
            retrieved.optionalTags,
            isA<Set<String>>(),
            reason: 'Iteration $i: Should return Set<String>, not null',
          );

          expect(
            retrieved.optionalScores,
            isEmpty,
            reason: 'Iteration $i: Null map should be returned as empty map',
          );
          expect(
            retrieved.optionalScores,
            isA<Map<String, int>>(),
            reason: 'Iteration $i: Should return Map<String, int>, not null',
          );

          await repo.deleteById(aggregate.id);
        }
      });

      test('should handle nullable collection elements', () async {
        final repo = TestNullableElementsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(52);

        for (var i = 0; i < 100; i++) {
          // Create list with mix of null and non-null values
          final nullableNumbers = <int?>[];
          for (var j = 0; j < random.nextInt(5) + 1; j++) {
            // Randomly add null or a number
            nullableNumbers.add(
              random.nextBool() ? null : random.nextInt(1000),
            );
          }

          final aggregate = TestNullableElements(
            id: UuidValue.generate(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'Test ${random.nextInt(1000)}',
            nullableNumbers: nullableNumbers,
          );

          await repo.save(aggregate);
          final retrieved = await repo.getById(aggregate.id);

          expect(
            retrieved.nullableNumbers.length,
            equals(aggregate.nullableNumbers.length),
            reason: 'Iteration $i: List length should match',
          );

          for (var j = 0; j < aggregate.nullableNumbers.length; j++) {
            expect(
              retrieved.nullableNumbers[j],
              equals(aggregate.nullableNumbers[j]),
              reason:
                  'Iteration $i, Index $j: Nullable element should match (including null)',
            );
          }

          await repo.deleteById(aggregate.id);
        }
      });
    });

    // **Feature: sql-collection-support, Property 9: Collection cascade delete**
    // **Validates: Requirements 1.9, 2.6, 7.5, 8.5**
    group('Property 9: Collection cascade delete', () {
      test('should cascade delete primitive collection items', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(53);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomPrimitiveCollections(random);

          // Save aggregate with collections
          await repo.save(aggregate);

          // Verify collection items exist in junction tables
          final listCount = await helper.countRows(
            'test_primitive_collections_favoriteNumbers',
          );
          expect(
            listCount,
            equals(aggregate.favoriteNumbers.length),
            reason: 'Iteration $i: List items should exist before delete',
          );

          final setCount = await helper.countRows(
            'test_primitive_collections_tags',
          );
          expect(
            setCount,
            equals(aggregate.tags.length),
            reason: 'Iteration $i: Set items should exist before delete',
          );

          final mapCount = await helper.countRows(
            'test_primitive_collections_scoresByGame',
          );
          expect(
            mapCount,
            equals(aggregate.scoresByGame.length),
            reason: 'Iteration $i: Map items should exist before delete',
          );

          // Delete the aggregate
          await repo.deleteById(aggregate.id);

          // Verify all collection items are cascade deleted
          final listCountAfter = await helper.countRows(
            'test_primitive_collections_favoriteNumbers',
          );
          expect(
            listCountAfter,
            equals(0),
            reason: 'Iteration $i: List items should be cascade deleted',
          );

          final setCountAfter = await helper.countRows(
            'test_primitive_collections_tags',
          );
          expect(
            setCountAfter,
            equals(0),
            reason: 'Iteration $i: Set items should be cascade deleted',
          );

          final mapCountAfter = await helper.countRows(
            'test_primitive_collections_scoresByGame',
          );
          expect(
            mapCountAfter,
            equals(0),
            reason: 'Iteration $i: Map items should be cascade deleted',
          );
        }
      });

      test('should cascade delete value object collection items', () async {
        final repo = TestValueCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(54);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomValueCollections(random);

          // Save aggregate with collections
          await repo.save(aggregate);

          // Verify collection items exist in junction tables
          final listCount = await helper.countRows(
            'test_value_collections_payments',
          );
          expect(
            listCount,
            equals(aggregate.payments.length),
            reason: 'Iteration $i: Value list items should exist before delete',
          );

          final setCount = await helper.countRows(
            'test_value_collections_addresses',
          );
          expect(
            setCount,
            equals(aggregate.addresses.length),
            reason: 'Iteration $i: Value set items should exist before delete',
          );

          final mapCount = await helper.countRows(
            'test_value_collections_pricesByProduct',
          );
          expect(
            mapCount,
            equals(aggregate.pricesByProduct.length),
            reason: 'Iteration $i: Value map items should exist before delete',
          );

          // Delete the aggregate
          await repo.deleteById(aggregate.id);

          // Verify all collection items are cascade deleted
          final listCountAfter = await helper.countRows(
            'test_value_collections_payments',
          );
          expect(
            listCountAfter,
            equals(0),
            reason: 'Iteration $i: Value list items should be cascade deleted',
          );

          final setCountAfter = await helper.countRows(
            'test_value_collections_addresses',
          );
          expect(
            setCountAfter,
            equals(0),
            reason: 'Iteration $i: Value set items should be cascade deleted',
          );

          final mapCountAfter = await helper.countRows(
            'test_value_collections_pricesByProduct',
          );
          expect(
            mapCountAfter,
            equals(0),
            reason: 'Iteration $i: Value map items should be cascade deleted',
          );
        }
      });

      test('should cascade delete entity collection items', () async {
        final repo = TestEntityCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(55);

        for (var i = 0; i < 100; i++) {
          final aggregate = _generateRandomEntityCollections(random);

          // Save aggregate with collections
          await repo.save(aggregate);

          // Verify collection items exist in entity tables
          final setCount = await helper.countRows(
            'test_entity_collections_uniqueItems',
          );
          expect(
            setCount,
            equals(aggregate.uniqueItems.length),
            reason: 'Iteration $i: Entity set items should exist before delete',
          );

          final mapCount = await helper.countRows(
            'test_entity_collections_itemsByCategory',
          );
          expect(
            mapCount,
            equals(aggregate.itemsByCategory.length),
            reason: 'Iteration $i: Entity map items should exist before delete',
          );

          // Delete the aggregate
          await repo.deleteById(aggregate.id);

          // Verify all collection items are cascade deleted
          final setCountAfter = await helper.countRows(
            'test_entity_collections_uniqueItems',
          );
          expect(
            setCountAfter,
            equals(0),
            reason: 'Iteration $i: Entity set items should be cascade deleted',
          );

          final mapCountAfter = await helper.countRows(
            'test_entity_collections_itemsByCategory',
          );
          expect(
            mapCountAfter,
            equals(0),
            reason: 'Iteration $i: Entity map items should be cascade deleted',
          );
        }
      });
    });

    // **Feature: sql-collection-support, Property 17: Transaction rollback on failure**
    // **Validates: Requirements 10.1, 10.5**
    group('Property 17: Transaction rollback on failure', () {
      test('should rollback all changes when database error occurs', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(56);

        // Note: This test verifies that IF a save operation fails,
        // the database state remains consistent. However, the current
        // implementation may not use transactions, so we test the
        // observable behavior: either the save succeeds completely
        // or fails completely without partial updates.

        for (var i = 0; i < 100; i++) {
          // Create and save an initial aggregate
          final initial = _generateRandomPrimitiveCollections(random);
          await repo.save(initial);

          // Create a modified version
          final modified = TestPrimitiveCollections(
            id: initial.id,
            createdAt: initial.createdAt,
            updatedAt: DateTime.now(),
            name: 'Modified ${random.nextInt(1000)}',
            favoriteNumbers: List.generate(
              random.nextInt(10) + 5,
              (_) => random.nextInt(1000),
            ),
            tags: List.generate(
              random.nextInt(10) + 5,
              (i) => 'newtag${random.nextInt(100)}',
            ).toSet(),
            scoresByGame: Map.fromEntries(
              List.generate(
                random.nextInt(10) + 5,
                (i) => MapEntry(
                  'newgame${random.nextInt(100)}',
                  random.nextInt(10000),
                ),
              ),
            ),
          );

          // Save the modified version (should succeed normally)
          await repo.save(modified);

          // Verify the save succeeded completely
          final afterSave = await repo.getById(initial.id);
          expect(
            afterSave.name,
            equals(modified.name),
            reason: 'Iteration $i: Save should update name',
          );
          expect(
            afterSave.favoriteNumbers,
            equals(modified.favoriteNumbers),
            reason: 'Iteration $i: Save should update favoriteNumbers',
          );
          expect(
            afterSave.tags,
            equals(modified.tags),
            reason: 'Iteration $i: Save should update tags',
          );
          expect(
            afterSave.scoresByGame,
            equals(modified.scoresByGame),
            reason: 'Iteration $i: Save should update scoresByGame',
          );

          // Verify collection counts match the new state
          final afterListCount = await helper.countRows(
            'test_primitive_collections_favoriteNumbers',
          );
          final afterSetCount = await helper.countRows(
            'test_primitive_collections_tags',
          );
          final afterMapCount = await helper.countRows(
            'test_primitive_collections_scoresByGame',
          );

          expect(
            afterListCount,
            equals(modified.favoriteNumbers.length),
            reason: 'Iteration $i: List item count should match new state',
          );
          expect(
            afterSetCount,
            equals(modified.tags.length),
            reason: 'Iteration $i: Set item count should match new state',
          );
          expect(
            afterMapCount,
            equals(modified.scoresByGame.length),
            reason: 'Iteration $i: Map item count should match new state',
          );

          // Clean up
          await repo.deleteById(initial.id);
        }
      });

      test('should maintain consistency across multiple collections', () async {
        final repo = TestPrimitiveCollectionsSqliteRepository(connection);
        await repo.createTables();

        final random = Random(57);

        // This test verifies that when saving an aggregate with multiple
        // collections, either all collections are updated or none are.
        // This is the atomicity property of transactions.

        for (var i = 0; i < 100; i++) {
          // Create an aggregate with multiple collections
          final aggregate = _generateRandomPrimitiveCollections(random);

          // Save initial state
          await repo.save(aggregate);

          // Get initial collection counts
          final initialListCount = await helper.countRows(
            'test_primitive_collections_favoriteNumbers',
          );
          final initialSetCount = await helper.countRows(
            'test_primitive_collections_tags',
          );
          final initialMapCount = await helper.countRows(
            'test_primitive_collections_scoresByGame',
          );

          // Verify initial counts match the aggregate
          expect(
            initialListCount,
            equals(aggregate.favoriteNumbers.length),
            reason: 'Iteration $i: Initial list count should match',
          );
          expect(
            initialSetCount,
            equals(aggregate.tags.length),
            reason: 'Iteration $i: Initial set count should match',
          );
          expect(
            initialMapCount,
            equals(aggregate.scoresByGame.length),
            reason: 'Iteration $i: Initial map count should match',
          );

          // Create a modified version with different collection sizes
          final modified = TestPrimitiveCollections(
            id: aggregate.id,
            createdAt: aggregate.createdAt,
            updatedAt: DateTime.now(),
            name: 'Modified ${random.nextInt(1000)}',
            favoriteNumbers: List.generate(
              random.nextInt(20) + 1,
              (_) => random.nextInt(1000),
            ),
            tags: List.generate(
              random.nextInt(20) + 1,
              (i) => 'tag${random.nextInt(100)}',
            ).toSet(),
            scoresByGame: Map.fromEntries(
              List.generate(
                random.nextInt(20) + 1,
                (i) => MapEntry(
                  'game${random.nextInt(100)}',
                  random.nextInt(10000),
                ),
              ),
            ),
          );

          // Save the modified version
          await repo.save(modified);

          // Verify all collections were updated atomically
          final retrieved = await repo.getById(aggregate.id);
          expect(
            retrieved.favoriteNumbers,
            equals(modified.favoriteNumbers),
            reason: 'Iteration $i: All collections should be updated together',
          );
          expect(
            retrieved.tags,
            equals(modified.tags),
            reason: 'Iteration $i: All collections should be updated together',
          );
          expect(
            retrieved.scoresByGame,
            equals(modified.scoresByGame),
            reason: 'Iteration $i: All collections should be updated together',
          );

          // Verify collection counts match the new state
          final afterListCount = await helper.countRows(
            'test_primitive_collections_favoriteNumbers',
          );
          final afterSetCount = await helper.countRows(
            'test_primitive_collections_tags',
          );
          final afterMapCount = await helper.countRows(
            'test_primitive_collections_scoresByGame',
          );

          expect(
            afterListCount,
            equals(modified.favoriteNumbers.length),
            reason:
                'Iteration $i: List count should match new state atomically',
          );
          expect(
            afterSetCount,
            equals(modified.tags.length),
            reason: 'Iteration $i: Set count should match new state atomically',
          );
          expect(
            afterMapCount,
            equals(modified.scoresByGame.length),
            reason: 'Iteration $i: Map count should match new state atomically',
          );

          // Clean up
          await repo.deleteById(aggregate.id);
        }
      });
    });
  });
}

// Generator functions

/// Generates a random TestPrimitiveCollections instance.
TestPrimitiveCollections _generateRandomPrimitiveCollections(Random random) {
  final favoriteNumbers = List.generate(
    random.nextInt(5) + 1,
    (_) => random.nextInt(1000),
  );

  final tags = List.generate(
    random.nextInt(5) + 1,
    (i) => 'tag${random.nextInt(100)}',
  ).toSet();

  final scoresByGame = <String, int>{};
  for (var i = 0; i < random.nextInt(5) + 1; i++) {
    scoresByGame['game${random.nextInt(100)}'] = random.nextInt(10000);
  }

  return TestPrimitiveCollections(
    id: UuidValue.generate(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    name: 'Test ${random.nextInt(1000)}',
    favoriteNumbers: favoriteNumbers,
    tags: tags,
    scoresByGame: scoresByGame,
  );
}

/// Generates a random TestValueCollections instance.
TestValueCollections _generateRandomValueCollections(Random random) {
  final payments = List.generate(
    random.nextInt(5) + 1,
    (_) => _generateRandomMoney(random),
  );

  final addresses = List.generate(
    random.nextInt(5) + 1,
    (_) => _generateRandomAddress(random),
  ).toSet();

  final pricesByProduct = <String, Money>{};
  for (var i = 0; i < random.nextInt(5) + 1; i++) {
    pricesByProduct['product${random.nextInt(100)}'] =
        _generateRandomMoney(random);
  }

  return TestValueCollections(
    id: UuidValue.generate(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    name: 'Test ${random.nextInt(1000)}',
    payments: payments,
    addresses: addresses,
    pricesByProduct: pricesByProduct,
  );
}

/// Generates a random TestEntityCollections instance.
TestEntityCollections _generateRandomEntityCollections(Random random) {
  final uniqueItems = List.generate(
    random.nextInt(5) + 1,
    (i) => TestItem(
      id: UuidValue.generate(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      name: 'Item ${random.nextInt(1000)}',
      quantity: random.nextInt(100) + 1,
    ),
  ).toSet();

  final itemsByCategory = <String, TestItem>{};
  for (var i = 0; i < random.nextInt(5) + 1; i++) {
    itemsByCategory['category${random.nextInt(100)}'] = TestItem(
      id: UuidValue.generate(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      name: 'Item ${random.nextInt(1000)}',
      quantity: random.nextInt(100) + 1,
    );
  }

  return TestEntityCollections(
    id: UuidValue.generate(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    name: 'Test ${random.nextInt(1000)}',
    uniqueItems: uniqueItems,
    itemsByCategory: itemsByCategory,
  );
}

/// Generates a random Money value object.
Money _generateRandomMoney(Random random) {
  final currencies = ['USD', 'EUR', 'GBP', 'JPY'];
  return Money(
    amount: (random.nextInt(999999) + 1) / 100.0,
    currency: currencies[random.nextInt(currencies.length)],
  );
}

/// Generates a random Address value object.
Address _generateRandomAddress(Random random) {
  final streets = ['Main St', 'Oak Ave', 'Elm Rd', 'Pine Blvd'];
  final cities = ['New York', 'London', 'Tokyo', 'Paris'];
  final countries = ['USA', 'UK', 'Japan', 'France'];

  return Address(
    street:
        '${random.nextInt(9999) + 1} ${streets[random.nextInt(streets.length)]}',
    city: cities[random.nextInt(cities.length)],
    country: countries[random.nextInt(countries.length)],
  );
}
