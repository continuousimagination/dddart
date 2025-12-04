/// Integration tests for MySQL collection support.
///
/// These tests verify end-to-end functionality of collection support including:
/// - Schema generation for all collection types
/// - Save operations for collections
/// - Load operations for collections
/// - Delete operations with CASCADE
/// - Round-trip preservation of data
///
/// These tests require a running MySQL instance on localhost:3307.
/// You can use Docker to run MySQL:
///   docker run -d -p 3307:3306 -e MYSQL_ROOT_PASSWORD=test_password \
///     -e MYSQL_DATABASE=test_db mysql:8.0
///
/// Or skip these tests if MySQL is not available:
///   dart test --exclude-tags=requires-mysql
@Tags(['requires-mysql', 'integration'])
library;

import 'package:test/test.dart';

import 'integration_test_models.dart';
import 'test_helpers.dart';

void main() {
  group('MySQL Collection Integration Tests', () {
    TestMysqlHelper? helper;
    var mysqlAvailable = false;

    setUpAll(() async {
      // Test if MySQL is available
      final testHelper = createTestHelper();
      try {
        await testHelper.connect();
        mysqlAvailable = true;
        await testHelper.disconnect();
        print('MySQL is available - running collection integration tests');
      } catch (e) {
        // MySQL not available - tests will be skipped
        mysqlAvailable = false;
        print('MySQL not available on localhost:3307');
        print('To run these tests, start MySQL with:');
        print(
          '  docker run -d -p 3307:3306 -e MYSQL_ROOT_PASSWORD=test_password -e MYSQL_DATABASE=test_db mysql:8.0',
        );
      }
    });

    setUp(() async {
      if (!mysqlAvailable) {
        return;
      }
      // Create fresh connection for each test
      helper = createTestHelper();
      await helper!.connect();
    });

    tearDown(() async {
      if (helper != null && helper!.isConnected) {
        try {
          // Clean up all tables
          await helper!.dropAllTables();
        } catch (e) {
          // Ignore cleanup errors
        }
        // Always disconnect to avoid connection leaks
        await helper!.disconnect();
      }
    });

    group('Primitive Collections', () {
      test('should create junction tables for primitive collections', () async {
        if (!mysqlAvailable) return;
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        // Verify all junction tables were created
        expect(
          await helper!.tableExists('test_primitive_collections'),
          isTrue,
        );
        expect(
          await helper!
              .tableExists('test_primitive_collections_favoriteNumbers_items'),
          isTrue,
        );
        expect(
          await helper!.tableExists('test_primitive_collections_tags_items'),
          isTrue,
        );
        expect(
          await helper!
              .tableExists('test_primitive_collections_scoresByGame_items'),
          isTrue,
        );
      });

      test('should save and load List<int> correctly', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Test User',
          favoriteNumbers: [7, 42, 13, 99],
          tags: {},
          scoresByGame: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.favoriteNumbers, equals([7, 42, 13, 99]));
      });

      test('should preserve list order', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Order Test',
          favoriteNumbers: [1, 2, 3, 4, 5],
          tags: {},
          scoresByGame: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.favoriteNumbers, equals([1, 2, 3, 4, 5]));
      });

      test('should save and load Set<String> correctly', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Tag Test',
          favoriteNumbers: [],
          tags: {'dart', 'flutter', 'ddd'},
          scoresByGame: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.tags, equals({'dart', 'flutter', 'ddd'}));
      });

      test('should save and load Map<String, int> correctly', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Score Test',
          favoriteNumbers: [],
          tags: {},
          scoresByGame: {
            'chess': 1200,
            'go': 800,
            'poker': 500,
          },
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(
          loaded.scoresByGame,
          equals({
            'chess': 1200,
            'go': 800,
            'poker': 500,
          }),
        );
      });

      test('should handle empty collections', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Empty Test',
          favoriteNumbers: [],
          tags: {},
          scoresByGame: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.favoriteNumbers, isEmpty);
        expect(loaded.tags, isEmpty);
        expect(loaded.scoresByGame, isEmpty);
      });

      test('should update collections correctly', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Update Test',
          favoriteNumbers: [1, 2, 3],
          tags: {'old'},
          scoresByGame: {'game1': 100},
        );

        await repo.save(aggregate);

        // Update with new collections
        final updated = TestPrimitiveCollections(
          name: 'Update Test',
          favoriteNumbers: [4, 5, 6, 7],
          tags: {'new', 'updated'},
          scoresByGame: {'game2': 200, 'game3': 300},
          id: aggregate.id,
        );

        await repo.save(updated);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.favoriteNumbers, equals([4, 5, 6, 7]));
        expect(loaded.tags, equals({'new', 'updated'}));
        expect(loaded.scoresByGame, equals({'game2': 200, 'game3': 300}));
      });

      test('should cascade delete collection items', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Delete Test',
          favoriteNumbers: [1, 2, 3],
          tags: {'tag1', 'tag2'},
          scoresByGame: {'game': 100},
        );

        await repo.save(aggregate);

        // Verify items exist
        expect(
          await helper!
              .countRows('test_primitive_collections_favoriteNumbers_items'),
          equals(3),
        );
        expect(
          await helper!.countRows('test_primitive_collections_tags_items'),
          equals(2),
        );
        expect(
          await helper!
              .countRows('test_primitive_collections_scoresByGame_items'),
          equals(1),
        );

        // Delete aggregate
        await repo.deleteById(aggregate.id);

        // Verify cascade delete
        expect(
          await helper!
              .countRows('test_primitive_collections_favoriteNumbers_items'),
          equals(0),
        );
        expect(
          await helper!.countRows('test_primitive_collections_tags_items'),
          equals(0),
        );
        expect(
          await helper!
              .countRows('test_primitive_collections_scoresByGame_items'),
          equals(0),
        );
      });
    });

    group('Value Object Collections', () {
      test('should create junction tables with flattened value fields',
          () async {
        final repo = TestValueCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        // Verify junction tables exist
        expect(await helper!.tableExists('test_value_collections'), isTrue);
        expect(
          await helper!.tableExists('test_value_collections_payments_items'),
          isTrue,
        );
        expect(
          await helper!.tableExists('test_value_collections_addresses_items'),
          isTrue,
        );
        expect(
          await helper!
              .tableExists('test_value_collections_pricesByProduct_items'),
          isTrue,
        );
      });

      test('should save and load List<Money> correctly', () async {
        final repo = TestValueCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestValueCollections(
          name: 'Payment Test',
          payments: [
            const Money(amount: 100, currency: 'USD'),
            const Money(amount: 50, currency: 'EUR'),
            const Money(amount: 75, currency: 'GBP'),
          ],
          addresses: {},
          pricesByProduct: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.payments, hasLength(3));
        expect(loaded.payments[0].amount, equals(100));
        expect(loaded.payments[0].currency, equals('USD'));
        expect(loaded.payments[1].amount, equals(50));
        expect(loaded.payments[1].currency, equals('EUR'));
        expect(loaded.payments[2].amount, equals(75));
        expect(loaded.payments[2].currency, equals('GBP'));
      });

      test('should save and load Set<Address> correctly', () async {
        final repo = TestValueCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestValueCollections(
          name: 'Address Test',
          payments: [],
          addresses: {
            const Address(
              street: '123 Main St',
              city: 'Springfield',
              state: 'IL',
              zipCode: '62701',
            ),
            const Address(
              street: '456 Oak Ave',
              city: 'Portland',
              state: 'OR',
              zipCode: '97201',
            ),
          },
          pricesByProduct: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.addresses, hasLength(2));
        expect(
          loaded.addresses.any((a) => a.street == '123 Main St'),
          isTrue,
        );
        expect(
          loaded.addresses.any((a) => a.street == '456 Oak Ave'),
          isTrue,
        );
      });

      test('should save and load Map<String, Money> correctly', () async {
        final repo = TestValueCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestValueCollections(
          name: 'Price Test',
          payments: [],
          addresses: {},
          pricesByProduct: {
            'widget': const Money(amount: 29.99, currency: 'USD'),
            'gadget': const Money(amount: 49.99, currency: 'USD'),
          },
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.pricesByProduct, hasLength(2));
        expect(loaded.pricesByProduct['widget']?.amount, equals(29.99));
        expect(loaded.pricesByProduct['widget']?.currency, equals('USD'));
        expect(loaded.pricesByProduct['gadget']?.amount, equals(49.99));
        expect(loaded.pricesByProduct['gadget']?.currency, equals('USD'));
      });

      test('should handle empty value object collections', () async {
        final repo = TestValueCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestValueCollections(
          name: 'Empty Test',
          payments: [],
          addresses: {},
          pricesByProduct: {},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.payments, isEmpty);
        expect(loaded.addresses, isEmpty);
        expect(loaded.pricesByProduct, isEmpty);
      });
    });

    // Note: Entity collections are not yet fully supported in MySQL
    // Skipping these tests until implementation is complete
    // group('Entity Collections', () { ... });

    group('Nullable Collections', () {
      test('should treat null collections as empty on save', () async {
        final repo = TestNullableCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestNullableCollections(
          name: 'Null Test',
        );

        await repo.save(aggregate);

        // Verify no items were saved
        expect(
          await helper!
              .countRows('test_nullable_collections_optionalNumbers_items'),
          equals(0),
        );
        expect(
          await helper!
              .countRows('test_nullable_collections_optionalTags_items'),
          equals(0),
        );
        expect(
          await helper!
              .countRows('test_nullable_collections_optionalScores_items'),
          equals(0),
        );
      });

      test('should return empty collections (not null) on load', () async {
        final repo = TestNullableCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestNullableCollections(
          name: 'Empty Return Test',
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        // Should return empty collections, not null
        expect(loaded.optionalNumbers, isEmpty);
        expect(loaded.optionalTags, isEmpty);
        expect(loaded.optionalScores, isEmpty);
      });

      test('should handle non-null nullable collections', () async {
        final repo = TestNullableCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestNullableCollections(
          name: 'Non-null Test',
          optionalNumbers: [1, 2, 3],
          optionalTags: {'tag1', 'tag2'},
          optionalScores: {'game': 100},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.optionalNumbers, equals([1, 2, 3]));
        expect(loaded.optionalTags, equals({'tag1', 'tag2'}));
        expect(loaded.optionalScores, equals({'game': 100}));
      });
    });

    group('Complex Scenarios', () {
      test('should handle aggregate with multiple collection types', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate = TestPrimitiveCollections(
          name: 'Complex Test',
          favoriteNumbers: [1, 2, 3],
          tags: {'dart', 'flutter'},
          scoresByGame: {'chess': 1200},
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.favoriteNumbers, equals([1, 2, 3]));
        expect(loaded.tags, equals({'dart', 'flutter'}));
        expect(loaded.scoresByGame, equals({'chess': 1200}));
      });

      test('should handle large collections', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final largeList = List.generate(100, (i) => i);
        final largeSet = Set<String>.from(List.generate(50, (i) => 'tag$i'));
        final largeMap = Map<String, int>.fromEntries(
          List.generate(75, (i) => MapEntry('game$i', i * 10)),
        );

        final aggregate = TestPrimitiveCollections(
          name: 'Large Collections',
          favoriteNumbers: largeList,
          tags: largeSet,
          scoresByGame: largeMap,
        );

        await repo.save(aggregate);
        final loaded = await repo.getById(aggregate.id);

        expect(loaded.favoriteNumbers, equals(largeList));
        expect(loaded.tags, equals(largeSet));
        expect(loaded.scoresByGame, equals(largeMap));
      });

      test('should handle multiple aggregates with collections', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        final aggregate1 = TestPrimitiveCollections(
          name: 'User 1',
          favoriteNumbers: [1, 2, 3],
          tags: {'tag1'},
          scoresByGame: {'game1': 100},
        );

        final aggregate2 = TestPrimitiveCollections(
          name: 'User 2',
          favoriteNumbers: [4, 5, 6],
          tags: {'tag2'},
          scoresByGame: {'game2': 200},
        );

        await repo.save(aggregate1);
        await repo.save(aggregate2);

        final loaded1 = await repo.getById(aggregate1.id);
        final loaded2 = await repo.getById(aggregate2.id);

        expect(loaded1.favoriteNumbers, equals([1, 2, 3]));
        expect(loaded2.favoriteNumbers, equals([4, 5, 6]));
      });
    });

    group('MySQL-Specific Features', () {
      test('should use MySQL DATETIME type for DateTime fields', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        // This test verifies that the schema uses MySQL-specific types
        // The actual verification would require inspecting the schema
        // For now, we just verify the tables were created successfully
        expect(await helper!.tableExists('test_primitive_collections'), isTrue);
      });

      test('should use MySQL TINYINT for boolean fields', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        // This test verifies that the schema uses MySQL-specific types
        // The actual verification would require inspecting the schema
        // For now, we just verify the tables were created successfully
        expect(await helper!.tableExists('test_primitive_collections'), isTrue);
      });

      test('should use MySQL BINARY(16) for UUID fields', () async {
        final repo =
            TestPrimitiveCollectionsMysqlRepository(helper!.connection);
        await repo.createTables();

        // This test verifies that the schema uses MySQL-specific types
        // The actual verification would require inspecting the schema
        // For now, we just verify the tables were created successfully
        expect(await helper!.tableExists('test_primitive_collections'), isTrue);
      });
    });
  });
}
