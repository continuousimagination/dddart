import 'dart:async';
import 'package:dddart/dddart.dart';

import 'lib/user_aggregate.dart';
import 'lib/user_registered_event.dart';

/// Console logging example for DDDart.
///
/// This example demonstrates:
/// - Basic console logging setup
/// - EventBus logging output
/// - Repository logging output
/// - How to configure log levels
///
/// Run with: dart run example/logging_console.dart
Future<void> main() async {
  print('🔊 DDDart Console Logging Example\n');
  print('=' * 60);

  // Configure console logging
  // Set the root logger level to capture all messages
  Logger.root.level = Level.ALL;

  // Attach a console handler that prints log records
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  Stack trace:\n${record.stackTrace}');
    }
  });

  print('Console logging configured. All DDDart components will now log.\n');
  print('=' * 60);
  print('');

  await _demonstrateEventBusLogging();
  await _demonstrateRepositoryLogging();

  print('\n' + '=' * 60);
  print('✅ Console logging example completed!');
  print('=' * 60);
}

/// Demonstrate EventBus logging output
Future<void> _demonstrateEventBusLogging() async {
  print('📢 EventBus Logging Demo');
  print('-' * 60);

  final eventBus = EventBus();

  // Create a subscription (logs at FINE level)
  final subscription = eventBus.on<UserRegisteredEvent>().listen((event) {
    print('  📧 Application: Sending welcome email to ${event.email}');
  });

  // Register a user (raises an event)
  final user = UserAggregate.register(
    email: 'console.demo@example.com',
    fullName: 'Console Demo User',
    organizationId: 'org-console',
  );

  // Publish the event (logs at FINE level)
  for (final event in user.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  user.markEventsAsCommitted();

  // Give the stream time to process
  await Future.delayed(Duration(milliseconds: 50));

  // Clean up (logs at INFO level)
  await subscription.cancel();
  await eventBus.close();

  print('-' * 60);
  print('');
}

/// Demonstrate Repository logging output
Future<void> _demonstrateRepositoryLogging() async {
  print('💾 Repository Logging Demo');
  print('-' * 60);

  final repository = InMemoryRepository<UserAggregate>();

  // Create a user
  final user = UserAggregate.register(
    email: 'repo.demo@example.com',
    fullName: 'Repository Demo User',
    organizationId: 'org-repo',
  );
  user.markEventsAsCommitted();

  // Save operation (logs at FINE level)
  await repository.save(user);

  // Retrieve operation (logs at FINE level)
  final retrieved = await repository.getById(user.id);
  print('  ✓ Retrieved user: ${retrieved.email}');

  // Delete operation (logs at FINE level)
  await repository.deleteById(user.id);

  // Try to retrieve deleted user (logs at SEVERE level)
  try {
    await repository.getById(user.id);
  } catch (e) {
    print('  ✓ Expected error: User not found after deletion');
  }

  print('-' * 60);
  print('');
}
