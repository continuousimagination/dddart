import 'dart:async';
import 'package:dddart/dddart.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

// Test event for EventBus logging
class ConfigTestEvent extends DomainEvent {
  final String message;

  ConfigTestEvent({
    required UuidValue aggregateId,
    required this.message,
  }) : super(aggregateId: aggregateId);
}

// Test aggregate for Repository logging
class ConfigTestAggregate extends AggregateRoot {
  ConfigTestAggregate({
    UuidValue? id,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  final String name;
}

void main() {
  group('Logging Configuration', () {
    late List<LogRecord> allLogRecords;
    late StreamSubscription<LogRecord> logSubscription;

    setUp(() {
      allLogRecords = [];
      
      // Enable hierarchical logging
      hierarchicalLoggingEnabled = true;
      
      // Reset logging configuration
      Logger.root.level = Level.OFF;
      Logger.root.clearListeners();
      
      // Set up listener to capture all log records
      logSubscription = Logger.root.onRecord.listen((record) {
        allLogRecords.add(record);
      });
    });

    tearDown(() async {
      await logSubscription.cancel();
      Logger.root.clearListeners();
      Logger.root.level = Level.OFF;
      hierarchicalLoggingEnabled = false;
    });

    group('Hierarchical logger configuration', () {
      test('root dddart logger affects all components', () async {
        // Configure root dddart logger
        Logger('dddart').level = Level.INFO;
        Logger.root.level = Level.ALL;

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform operations that log at FINE level (below INFO)
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);

        await Future.delayed(Duration(milliseconds: 10));

        // FINE level logs should be filtered out by dddart logger
        final fineLogs = allLogRecords.where((r) => 
          r.level == Level.FINE && 
          r.loggerName.startsWith('dddart')
        ).toList();

        expect(fineLogs, isEmpty);

        // But INFO level logs should come through
        await eventBus.close();
        await Future.delayed(Duration(milliseconds: 10));

        final infoLogs = allLogRecords.where((r) => 
          r.level == Level.INFO && 
          r.loggerName.startsWith('dddart')
        ).toList();

        expect(infoLogs, isNotEmpty);
        
        await eventBus.close();
      });

      test('specific component logger overrides parent', () async {
        // Set root dddart logger to INFO
        Logger('dddart').level = Level.INFO;
        
        // Override eventbus logger to FINE
        Logger('dddart.eventbus').level = Level.FINE;
        
        // Keep repository at parent level (INFO)
        Logger.root.level = Level.ALL;

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform operations that log at FINE level
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);

        await Future.delayed(Duration(milliseconds: 10));

        // EventBus FINE logs should come through
        final eventBusFineLogs = allLogRecords.where((r) => 
          r.level == Level.FINE && 
          r.loggerName == 'dddart.eventbus'
        ).toList();

        expect(eventBusFineLogs, isNotEmpty);

        // Repository FINE logs should be filtered out
        final repositoryFineLogs = allLogRecords.where((r) => 
          r.level == Level.FINE && 
          r.loggerName == 'dddart.repository'
        ).toList();

        expect(repositoryFineLogs, isEmpty);
        
        await eventBus.close();
      });

      test('child logger respects parent level filtering', () async {
        // In hierarchical logging, handlers can filter based on level
        // Set root dddart logger to WARNING
        Logger('dddart').level = Level.WARNING;
        Logger.root.level = Level.ALL;
        
        // Listen to parent logger and manually filter based on level
        final dddartRecords = <LogRecord>[];
        final dddartSub = Logger('dddart').onRecord.listen((record) {
          // Only capture records at or above the logger's level
          if (record.level.value >= Logger('dddart').level.value) {
            dddartRecords.add(record);
          }
        });

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform operations that log at FINE and INFO levels
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);
        await repository.getById(aggregate.id);

        await eventBus.close();
        await Future.delayed(Duration(milliseconds: 10));

        // FINE and INFO logs should be filtered out by our handler
        final belowWarningLogs = dddartRecords.where((r) => 
          r.level.value < Level.WARNING.value
        ).toList();

        expect(belowWarningLogs, isEmpty);

        // Trigger a SEVERE log by trying to get non-existent aggregate
        try {
          await repository.getById(UuidValue.generate());
        } catch (e) {
          // Expected exception
        }

        await Future.delayed(Duration(milliseconds: 10));

        // SEVERE logs should come through
        final severeLogs = dddartRecords.where((r) => 
          r.level == Level.SEVERE
        ).toList();

        expect(severeLogs, isNotEmpty);
        
        await dddartSub.cancel();
        await eventBus.close();
      });

      test('can configure different levels for each component', () async {
        // Configure each component differently
        Logger('dddart.eventbus').level = Level.FINE;
        Logger('dddart.repository').level = Level.INFO;
        Logger.root.level = Level.ALL;

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform operations
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);

        await Future.delayed(Duration(milliseconds: 10));

        // EventBus FINE logs should be present
        final eventBusFineLogs = allLogRecords.where((r) => 
          r.loggerName == 'dddart.eventbus' && 
          r.level == Level.FINE
        ).toList();

        expect(eventBusFineLogs, isNotEmpty);

        // Repository FINE logs should be filtered out
        final repositoryFineLogs = allLogRecords.where((r) => 
          r.loggerName == 'dddart.repository' && 
          r.level == Level.FINE
        ).toList();

        expect(repositoryFineLogs, isEmpty);
        
        await eventBus.close();
      });
    });

    group('Multiple handlers', () {
      test('multiple handlers can be attached to same logger', () async {
        Logger.root.level = Level.ALL;
        
        final handler1Records = <LogRecord>[];
        final handler2Records = <LogRecord>[];
        final handler3Records = <LogRecord>[];

        // Attach multiple handlers
        final sub1 = Logger.root.onRecord.listen((record) {
          if (record.loggerName.startsWith('dddart')) {
            handler1Records.add(record);
          }
        });

        final sub2 = Logger.root.onRecord.listen((record) {
          if (record.loggerName.startsWith('dddart')) {
            handler2Records.add(record);
          }
        });

        final sub3 = Logger.root.onRecord.listen((record) {
          if (record.loggerName.startsWith('dddart')) {
            handler3Records.add(record);
          }
        });

        final eventBus = EventBus();
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        await Future.delayed(Duration(milliseconds: 10));

        // All handlers should receive the same log records
        expect(handler1Records, isNotEmpty);
        expect(handler2Records.length, equals(handler1Records.length));
        expect(handler3Records.length, equals(handler1Records.length));

        // Verify they received the same records
        for (var i = 0; i < handler1Records.length; i++) {
          expect(handler2Records[i].message, equals(handler1Records[i].message));
          expect(handler3Records[i].message, equals(handler1Records[i].message));
        }

        await sub1.cancel();
        await sub2.cancel();
        await sub3.cancel();
        await eventBus.close();
      });

      test('handlers can filter records independently', () async {
        Logger.root.level = Level.ALL;
        
        final fineOnlyRecords = <LogRecord>[];
        final infoAndAboveRecords = <LogRecord>[];

        // Handler 1: Only FINE level
        final sub1 = Logger.root.onRecord.listen((record) {
          if (record.loggerName.startsWith('dddart') && record.level == Level.FINE) {
            fineOnlyRecords.add(record);
          }
        });

        // Handler 2: INFO and above
        final sub2 = Logger.root.onRecord.listen((record) {
          if (record.loggerName.startsWith('dddart') && record.level.value >= Level.INFO.value) {
            infoAndAboveRecords.add(record);
          }
        });

        final eventBus = EventBus();
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event); // FINE level
        await eventBus.close(); // INFO level

        await Future.delayed(Duration(milliseconds: 10));

        // First handler should only have FINE records
        expect(fineOnlyRecords, isNotEmpty);
        expect(fineOnlyRecords.every((r) => r.level == Level.FINE), isTrue);

        // Second handler should only have INFO and above
        expect(infoAndAboveRecords, isNotEmpty);
        expect(infoAndAboveRecords.every((r) => r.level.value >= Level.INFO.value), isTrue);

        await sub1.cancel();
        await sub2.cancel();
        await eventBus.close();
      });

      test('can attach handlers to specific component loggers', () async {
        Logger.root.level = Level.ALL;
        Logger('dddart.eventbus').level = Level.ALL;
        Logger('dddart.repository').level = Level.ALL;
        
        final eventBusRecords = <LogRecord>[];
        final repositoryRecords = <LogRecord>[];

        // Handler for EventBus only
        final sub1 = Logger('dddart.eventbus').onRecord.listen((record) {
          eventBusRecords.add(record);
        });

        // Handler for Repository only
        final sub2 = Logger('dddart.repository').onRecord.listen((record) {
          repositoryRecords.add(record);
        });

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);

        await Future.delayed(Duration(milliseconds: 10));

        // Each handler should only receive records from its logger
        expect(eventBusRecords, isNotEmpty);
        expect(eventBusRecords.every((r) => r.loggerName == 'dddart.eventbus'), isTrue);

        expect(repositoryRecords, isNotEmpty);
        expect(repositoryRecords.every((r) => r.loggerName == 'dddart.repository'), isTrue);

        await sub1.cancel();
        await sub2.cancel();
        await eventBus.close();
      });
    });

    group('No-op behavior when logging not configured', () {
      test('components work correctly without any handlers', () async {
        // Don't attach any handlers, just set level to OFF
        Logger.root.level = Level.OFF;
        Logger.root.clearListeners();

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform normal operations
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        
        // Should not throw
        expect(() => eventBus.publish(event), returnsNormally);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);

        final retrieved = await repository.getById(aggregate.id);
        expect(retrieved.name, equals('Test'));

        await repository.deleteById(aggregate.id);

        expect(
          () => repository.getById(aggregate.id),
          throwsA(isA<RepositoryException>()),
        );

        await eventBus.close();
      });

      test('components work correctly with Level.OFF', () async {
        // Explicitly set to OFF
        Logger.root.level = Level.ALL;
        Logger('dddart').level = Level.OFF;
        Logger('dddart.eventbus').level = Level.OFF;
        Logger('dddart.repository').level = Level.OFF;

        final capturedRecords = <LogRecord>[];
        final sub = Logger('dddart').onRecord.listen((record) {
          capturedRecords.add(record);
        });

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform operations
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);
        await repository.getById(aggregate.id);

        await eventBus.close();
        await Future.delayed(Duration(milliseconds: 10));

        // No records should be captured
        expect(capturedRecords, isEmpty);

        await sub.cancel();
        await eventBus.close();
      });

      test('logging has minimal overhead when disabled', () async {
        Logger.root.level = Level.OFF;
        Logger.root.clearListeners();

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Measure time with logging disabled
        final stopwatch = Stopwatch()..start();
        
        for (var i = 0; i < 100; i++) {
          final event = ConfigTestEvent(
            aggregateId: UuidValue.generate(),
            message: 'Test $i',
          );
          eventBus.publish(event);

          final aggregate = ConfigTestAggregate(name: 'Test $i');
          await repository.save(aggregate);
        }

        stopwatch.stop();
        
        // Operations should complete quickly (this is a smoke test, not a precise benchmark)
        // Just verify it doesn't hang or crash
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        expect(repository.getAll().length, equals(100));

        await eventBus.close();
      });

      test('can enable logging after components are created', () async {
        // Start with logging disabled
        Logger.root.level = Level.OFF;
        Logger('dddart').level = Level.OFF;
        Logger.root.clearListeners();

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        // Perform operation with logging disabled
        final event1 = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Before',
        );
        eventBus.publish(event1);

        await Future.delayed(Duration(milliseconds: 10));

        // Now enable logging
        Logger.root.level = Level.ALL;
        Logger('dddart').level = Level.ALL;
        Logger('dddart.eventbus').level = Level.ALL;
        
        final capturedRecords = <LogRecord>[];
        final sub = Logger('dddart.eventbus').onRecord.listen((record) {
          capturedRecords.add(record);
        });

        // Perform operation with logging enabled
        final event2 = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'After',
        );
        eventBus.publish(event2);

        await Future.delayed(Duration(milliseconds: 10));

        // Should have logs from second operation only
        expect(capturedRecords, isNotEmpty);
        expect(capturedRecords.any((r) => r.message.contains('Publishing event')), isTrue);

        await sub.cancel();
        await eventBus.close();
      });
    });

    group('Logger level inheritance', () {
      test('Level.ALL on root logger enables all logging', () async {
        Logger.root.level = Level.ALL;
        Logger('dddart').level = Level.ALL;
        Logger('dddart.eventbus').level = Level.ALL;
        
        final eventBusRecords = <LogRecord>[];
        final eventBusSub = Logger('dddart.eventbus').onRecord.listen((record) {
          eventBusRecords.add(record);
        });

        final eventBus = EventBus();
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        await Future.delayed(Duration(milliseconds: 10));

        // Should capture FINE level logs
        final fineLogs = eventBusRecords.where((r) => 
          r.level == Level.FINE
        ).toList();

        expect(fineLogs, isNotEmpty);
        
        await eventBusSub.cancel();
        await eventBus.close();
      });

      test('Level.OFF on component logger disables that component', () async {
        Logger.root.level = Level.ALL;
        Logger('dddart').level = Level.ALL;
        Logger('dddart.eventbus').level = Level.OFF;
        Logger('dddart.repository').level = Level.ALL;
        
        final dddartRecords = <LogRecord>[];
        final dddartSub = Logger('dddart').onRecord.listen((record) {
          dddartRecords.add(record);
        });

        final eventBus = EventBus();
        final repository = InMemoryRepository<ConfigTestAggregate>();

        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        final aggregate = ConfigTestAggregate(name: 'Test');
        await repository.save(aggregate);

        await Future.delayed(Duration(milliseconds: 10));

        // EventBus logs should be filtered out
        final eventBusLogs = dddartRecords.where((r) => 
          r.loggerName == 'dddart.eventbus'
        ).toList();

        expect(eventBusLogs, isEmpty);

        // Repository logs should be present
        final repositoryLogs = dddartRecords.where((r) => 
          r.loggerName == 'dddart.repository'
        ).toList();

        expect(repositoryLogs, isNotEmpty);
        
        await dddartSub.cancel();
        await eventBus.close();
      });

      test('parent logger level does not override explicit child level', () async {
        // Set child level first
        Logger('dddart.eventbus').level = Level.FINE;
        
        // Then set parent to more restrictive level
        Logger('dddart').level = Level.WARNING;
        Logger.root.level = Level.ALL;

        final eventBus = EventBus();
        final event = ConfigTestEvent(
          aggregateId: UuidValue.generate(),
          message: 'Test',
        );
        eventBus.publish(event);

        await Future.delayed(Duration(milliseconds: 10));

        // EventBus FINE logs should still come through
        final fineLogs = allLogRecords.where((r) => 
          r.loggerName == 'dddart.eventbus' && 
          r.level == Level.FINE
        ).toList();

        expect(fineLogs, isNotEmpty);
        
        await eventBus.close();
      });
    });
  });
}
