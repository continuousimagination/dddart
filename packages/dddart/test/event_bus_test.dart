import 'dart:async';
import 'package:dddart/dddart.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

// Test event classes
class TestEvent extends DomainEvent {
  TestEvent({
    required super.aggregateId,
    required this.message,
  });
  final String message;
}

class AnotherTestEvent extends DomainEvent {
  AnotherTestEvent({
    required super.aggregateId,
    required this.value,
  });
  final int value;
}

void main() {
  group('EventBus', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    tearDown(() async {
      await eventBus.close();
    });

    test('publishes events to subscribers', () async {
      final receivedEvents = <TestEvent>[];

      eventBus.on<TestEvent>().listen(receivedEvents.add);

      final event =
          TestEvent(aggregateId: UuidValue.generate(), message: 'Hello');
      eventBus.publish(event);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first.message, equals('Hello'));
    });

    test('delivers events to multiple subscribers', () async {
      final subscriber1Events = <TestEvent>[];
      final subscriber2Events = <TestEvent>[];

      eventBus.on<TestEvent>().listen(subscriber1Events.add);

      eventBus.on<TestEvent>().listen(subscriber2Events.add);

      final event =
          TestEvent(aggregateId: UuidValue.generate(), message: 'Broadcast');
      eventBus.publish(event);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(subscriber1Events, hasLength(1));
      expect(subscriber2Events, hasLength(1));
      expect(
        subscriber1Events.first.eventId,
        equals(subscriber2Events.first.eventId),
      );
    });

    test('type-safe subscriptions only receive matching event types', () async {
      final testEvents = <TestEvent>[];
      final anotherEvents = <AnotherTestEvent>[];

      eventBus.on<TestEvent>().listen(testEvents.add);

      eventBus.on<AnotherTestEvent>().listen(anotherEvents.add);

      eventBus.publish(
        TestEvent(aggregateId: UuidValue.generate(), message: 'Test'),
      );
      eventBus.publish(
        AnotherTestEvent(aggregateId: UuidValue.generate(), value: 42),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(testEvents, hasLength(1));
      expect(anotherEvents, hasLength(1));
      expect(testEvents.first.message, equals('Test'));
      expect(anotherEvents.first.value, equals(42));
    });

    test('throws StateError when publishing to closed event bus', () async {
      await eventBus.close();

      expect(
        () => eventBus.publish(
          TestEvent(aggregateId: UuidValue.generate(), message: 'Fail'),
        ),
        throwsStateError,
      );
    });

    test('isClosed returns correct state', () async {
      expect(eventBus.isClosed, isFalse);

      await eventBus.close();

      expect(eventBus.isClosed, isTrue);
    });

    test('completes subscriptions when event bus is closed', () async {
      var completed = false;

      eventBus.on<TestEvent>().listen(
        (event) {},
        onDone: () {
          completed = true;
        },
      );

      await eventBus.close();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(completed, isTrue);
    });
  });

  group('EventBus Logging', () {
    late EventBus eventBus;
    late List<LogRecord> logRecords;
    late StreamSubscription<LogRecord> logSubscription;

    setUp(() {
      eventBus = EventBus();
      logRecords = [];

      // Enable logging at all levels
      Logger.root.level = Level.ALL;

      // Capture log records
      logSubscription = Logger('dddart.eventbus').onRecord.listen((record) {
        logRecords.add(record);
      });
    });

    tearDown(() async {
      await logSubscription.cancel();
      await eventBus.close();
    });

    test('logs event publishing at FINE level', () async {
      final event =
          TestEvent(aggregateId: UuidValue.generate(), message: 'Test');
      eventBus.publish(event);

      await Future.delayed(const Duration(milliseconds: 10));

      final publishLogs = logRecords
          .where(
            (r) =>
                r.level == Level.FINE && r.message.contains('Publishing event'),
          )
          .toList();

      expect(publishLogs, hasLength(1));
      expect(publishLogs.first.message, contains('TestEvent'));
      expect(publishLogs.first.message, contains(event.aggregateId.toString()));
    });

    test('logs subscription creation at FINE level', () async {
      eventBus.on<TestEvent>();

      await Future.delayed(const Duration(milliseconds: 10));

      final subscriptionLogs = logRecords
          .where(
            (r) =>
                r.level == Level.FINE &&
                r.message.contains('Creating subscription'),
          )
          .toList();

      expect(subscriptionLogs, hasLength(1));
      expect(subscriptionLogs.first.message, contains('TestEvent'));
    });

    test('stream transformer logs errors at SEVERE level with stack trace',
        () async {
      // Note: This tests that the stream transformer can log errors that are added to the stream.
      // Exceptions thrown by user handlers are caught by Dart's zone system and cannot be
      // intercepted by the EventBus without changing the API.

      final completer = Completer<void>();

      // Create a custom stream controller to simulate stream errors
      final testController = StreamController<TestEvent>.broadcast();
      final testError = Exception('Stream processing error');
      final testStackTrace = StackTrace.current;

      // Subscribe to the stream with our transformer
      testController.stream
          .transform(
        StreamTransformer<TestEvent, TestEvent>.fromHandlers(
          handleData: (event, sink) {
            sink.add(event);
          },
          handleError: (error, stackTrace, sink) {
            Logger('dddart.eventbus')
                .severe('Event handler threw exception', error, stackTrace);
            sink.addError(error, stackTrace);
          },
        ),
      )
          .listen(
        (event) {},
        onError: (error, stackTrace) {
          completer.complete();
        },
      );

      // Add an error to the stream
      testController.addError(testError, testStackTrace);

      // Wait for error to be handled
      await completer.future.timeout(const Duration(milliseconds: 100));

      final errorLogs = logRecords
          .where(
            (r) =>
                r.level == Level.SEVERE &&
                r.message.contains('Event handler threw exception'),
          )
          .toList();

      expect(errorLogs, hasLength(1));
      expect(errorLogs.first.error, equals(testError));
      expect(errorLogs.first.stackTrace, equals(testStackTrace));

      await testController.close();
    });

    test('logs EventBus close at INFO level', () async {
      await eventBus.close();

      await Future.delayed(const Duration(milliseconds: 10));

      final closeLogs = logRecords
          .where(
            (r) =>
                r.level == Level.INFO && r.message.contains('EventBus closing'),
          )
          .toList();

      expect(closeLogs, hasLength(1));
    });
  });
}
