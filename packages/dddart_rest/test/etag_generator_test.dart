import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

// Test aggregate root
class TestAggregate extends AggregateRoot {
  TestAggregate({
    required super.id,
    required this.name,
    required super.createdAt,
    required super.updatedAt,
  });

  final String name;
}

// Test serializer
class TestSerializer implements Serializer<TestAggregate> {
  @override
  TestAggregate deserialize(String data, [dynamic config]) {
    throw UnimplementedError();
  }

  @override
  String serialize(TestAggregate aggregate, [dynamic config]) {
    return '{"id":"${aggregate.id}","name":"${aggregate.name}"}';
  }
}

void main() {
  group('ETagGenerator', () {
    late TestAggregate aggregate;
    late DateTime timestamp;

    setUp(() {
      timestamp = DateTime.utc(2024, 1, 15, 10, 30);
      aggregate = TestAggregate(
        id: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
        name: 'Test',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
    });

    group('timestamp strategy', () {
      test('generates ETag from updatedAt timestamp', () {
        final generator = ETagGenerator<TestAggregate>();

        final etag = generator.generate(aggregate);

        expect(etag, equals('"2024-01-15T10:30:00.000Z"'));
      });

      test('generates same ETag for same timestamp', () {
        final generator = ETagGenerator<TestAggregate>();

        final etag1 = generator.generate(aggregate);
        final etag2 = generator.generate(aggregate);

        expect(etag1, equals(etag2));
      });

      test('generates different ETag for different timestamp', () {
        final generator = ETagGenerator<TestAggregate>();

        final etag1 = generator.generate(aggregate);

        final updatedAggregate = TestAggregate(
          id: aggregate.id,
          name: aggregate.name,
          createdAt: aggregate.createdAt,
          updatedAt: timestamp.add(const Duration(seconds: 1)),
        );

        final etag2 = generator.generate(updatedAggregate);

        expect(etag1, isNot(equals(etag2)));
      });

      test('returns quoted ETag per RFC 7232', () {
        final generator = ETagGenerator<TestAggregate>();

        final etag = generator.generate(aggregate);

        expect(etag.startsWith('"'), isTrue);
        expect(etag.endsWith('"'), isTrue);
      });

      test('validates matching ETag', () {
        final generator = ETagGenerator<TestAggregate>();

        final etag = generator.generate(aggregate);
        final isValid = generator.validate(etag, aggregate);

        expect(isValid, isTrue);
      });

      test('rejects non-matching ETag', () {
        final generator = ETagGenerator<TestAggregate>();

        final isValid = generator.validate('"wrong-etag"', aggregate);

        expect(isValid, isFalse);
      });
    });

    group('contentHash strategy', () {
      test('generates ETag from content hash', () {
        final generator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        final etag = generator.generate(aggregate);

        // Should be a quoted SHA-256 hash
        expect(etag.startsWith('"'), isTrue);
        expect(etag.endsWith('"'), isTrue);
        expect(etag.length, greaterThan(10)); // Hash is long
      });

      test('generates same ETag for same content', () {
        final generator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        final etag1 = generator.generate(aggregate);
        final etag2 = generator.generate(aggregate);

        expect(etag1, equals(etag2));
      });

      test('generates different ETag for different content', () {
        final generator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        final etag1 = generator.generate(aggregate);

        final differentAggregate = TestAggregate(
          id: aggregate.id,
          name: 'Different',
          createdAt: aggregate.createdAt,
          updatedAt: aggregate.updatedAt,
        );

        final etag2 = generator.generate(differentAggregate);

        expect(etag1, isNot(equals(etag2)));
      });

      test('validates matching ETag', () {
        final generator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        final etag = generator.generate(aggregate);
        final isValid = generator.validate(etag, aggregate);

        expect(isValid, isTrue);
      });

      test('rejects non-matching ETag', () {
        final generator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        final isValid = generator.validate('"wrong-etag"', aggregate);

        expect(isValid, isFalse);
      });

      test('throws ArgumentError when serializer not provided', () {
        expect(
          () => ETagGenerator<TestAggregate>(
            strategy: ETagStrategy.contentHash,
          ),
          throwsArgumentError,
        );
      });
    });

    group('strategy comparison', () {
      test('timestamp and contentHash produce different ETags', () {
        final timestampGenerator = ETagGenerator<TestAggregate>();
        final contentHashGenerator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        final timestampETag = timestampGenerator.generate(aggregate);
        final contentHashETag = contentHashGenerator.generate(aggregate);

        expect(timestampETag, isNot(equals(contentHashETag)));
      });

      test('timestamp strategy is faster than contentHash', () {
        final timestampGenerator = ETagGenerator<TestAggregate>();
        final contentHashGenerator = ETagGenerator<TestAggregate>(
          strategy: ETagStrategy.contentHash,
          serializer: TestSerializer(),
        );

        // Warm up
        timestampGenerator.generate(aggregate);
        contentHashGenerator.generate(aggregate);

        // Measure timestamp strategy
        final timestampStart = DateTime.now();
        for (var i = 0; i < 1000; i++) {
          timestampGenerator.generate(aggregate);
        }
        final timestampDuration = DateTime.now().difference(timestampStart);

        // Measure contentHash strategy
        final contentHashStart = DateTime.now();
        for (var i = 0; i < 1000; i++) {
          contentHashGenerator.generate(aggregate);
        }
        final contentHashDuration = DateTime.now().difference(contentHashStart);

        // Timestamp should be faster (this is a performance characteristic test)
        // We don't assert specific times, just that timestamp is faster
        expect(
          timestampDuration.inMicroseconds,
          lessThan(contentHashDuration.inMicroseconds),
        );
      });
    });
  });
}
