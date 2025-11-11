import 'package:logging/logging.dart';
import 'package:test/test.dart';
import '../lib/src/aggregate_root.dart';
import '../lib/src/in_memory_repository.dart';
import '../lib/src/repository_exception.dart';
import '../lib/src/uuid_value.dart';

// Test aggregate classes for testing repository functionality
class TestAggregate extends AggregateRoot {
  TestAggregate({
    UuidValue? id,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  final String name;
}

class AnotherTestAggregate extends AggregateRoot {
  AnotherTestAggregate({
    UuidValue? id,
    required this.value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  final int value;
}

void main() {
  group('InMemoryRepository', () {
    late InMemoryRepository<TestAggregate> repository;

    setUp(() {
      repository = InMemoryRepository<TestAggregate>();
    });

    group('getById', () {
      test('throws RepositoryException for non-existent ID', () async {
        final nonExistentId = UuidValue.generate();
        
        expect(
          () => repository.getById(nonExistentId),
          throwsA(isA<RepositoryException>()
              .having((e) => e.type, 'type', RepositoryExceptionType.notFound)
              .having((e) => e.message, 'message', contains('not found'))),
        );
      });

      test('returns correct aggregate after save', () async {
        final aggregate = TestAggregate(name: 'Test User');
        await repository.save(aggregate);
        
        final retrieved = await repository.getById(aggregate.id);
        
        expect(retrieved, equals(aggregate));
        expect(retrieved.id, equals(aggregate.id));
        expect(retrieved.name, equals('Test User'));
      });

      test('returns most recent version after multiple saves', () async {
        final id = UuidValue.generate();
        final aggregate1 = TestAggregate(id: id, name: 'Original Name');
        final aggregate2 = TestAggregate(id: id, name: 'Updated Name');
        
        await repository.save(aggregate1);
        await repository.save(aggregate2);
        
        final retrieved = await repository.getById(id);
        
        expect(retrieved.name, equals('Updated Name'));
      });
    });

    group('save', () {
      test('inserts new aggregate', () async {
        final aggregate = TestAggregate(name: 'New User');
        
        await repository.save(aggregate);
        
        final retrieved = await repository.getById(aggregate.id);
        expect(retrieved, equals(aggregate));
      });

      test('updates existing aggregate (upsert behavior)', () async {
        final id = UuidValue.generate();
        final aggregate1 = TestAggregate(id: id, name: 'Original');
        final aggregate2 = TestAggregate(id: id, name: 'Updated');
        
        await repository.save(aggregate1);
        await repository.save(aggregate2);
        
        final retrieved = await repository.getById(id);
        expect(retrieved.name, equals('Updated'));
        expect(repository.getAll().length, equals(1));
      });

      test('saves multiple different aggregates', () async {
        final aggregate1 = TestAggregate(name: 'User 1');
        final aggregate2 = TestAggregate(name: 'User 2');
        final aggregate3 = TestAggregate(name: 'User 3');
        
        await repository.save(aggregate1);
        await repository.save(aggregate2);
        await repository.save(aggregate3);
        
        expect(repository.getAll().length, equals(3));
      });

      test('preserves aggregate identity and properties', () async {
        final aggregate = TestAggregate(name: 'Test User');
        final originalId = aggregate.id;
        final originalCreatedAt = aggregate.createdAt;
        
        await repository.save(aggregate);
        final retrieved = await repository.getById(aggregate.id);
        
        expect(retrieved.id, equals(originalId));
        expect(retrieved.createdAt, equals(originalCreatedAt));
        expect(retrieved.name, equals('Test User'));
      });
    });

    group('deleteById', () {
      test('removes aggregate successfully', () async {
        final aggregate = TestAggregate(name: 'To Delete');
        await repository.save(aggregate);
        
        await repository.deleteById(aggregate.id);
        
        expect(
          () => repository.getById(aggregate.id),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('throws RepositoryException for non-existent ID', () async {
        final nonExistentId = UuidValue.generate();
        
        expect(
          () => repository.deleteById(nonExistentId),
          throwsA(isA<RepositoryException>()
              .having((e) => e.type, 'type', RepositoryExceptionType.notFound)
              .having((e) => e.message, 'message', contains('not found'))),
        );
      });

      test('removes only the specified aggregate', () async {
        final aggregate1 = TestAggregate(name: 'User 1');
        final aggregate2 = TestAggregate(name: 'User 2');
        final aggregate3 = TestAggregate(name: 'User 3');
        
        await repository.save(aggregate1);
        await repository.save(aggregate2);
        await repository.save(aggregate3);
        
        await repository.deleteById(aggregate2.id);
        
        expect(repository.getAll().length, equals(2));
        expect(await repository.getById(aggregate1.id), equals(aggregate1));
        expect(await repository.getById(aggregate3.id), equals(aggregate3));
        expect(
          () => repository.getById(aggregate2.id),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('allows re-saving after deletion', () async {
        final id = UuidValue.generate();
        final aggregate1 = TestAggregate(id: id, name: 'Original');
        
        await repository.save(aggregate1);
        await repository.deleteById(id);
        
        final aggregate2 = TestAggregate(id: id, name: 'New');
        await repository.save(aggregate2);
        
        final retrieved = await repository.getById(id);
        expect(retrieved.name, equals('New'));
      });
    });

    group('clear', () {
      test('removes all aggregates', () async {
        final aggregate1 = TestAggregate(name: 'User 1');
        final aggregate2 = TestAggregate(name: 'User 2');
        final aggregate3 = TestAggregate(name: 'User 3');
        
        await repository.save(aggregate1);
        await repository.save(aggregate2);
        await repository.save(aggregate3);
        
        repository.clear();
        
        expect(repository.getAll(), isEmpty);
      });

      test('allows saving after clear', () async {
        final aggregate1 = TestAggregate(name: 'Before Clear');
        await repository.save(aggregate1);
        
        repository.clear();
        
        final aggregate2 = TestAggregate(name: 'After Clear');
        await repository.save(aggregate2);
        
        expect(repository.getAll().length, equals(1));
        expect(await repository.getById(aggregate2.id), equals(aggregate2));
      });

      test('does nothing when repository is already empty', () {
        repository.clear();
        
        expect(repository.getAll(), isEmpty);
      });
    });

    group('getAll', () {
      test('returns all stored aggregates', () async {
        final aggregate1 = TestAggregate(name: 'User 1');
        final aggregate2 = TestAggregate(name: 'User 2');
        final aggregate3 = TestAggregate(name: 'User 3');
        
        await repository.save(aggregate1);
        await repository.save(aggregate2);
        await repository.save(aggregate3);
        
        final allAggregates = repository.getAll();
        
        expect(allAggregates.length, equals(3));
        expect(allAggregates, contains(aggregate1));
        expect(allAggregates, contains(aggregate2));
        expect(allAggregates, contains(aggregate3));
      });

      test('returns empty list when repository is empty', () {
        final allAggregates = repository.getAll();
        
        expect(allAggregates, isEmpty);
      });

      test('returns unmodifiable list', () {
        final aggregate = TestAggregate(name: 'Test User');
        repository.save(aggregate);
        
        final allAggregates = repository.getAll();
        
        expect(
          () => allAggregates.add(TestAggregate(name: 'Another')),
          throwsUnsupportedError,
        );
      });

      test('reflects current state after modifications', () async {
        final aggregate1 = TestAggregate(name: 'User 1');
        final aggregate2 = TestAggregate(name: 'User 2');
        
        await repository.save(aggregate1);
        expect(repository.getAll().length, equals(1));
        
        await repository.save(aggregate2);
        expect(repository.getAll().length, equals(2));
        
        await repository.deleteById(aggregate1.id);
        expect(repository.getAll().length, equals(1));
        
        repository.clear();
        expect(repository.getAll(), isEmpty);
      });
    });

    group('storage isolation', () {
      test('different repository instances have separate storage', () async {
        final repository1 = InMemoryRepository<TestAggregate>();
        final repository2 = InMemoryRepository<TestAggregate>();
        
        final aggregate = TestAggregate(name: 'Test User');
        await repository1.save(aggregate);
        
        expect(repository1.getAll().length, equals(1));
        expect(repository2.getAll().length, equals(0));
        expect(
          () => repository2.getById(aggregate.id),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('operations on one instance do not affect another', () async {
        final repository1 = InMemoryRepository<TestAggregate>();
        final repository2 = InMemoryRepository<TestAggregate>();
        
        final aggregate1 = TestAggregate(name: 'User 1');
        final aggregate2 = TestAggregate(name: 'User 2');
        
        await repository1.save(aggregate1);
        await repository2.save(aggregate2);
        
        repository1.clear();
        
        expect(repository1.getAll(), isEmpty);
        expect(repository2.getAll().length, equals(1));
      });
    });

    group('type safety', () {
      test('repository works with different aggregate types', () async {
        final testRepository = InMemoryRepository<TestAggregate>();
        final anotherRepository = InMemoryRepository<AnotherTestAggregate>();
        
        final testAggregate = TestAggregate(name: 'Test');
        final anotherAggregate = AnotherTestAggregate(value: 42);
        
        await testRepository.save(testAggregate);
        await anotherRepository.save(anotherAggregate);
        
        final retrievedTest = await testRepository.getById(testAggregate.id);
        final retrievedAnother = await anotherRepository.getById(anotherAggregate.id);
        
        expect(retrievedTest, isA<TestAggregate>());
        expect(retrievedTest.name, equals('Test'));
        expect(retrievedAnother, isA<AnotherTestAggregate>());
        expect(retrievedAnother.value, equals(42));
      });

      test('repository maintains type constraints', () async {
        final repository = InMemoryRepository<TestAggregate>();
        final aggregate = TestAggregate(name: 'Typed Aggregate');
        
        await repository.save(aggregate);
        final retrieved = await repository.getById(aggregate.id);
        
        expect(retrieved, isA<TestAggregate>());
        expect(retrieved, isA<AggregateRoot>());
      });
    });

    group('async operations', () {
      test('getById completes asynchronously', () async {
        final aggregate = TestAggregate(name: 'Async Test');
        await repository.save(aggregate);
        
        final future = repository.getById(aggregate.id);
        expect(future, isA<Future<TestAggregate>>());
        
        final result = await future;
        expect(result, equals(aggregate));
      });

      test('save completes asynchronously', () async {
        final aggregate = TestAggregate(name: 'Async Test');
        
        final future = repository.save(aggregate);
        expect(future, isA<Future<void>>());
        
        await future;
        expect(await repository.getById(aggregate.id), equals(aggregate));
      });

      test('deleteById completes asynchronously', () async {
        final aggregate = TestAggregate(name: 'Async Test');
        await repository.save(aggregate);
        
        final future = repository.deleteById(aggregate.id);
        expect(future, isA<Future<void>>());
        
        await future;
        expect(
          () => repository.getById(aggregate.id),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('logging integration', () {
      late List<LogRecord> logRecords;
      late InMemoryRepository<TestAggregate> loggingRepository;

      setUp(() {
        logRecords = [];
        loggingRepository = InMemoryRepository<TestAggregate>();
        
        // Set up logging to capture log records
        Logger.root.level = Level.ALL;
        Logger.root.onRecord.listen((record) {
          if (record.loggerName == 'dddart.repository') {
            logRecords.add(record);
          }
        });
      });

      tearDown(() {
        Logger.root.clearListeners();
      });

      test('save operation logs at FINE level', () async {
        final aggregate = TestAggregate(name: 'Test User');
        
        await loggingRepository.save(aggregate);
        
        expect(logRecords, isNotEmpty);
        final saveLog = logRecords.firstWhere(
          (r) => r.message.contains('Saving') && r.message.contains(aggregate.id.toString()),
        );
        expect(saveLog.level, equals(Level.FINE));
        expect(saveLog.message, contains('TestAggregate'));
        expect(saveLog.message, contains(aggregate.id.toString()));
      });

      test('getById operation logs at FINE level', () async {
        final aggregate = TestAggregate(name: 'Test User');
        await loggingRepository.save(aggregate);
        logRecords.clear();
        
        await loggingRepository.getById(aggregate.id);
        
        expect(logRecords, isNotEmpty);
        final getLog = logRecords.firstWhere(
          (r) => r.message.contains('Retrieving') && r.message.contains(aggregate.id.toString()),
        );
        expect(getLog.level, equals(Level.FINE));
        expect(getLog.message, contains('TestAggregate'));
        expect(getLog.message, contains(aggregate.id.toString()));
      });

      test('deleteById operation logs at FINE level', () async {
        final aggregate = TestAggregate(name: 'Test User');
        await loggingRepository.save(aggregate);
        logRecords.clear();
        
        await loggingRepository.deleteById(aggregate.id);
        
        expect(logRecords, isNotEmpty);
        final deleteLog = logRecords.firstWhere(
          (r) => r.message.contains('Deleting') && r.message.contains(aggregate.id.toString()),
        );
        expect(deleteLog.level, equals(Level.FINE));
        expect(deleteLog.message, contains('TestAggregate'));
        expect(deleteLog.message, contains(aggregate.id.toString()));
      });

      test('operation failure logs at SEVERE level with exception', () async {
        final nonExistentId = UuidValue.generate();
        
        try {
          await loggingRepository.getById(nonExistentId);
          fail('Expected RepositoryException to be thrown');
        } catch (e) {
          expect(e, isA<RepositoryException>());
        }
        
        final severeLog = logRecords.firstWhere(
          (r) => r.level == Level.SEVERE,
        );
        expect(severeLog.message, contains('Failed to retrieve'));
        expect(severeLog.message, contains('TestAggregate'));
        expect(severeLog.message, contains(nonExistentId.toString()));
        expect(severeLog.error, isA<RepositoryException>());
        expect(severeLog.stackTrace, isNotNull);
      });

      test('deleteById failure logs at SEVERE level with exception', () async {
        final nonExistentId = UuidValue.generate();
        
        try {
          await loggingRepository.deleteById(nonExistentId);
          fail('Expected RepositoryException to be thrown');
        } catch (e) {
          expect(e, isA<RepositoryException>());
        }
        
        final severeLog = logRecords.firstWhere(
          (r) => r.level == Level.SEVERE && r.message.contains('Failed to delete'),
        );
        expect(severeLog.message, contains('TestAggregate'));
        expect(severeLog.message, contains(nonExistentId.toString()));
        expect(severeLog.error, isA<RepositoryException>());
        expect(severeLog.stackTrace, isNotNull);
      });
    });
  });
}
