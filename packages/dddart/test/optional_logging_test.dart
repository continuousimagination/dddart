import 'package:dddart/dddart.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

// Test domain models
class TestUser extends AggregateRoot {
  final String name;

  TestUser({
    required this.name,
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);
}

class UserRegisteredEvent extends DomainEvent {
  final String userName;

  UserRegisteredEvent({
    required UuidValue aggregateId,
    required this.userName,
    UuidValue? eventId,
    DateTime? occurredAt,
    Map<String, dynamic> context = const {},
  }) : super(
          aggregateId: aggregateId,
          eventId: eventId,
          occurredAt: occurredAt,
          context: context,
        );
}

void main() {
  group('Optional Logging Behavior', () {
    setUp(() {
      // Ensure no logging configuration exists
      Logger.root.clearListeners();
      Logger.root.level = Level.OFF;
    });

    test('EventBus works without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final eventBus = EventBus();
      final userId = UuidValue.generate();
      final event = UserRegisteredEvent(
        aggregateId: userId,
        userName: 'John Doe',
      );

      // Should not crash or throw exceptions
      expect(() => eventBus.publish(event), returnsNormally);

      // Subscription should work
      final subscription = eventBus.on<UserRegisteredEvent>();
      expect(subscription, isNotNull);

      // Should receive events
      var receivedEvent = false;
      subscription.listen((e) {
        receivedEvent = true;
        expect(e.userName, equals('John Doe'));
      });

      eventBus.publish(event);
      
      // Wait for async event delivery
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(receivedEvent, isTrue);

      await eventBus.close();
    });

    test('InMemoryRepository works without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestUser>();
      final userId = UuidValue.generate();
      final user = TestUser(id: userId, name: 'Jane Doe');

      // Should not crash or throw exceptions
      await repository.save(user);

      // Retrieval should work
      final retrieved = await repository.getById(userId);
      expect(retrieved.name, equals('Jane Doe'));

      // Deletion should work
      await repository.deleteById(userId);
    });

    test('Multiple operations work without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.3, 4.4, 4.5
      final eventBus = EventBus();
      final repository = InMemoryRepository<TestUser>();

      // Perform multiple operations
      for (var i = 0; i < 10; i++) {
        final userId = UuidValue.generate();
        final user = TestUser(id: userId, name: 'User $i');
        final event = UserRegisteredEvent(
          aggregateId: userId,
          userName: 'User $i',
        );

        // Should all work without issues
        await repository.save(user);
        eventBus.publish(event);
      }

      await eventBus.close();
    });

    test('Logging has minimal overhead when disabled', () async {
      // Requirement 4.3 - Verify minimal performance overhead
      final eventBus = EventBus();
      final repository = InMemoryRepository<TestUser>();
      final stopwatch = Stopwatch()..start();

      // Perform operations without logging
      for (var i = 0; i < 100; i++) {
        final userId = UuidValue.generate();
        final user = TestUser(id: userId, name: 'User $i');
        final event = UserRegisteredEvent(
          aggregateId: userId,
          userName: 'User $i',
        );

        await repository.save(user);
        eventBus.publish(event);
      }

      stopwatch.stop();
      final timeWithoutLogging = stopwatch.elapsedMicroseconds;

      // Time should be reasonable (less than 100ms for 100 operations)
      expect(timeWithoutLogging, lessThan(100000));

      await eventBus.close();
    });

    test('Components work correctly when Logger.root.level is OFF', () async {
      // Requirement 4.1, 4.2, 4.3
      Logger.root.level = Level.OFF;

      final eventBus = EventBus();
      final repository = InMemoryRepository<TestUser>();
      final userId = UuidValue.generate();
      final user = TestUser(id: userId, name: 'Test User');
      final event = UserRegisteredEvent(
        aggregateId: userId,
        userName: 'Test User',
      );

      // All operations should work normally
      await repository.save(user);
      eventBus.publish(event);

      await eventBus.close();
    });

    test('Components work when no handlers are attached', () async {
      // Requirement 4.1, 4.3
      // Set level to ALL but don't attach any handlers
      Logger.root.level = Level.ALL;
      Logger.root.clearListeners();

      final eventBus = EventBus();
      final repository = InMemoryRepository<TestUser>();
      final userId = UuidValue.generate();
      final user = TestUser(id: userId, name: 'Test User');
      final event = UserRegisteredEvent(
        aggregateId: userId,
        userName: 'Test User',
      );

      // Should work without crashes - logs are discarded
      await repository.save(user);
      eventBus.publish(event);

      await eventBus.close();
    });

    test('Repository operations complete successfully without logging', () async {
      // Requirement 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestUser>();
      final userId = UuidValue.generate();
      final user = TestUser(id: userId, name: 'Complete Test');

      // Save
      await repository.save(user);

      // Retrieve
      final retrieved = await repository.getById(userId);
      expect(retrieved.id, equals(userId));
      expect(retrieved.name, equals('Complete Test'));

      // Delete
      await repository.deleteById(userId);

      // Verify deletion
      expect(
        () async => await repository.getById(userId),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('EventBus subscription and publishing work without logging', () async {
      // Requirement 4.2, 4.4, 4.5
      final eventBus = EventBus();
      final receivedEvents = <UserRegisteredEvent>[];

      // Create subscription
      final subscription = eventBus.on<UserRegisteredEvent>();
      subscription.listen((event) {
        receivedEvents.add(event);
      });

      // Publish multiple events
      for (var i = 0; i < 5; i++) {
        final userId = UuidValue.generate();
        final event = UserRegisteredEvent(
          aggregateId: userId,
          userName: 'User $i',
        );
        eventBus.publish(event);
      }

      // Wait for async event delivery
      await Future.delayed(Duration(milliseconds: 10));

      // Verify all events received
      expect(receivedEvents.length, equals(5));
      for (var i = 0; i < 5; i++) {
        expect(receivedEvents[i].userName, equals('User $i'));
      }

      await eventBus.close();
    });
  });
}
