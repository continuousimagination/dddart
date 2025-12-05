/// Manual test to verify validation errors.
///
/// Run this with: dart run build_runner build --delete-conflicting-outputs
///
/// This file intentionally contains invalid models that should fail
/// code generation with clear error messages.
library;

// UNCOMMENT ONE AT A TIME TO TEST VALIDATION ERRORS

// Test 1: Nested collections - should fail with clear error
// @Serializable()
// @GenerateSqliteRepository(tableName: 'test_nested')
// class TestNested extends AggregateRoot {
//   TestNested({
//     required this.matrix,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   final List<List<int>> matrix;
// }

// Test 2: Dynamic collections - should fail with clear error
// @Serializable()
// @GenerateSqliteRepository(tableName: 'test_dynamic')
// class TestDynamic extends AggregateRoot {
//   TestDynamic({
//     required this.stuff,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   final List<dynamic> stuff;
// }

// Test 3: Object collections - should fail with clear error
// @Serializable()
// @GenerateSqliteRepository(tableName: 'test_object')
// class TestObject extends AggregateRoot {
//   TestObject({
//     required this.things,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   final List<Object> things;
// }

// Test 4: Value object as map key - should fail with clear error
// @Serializable()
// class TestValue extends Value {
//   const TestValue({required this.name});
//   final String name;
//   @override
//   List<Object?> get props => [name];
// }
//
// @Serializable()
// @GenerateSqliteRepository(tableName: 'test_value_key')
// class TestValueKey extends AggregateRoot {
//   TestValueKey({
//     required this.items,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   final Map<TestValue, int> items;
// }

// Test 5: Aggregate root in collection - should fail with clear error
// @Serializable()
// class OtherRoot extends AggregateRoot {
//   OtherRoot({
//     required this.name,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//   final String name;
// }
//
// @Serializable()
// @GenerateSqliteRepository(tableName: 'test_aggregate')
// class TestAggregateCollection extends AggregateRoot {
//   TestAggregateCollection({
//     required this.others,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   final List<OtherRoot> others;
// }

void main() {
  print('This file is for manual validation testing.');
  print('Uncomment one test case at a time and run:');
  print('  dart run build_runner build --delete-conflicting-outputs');
  print('');
  print('Each test should fail with a clear, helpful error message.');
}
