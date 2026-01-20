import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

void main() {
  group('ConcurrencyException', () {
    late UuidValue aggregateId;

    setUp(() {
      aggregateId =
          UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000');
    });

    test('creates exception with message and aggregate ID', () {
      final exception = ConcurrencyException(
        'Resource was modified',
        aggregateId,
      );

      expect(exception.message, equals('Resource was modified'));
      expect(exception.aggregateId, equals(aggregateId));
      expect(exception.providedETag, isNull);
      expect(exception.currentETag, isNull);
    });

    test('creates exception with ETags', () {
      final exception = ConcurrencyException(
        'Resource was modified',
        aggregateId,
        providedETag: '"etag1"',
        currentETag: '"etag2"',
      );

      expect(exception.message, equals('Resource was modified'));
      expect(exception.aggregateId, equals(aggregateId));
      expect(exception.providedETag, equals('"etag1"'));
      expect(exception.currentETag, equals('"etag2"'));
    });

    test('toString includes message and aggregate ID', () {
      final exception = ConcurrencyException(
        'Resource was modified',
        aggregateId,
      );

      final string = exception.toString();

      expect(string, contains('ConcurrencyException'));
      expect(string, contains('Resource was modified'));
      expect(string, contains(aggregateId.toString()));
    });

    test('toString includes ETags when provided', () {
      final exception = ConcurrencyException(
        'Resource was modified',
        aggregateId,
        providedETag: '"etag1"',
        currentETag: '"etag2"',
      );

      final string = exception.toString();

      expect(string, contains('provided: "etag1"'));
      expect(string, contains('current: "etag2"'));
    });

    test('toString does not include ETags when not provided', () {
      final exception = ConcurrencyException(
        'Resource was modified',
        aggregateId,
      );

      final string = exception.toString();

      expect(string, isNot(contains('provided:')));
      expect(string, isNot(contains('current:')));
    });

    test('is an Exception', () {
      final exception = ConcurrencyException(
        'Resource was modified',
        aggregateId,
      );

      expect(exception, isA<Exception>());
    });
  });
}
