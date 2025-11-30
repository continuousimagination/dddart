import 'dart:math';

import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart_repository_dynamodb/src/utils/attribute_value_converter.dart';
import 'package:test/test.dart';

void main() {
  group('AttributeValueConverter', () {
    group('jsonToAttributeValue', () {
      test('should convert null to NULL AttributeValue', () {
        final result = AttributeValueConverter.jsonToAttributeValue(null);
        expect(result.nullValue, isTrue);
      });

      test('should convert bool to BOOL AttributeValue', () {
        final resultTrue = AttributeValueConverter.jsonToAttributeValue(true);
        expect(resultTrue.boolValue, isTrue);

        final resultFalse = AttributeValueConverter.jsonToAttributeValue(false);
        expect(resultFalse.boolValue, isFalse);
      });

      test('should convert String to S AttributeValue', () {
        final result = AttributeValueConverter.jsonToAttributeValue('hello');
        expect(result.s, equals('hello'));
      });

      test('should convert int to N AttributeValue', () {
        final result = AttributeValueConverter.jsonToAttributeValue(42);
        expect(result.n, equals('42'));
      });

      test('should convert double to N AttributeValue', () {
        final result = AttributeValueConverter.jsonToAttributeValue(3.14);
        expect(result.n, equals('3.14'));
      });

      test('should convert List to L AttributeValue', () {
        final result = AttributeValueConverter.jsonToAttributeValue([1, 'two', true]);
        expect(result.l, isNotNull);
        expect(result.l!.length, equals(3));
        expect(result.l![0].n, equals('1'));
        expect(result.l![1].s, equals('two'));
        expect(result.l![2].boolValue, isTrue);
      });

      test('should convert Map to M AttributeValue', () {
        final result = AttributeValueConverter.jsonToAttributeValue({
          'name': 'John',
          'age': 30,
        });
        expect(result.m, isNotNull);
        expect(result.m!['name']!.s, equals('John'));
        expect(result.m!['age']!.n, equals('30'));
      });
    });

    group('attributeValueToJson', () {
      test('should convert NULL AttributeValue to null', () {
        final result = AttributeValueConverter.attributeValueToJson(
          AttributeValue(nullValue: true),
        );
        expect(result, isNull);
      });

      test('should convert BOOL AttributeValue to bool', () {
        final resultTrue = AttributeValueConverter.attributeValueToJson(
          AttributeValue(boolValue: true),
        );
        expect(resultTrue, isTrue);

        final resultFalse = AttributeValueConverter.attributeValueToJson(
          AttributeValue(boolValue: false),
        );
        expect(resultFalse, isFalse);
      });

      test('should convert S AttributeValue to String', () {
        final result = AttributeValueConverter.attributeValueToJson(
          AttributeValue(s: 'hello'),
        );
        expect(result, equals('hello'));
      });

      test('should convert N AttributeValue to int when possible', () {
        final result = AttributeValueConverter.attributeValueToJson(
          AttributeValue(n: '42'),
        );
        expect(result, equals(42));
        expect(result, isA<int>());
      });

      test('should convert N AttributeValue to double when needed', () {
        final result = AttributeValueConverter.attributeValueToJson(
          AttributeValue(n: '3.14'),
        );
        expect(result, equals(3.14));
        expect(result, isA<double>());
      });

      test('should convert L AttributeValue to List', () {
        final result = AttributeValueConverter.attributeValueToJson(
          AttributeValue(
            l: [
              AttributeValue(n: '1'),
              AttributeValue(s: 'two'),
              AttributeValue(boolValue: true),
            ],
          ),
        );
        expect(result, equals([1, 'two', true]));
      });

      test('should convert M AttributeValue to Map', () {
        final result = AttributeValueConverter.attributeValueToJson(
          AttributeValue(
            m: {
              'name': AttributeValue(s: 'John'),
              'age': AttributeValue(n: '30'),
            },
          ),
        );
        expect(result, equals({'name': 'John', 'age': 30}));
      });
    });

    group('jsonMapToAttributeMap', () {
      test('should convert JSON map to AttributeValue map', () {
        final result = AttributeValueConverter.jsonMapToAttributeMap({
          'name': 'John',
          'age': 30,
          'active': true,
        });
        expect(result['name']!.s, equals('John'));
        expect(result['age']!.n, equals('30'));
        expect(result['active']!.boolValue, isTrue);
      });
    });

    group('attributeMapToJsonMap', () {
      test('should convert AttributeValue map to JSON map', () {
        final result = AttributeValueConverter.attributeMapToJsonMap({
          'name': AttributeValue(s: 'John'),
          'age': AttributeValue(n: '30'),
          'active': AttributeValue(boolValue: true),
        });
        expect(result, equals({
          'name': 'John',
          'age': 30,
          'active': true,
        }));
      });
    });

    // **Feature: dynamodb-repository, Property 4: AttributeValue conversion round-trip**
    // **Validates: Requirements 3.3, 3.4**
    group('Property 4: AttributeValue conversion round-trip', () {
      final random = Random(42); // Fixed seed for reproducibility

      test('should round-trip null values', () {
        for (var i = 0; i < 100; i++) {
          final original = null;
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip bool values', () {
        for (var i = 0; i < 100; i++) {
          final original = random.nextBool();
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip string values', () {
        for (var i = 0; i < 100; i++) {
          final original = _generateRandomString(random);
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip integer values', () {
        for (var i = 0; i < 100; i++) {
          final original = random.nextInt(1000000) - 500000;
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip double values', () {
        for (var i = 0; i < 100; i++) {
          final original = (random.nextDouble() * 1000000) - 500000;
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, closeTo(original, 0.0000001), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip list values', () {
        for (var i = 0; i < 100; i++) {
          final original = _generateRandomList(random, depth: 0);
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip map values', () {
        for (var i = 0; i < 100; i++) {
          final original = _generateRandomMap(random, depth: 0);
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });

      test('should round-trip nested structures', () {
        for (var i = 0; i < 100; i++) {
          final original = _generateRandomJson(random, depth: 0);
          final attributeValue = AttributeValueConverter.jsonToAttributeValue(original);
          final roundTripped = AttributeValueConverter.attributeValueToJson(attributeValue);
          _expectJsonEquals(roundTripped, original, 'Iteration $i failed');
        }
      });

      test('should round-trip complex JSON objects', () {
        for (var i = 0; i < 100; i++) {
          final original = _generateRandomMap(random, depth: 0);
          final attributeMap = AttributeValueConverter.jsonMapToAttributeMap(original);
          final roundTripped = AttributeValueConverter.attributeMapToJsonMap(attributeMap);
          expect(roundTripped, equals(original), reason: 'Iteration $i failed');
        }
      });
    });
  });
}

// Helper functions for generating random JSON values

String _generateRandomString(Random random) {
  final length = random.nextInt(20) + 1;
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  return String.fromCharCodes(
    Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}

List<dynamic> _generateRandomList(Random random, {required int depth}) {
  if (depth > 2) return []; // Limit nesting depth
  
  final length = random.nextInt(5) + 1;
  return List.generate(length, (_) => _generateRandomJson(random, depth: depth + 1));
}

Map<String, dynamic> _generateRandomMap(Random random, {required int depth}) {
  if (depth > 2) return {}; // Limit nesting depth
  
  final length = random.nextInt(5) + 1;
  final map = <String, dynamic>{};
  for (var i = 0; i < length; i++) {
    final key = 'key_${random.nextInt(1000)}';
    map[key] = _generateRandomJson(random, depth: depth + 1);
  }
  return map;
}

dynamic _generateRandomJson(Random random, {required int depth}) {
  if (depth > 2) {
    // At max depth, only generate primitive values
    final type = random.nextInt(5);
    switch (type) {
      case 0:
        return null;
      case 1:
        return random.nextBool();
      case 2:
        return _generateRandomString(random);
      case 3:
        return random.nextInt(1000000) - 500000;
      case 4:
        return (random.nextDouble() * 1000000) - 500000;
      default:
        return null;
    }
  }

  final type = random.nextInt(7);
  switch (type) {
    case 0:
      return null;
    case 1:
      return random.nextBool();
    case 2:
      return _generateRandomString(random);
    case 3:
      return random.nextInt(1000000) - 500000;
    case 4:
      return (random.nextDouble() * 1000000) - 500000;
    case 5:
      return _generateRandomList(random, depth: depth);
    case 6:
      return _generateRandomMap(random, depth: depth);
    default:
      return null;
  }
}

void _expectJsonEquals(dynamic actual, dynamic expected, String reason) {
  if (expected is double) {
    expect(actual, closeTo(expected, 0.0000001), reason: reason);
  } else {
    expect(actual, equals(expected), reason: reason);
  }
}
