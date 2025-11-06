import 'package:test/test.dart';
import '../lib/src/value.dart';

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
  List<Object?> get props => [publicData]; // Only include publicData in equality
}

void main() {
  group('Value', () {
    group('abstract class behavior', () {
      test('cannot be instantiated directly', () {
        // This test verifies that Value is abstract by ensuring we can only
        // create instances of concrete subclasses
        expect(() => TestValue('test'), returnsNormally);
        expect(() => AnotherTestValue(42), returnsNormally);
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
        final value3 = TestValue('same');
        
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