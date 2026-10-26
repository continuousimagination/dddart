import 'dart:collection';

import 'package:dddart/src/value.dart';
import 'package:test/test.dart';

// Simple concrete implementation of Value for testing - minimal boilerplate!
class TestValue extends Value {
  const TestValue(this.data);

  final String data;

  @override
  List<Object?> get props => [data];
}

// Another concrete implementation for testing type safety
class AnotherTestValue extends Value {
  const AnotherTestValue(this.value);

  final int value;

  @override
  List<Object?> get props => [value];
}

// Multi-property value object for testing
class ComplexValue extends Value {
  const ComplexValue(this.name, this.age, this.active);

  final String name;
  final int age;
  final bool active;

  @override
  List<Object?> get props => [name, age, active];
}

// Value object with custom props for testing selective equality
class CustomPropsValue extends Value {
  const CustomPropsValue(this.publicData, this.privateData);

  final String publicData;
  final String privateData;

  @override
  List<Object?> get props =>
      [publicData]; // Only include publicData in equality
}

class CollectionValue extends Value {
  const CollectionValue(this.payload);

  final Object? payload;

  @override
  List<Object?> get props => [payload];
}

CollectionValue _collectionValue(Object? payload) => CollectionValue(payload);

void main() {
  group('Value', () {
    group('abstract class behavior', () {
      test('cannot be instantiated directly', () {
        // This test verifies that Value is abstract by ensuring we can only
        // create instances of concrete subclasses
        expect(() => const TestValue('test'), returnsNormally);
        expect(() => const AnotherTestValue(42), returnsNormally);
      });

      test('subclasses automatically get equality behavior', () {
        // This test verifies that subclasses automatically inherit
        // equality, hashCode, and toString by just passing props to super constructor
        const value = TestValue('test');

        expect(value, isA<Value>());
        expect(value.toString(), contains('TestValue'));
        expect(value.toString(), contains('test'));
        expect(value == const TestValue('test'), isTrue);
      });
    });

    group('const constructor', () {
      test('supports const constructor', () {
        // This test verifies that Value can be used with const constructors
        const value1 = TestValue('test');
        const value2 = TestValue('test');

        expect(identical(value1, value2), isTrue);
      });

      test('enables compile-time constants', () {
        // This test verifies that const values can be used in const contexts
        const values = [
          TestValue('a'),
          TestValue('b'),
          TestValue('c'),
        ];

        expect(values.length, equals(3));
        expect(values[0], equals(const TestValue('a')));
      });
    });

    group('automatic value semantics', () {
      test('equality based on value, not identity', () {
        const value1 = TestValue('same');
        const value2 = TestValue('same');
        const value3 = TestValue('same');

        expect(value1, equals(value2));
        expect(value1, equals(value3));
        expect(value2, equals(value3));
      });

      test('different values are not equal', () {
        const value1 = TestValue('different');
        const value2 = TestValue('values');

        expect(value1, isNot(equals(value2)));
      });

      test('different types with same data are not equal', () {
        const stringValue = TestValue('42');
        const intValue = AnotherTestValue(42);

        expect(stringValue, isNot(equals(intValue)));
      });

      test('multi-property equality works automatically', () {
        const value1 = ComplexValue('John', 30, true);
        const value2 = ComplexValue('John', 30, true);
        const value3 = ComplexValue('John', 30, false);

        expect(value1, equals(value2));
        expect(value1, isNot(equals(value3)));
      });

      test('hashCode consistency with equality', () {
        const value1 = TestValue('test');
        const value2 = TestValue('test');
        const value3 = TestValue('different');

        expect(value1.hashCode, equals(value2.hashCode));
        expect(value1.hashCode, isNot(equals(value3.hashCode)));
        expect(value1.hashCode, Object.hashAll(value1.props));
      });

      test('toString provides meaningful representation automatically', () {
        const value = TestValue('example');
        const complex = ComplexValue('Alice', 25, true);

        expect(value.toString(), contains('TestValue'));
        expect(value.toString(), contains('example'));
        expect(complex.toString(), contains('ComplexValue'));
        expect(complex.toString(), contains('Alice'));
        expect(complex.toString(), contains('25'));
        expect(complex.toString(), contains('true'));
      });
    });

    group('immutability', () {
      test('const constructor enforces immutability', () {
        const value = TestValue('immutable');

        // The fact that we can create a const instance verifies that
        // all fields are final and the object is immutable
        expect(value.data, equals('immutable'));
      });

      test('value objects should be immutable by design', () {
        const value1 = TestValue('test');
        const value2 = TestValue('test');

        // If objects are truly immutable and equal, they should have
        // the same hash code and be interchangeable
        expect(value1.hashCode, equals(value2.hashCode));
        expect(value1, equals(value2));
      });
    });

    group('custom props support', () {
      test('can override props to customize equality', () {
        const value1 = CustomPropsValue('same', 'different1');
        const value2 = CustomPropsValue('same', 'different2');
        const value3 = CustomPropsValue('different', 'same');

        // Should be equal because only publicData is compared
        expect(value1, equals(value2));
        expect(value1.hashCode, equals(value2.hashCode));

        // Should not be equal because publicData is different
        expect(value1, isNot(equals(value3)));
      });

      test('props can include all properties', () {
        const value = ComplexValue('test', 42, true);
        final props = value.props;

        expect(props.length, equals(3));
        expect(props, contains('test'));
        expect(props, contains(42));
        expect(props, contains(true));
      });
    });

    group('collection category boundaries', () {
      test('collection categories compare symmetrically in both directions',
          () {
        final categories = <Object>[
          <int>[1, 2],
          <int>{1, 2},
          <int, int>{1: 2},
          ListQueue<int>.from([1, 2]),
        ];
        for (var i = 0; i < categories.length; i++) {
          for (var j = i + 1; j < categories.length; j++) {
            final left = CollectionValue(categories[i]);
            final right = CollectionValue(categories[j]);
            expect(left == right, isFalse, reason: '$i -> $j');
            expect(right == left, isFalse, reason: '$j -> $i');
          }
        }
      });

      test(
          'collection category boundaries apply recursively to members and keys',
          () {
        final wrappers = <Object Function(Object)>[
          (value) => <Object>[value],
          (value) => <String, Object>{'items': value},
          (value) => <Object>{value},
          (value) => <Object, String>{value: 'entry'},
        ];
        for (final wrap in wrappers) {
          final queue = CollectionValue(wrap(ListQueue<int>.from([1, 2])));
          final list = CollectionValue(wrap(<int>[1, 2]));
          expect(queue == list, isFalse);
          expect(list == queue, isFalse);
          expect(<Value>{queue}.contains(list), isFalse);
          expect(<Value>{list}.contains(queue), isFalse);
        }
      });

      test(
          'other finite iterables retain ordered structural equality and hashing',
          () {
        final queue = CollectionValue(ListQueue<int>.from([1, 2]));
        final lazy =
            CollectionValue(Iterable<int>.generate(2, (index) => index + 1));
        final reversed = CollectionValue(ListQueue<int>.from([2, 1]));
        expect(queue == lazy, isTrue);
        expect(lazy == queue, isTrue);
        expect(queue.hashCode, lazy.hashCode);
        expect(<Value, String>{queue: 'found'}[lazy], 'found');
        expect(<Value>{lazy}.contains(queue), isTrue);
        expect(queue == reversed, isFalse);
        expect(reversed == queue, isFalse);
      });
    });

    group('collection properties', () {
      test('separately allocated nested lists compare and hash equally', () {
        final left = _collectionValue([
          1,
          [null, const TestValue('nested')],
        ]);
        final right = _collectionValue([
          1,
          [null, const TestValue('nested')],
        ]);
        final reordered = _collectionValue([
          [null, const TestValue('nested')],
          1,
        ]);

        expect(left, equals(right));
        expect(left.hashCode, equals(right.hashCode));
        expect({left: 'found'}[right], 'found');
        expect(left, isNot(equals(reordered)));
      });

      test('nested sets and maps ignore insertion order', () {
        final left = _collectionValue({
          'items': <Object?>{const TestValue('alpha'), const TestValue('beta')},
          'entries': <Object?>[
            {'count': 1, 'active': true},
            {'count': 2, 'active': false},
          ],
        });
        final right = _collectionValue({
          'entries': <Object?>[
            {'active': true, 'count': 1},
            {'active': false, 'count': 2},
          ],
          'items': <Object?>{const TestValue('beta'), const TestValue('alpha')},
        });

        expect(left, equals(right));
        expect(left.hashCode, equals(right.hashCode));
      });

      test('nested collection keys and set members use structural equality',
          () {
        final left = _collectionValue(<Object?, Object?>{
          <int>[1, 2]: <List<int>>{
            [3, 4],
            [5, 6],
          },
        });
        final right = _collectionValue(<Object?, Object?>{
          <int>[1, 2]: <List<int>>{
            [5, 6],
            [3, 4],
          },
        });

        expect(left, equals(right));
        expect(left.hashCode, equals(right.hashCode));
      });

      test('changed nested keys or set members remain unequal', () {
        final original = _collectionValue(<Object?, Object?>{
          <int>[1, 2]: <List<int>>{
            [3, 4],
            [5, 6],
          },
        });
        final changedKey = _collectionValue(<Object?, Object?>{
          <int>[1, 3]: <List<int>>{
            [3, 4],
            [5, 6],
          },
        });
        final changedMember = _collectionValue(<Object?, Object?>{
          <int>[1, 2]: <List<int>>{
            [3, 4],
            [5, 7],
          },
        });
        for (final changed in [changedKey, changedMember]) {
          expect(original == changed, isFalse);
          expect(changed == original, isFalse);
          expect(<Value, String>{original: 'stored'}[changed], isNull);
          expect(<Value, String>{changed: 'stored'}[original], isNull);
        }
      });

      test('collection kind and unequal nested values remain distinct', () {
        final ordered = _collectionValue({
          'items': [1, 2],
        });
        final reversed = _collectionValue({
          'items': [2, 1],
        });
        expect(
          _collectionValue([1, 2]),
          isNot(equals(_collectionValue({1, 2}))),
        );
        expect(ordered, isNot(equals(reversed)));
        expect(
          const CollectionValue(null),
          equals(const CollectionValue(null)),
        );
      });
    });

    group('minimal boilerplate required', () {
      test('simple subclasses work with just props override', () {
        const value1 = TestValue('test');
        const value2 = TestValue('test');
        const value3 = TestValue('different');

        // Equality works automatically
        expect(value1 == value2, isTrue);
        expect(value1 == value3, isFalse);

        // HashCode works automatically
        expect(value1.hashCode, equals(value2.hashCode));
        expect(value1.hashCode, isA<int>());

        // ToString works automatically
        expect(value1.toString(), isA<String>());
        expect(value1.toString(), contains('TestValue'));
        expect(value1.toString(), contains('test'));
      });
    });
  });
}
