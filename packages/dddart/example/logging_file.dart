import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

import 'lib/user_aggregate.dart';
import 'lib/user_registered_event.dart';
import 'lib/order_placed_event.dart';

/// File logging example for DDDart.
///
/// This example demonstrates:
/// - FileLogHandler usage
/// - Writing logs to a file
/// - Proper cleanup with close()
/// - Custom log formatting
///
/// Run with: dart run example/logging_file.dart
Future<void> main() async {
  print('📁 DDDart File Logging Example\n');
  print('=' * 60);

  final logFile = 'dddart_example.log';

  // Delete existing log file if it exists
  final file = File(logFile);
  if (await file.exists()) {
    await file.delete();
    print('Deleted existing log file');
  }

  // Configure file logging
  final fileHandler = FileLogHandler(logFile);

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(fileHandler);

  print('File logging configured. Logs will be written to: $logFile\n');
  print('=' * 60);
  print('');

  await _performOperations();

  // Important: Close the file handler to flush and close the file
  print('\n' + '=' * 60);
  print('Closing file handler...');
  await fileHandler.close();
  print('File handler closed.');

  // Display the log file contents
  await _displayLogFile(logFile);

  print('\n' + '=' * 60);
  print('✅ File logging example completed!');
  print('Log file saved to: $logFile');
  print('=' * 60);
}

/// Perform various operations that generate log messages
Future<void> _performOperations() async {
  print('🔄 Performing operations (logs written to file)...\n');

  // EventBus operations
  print('1. Creating EventBus and subscribing to events...');
  final eventBus = EventBus();

  final subscription = eventBus.on<UserRegisteredEvent>().listen((event) {
    // This won't be logged, but the subscription creation will be
  });

  // Repository operations
  print('2. Creating repository and saving aggregates...');
  final repository = InMemoryRepository<UserAggregate>();

  final user1 = UserAggregate.register(
    email: 'alice@example.com',
    fullName: 'Alice Johnson',
    organizationId: 'org-001',
  );

  final user2 = UserAggregate.register(
    email: 'bob@example.com',
    fullName: 'Bob Smith',
    organizationId: 'org-002',
  );

  // Publish events
  print('3. Publishing domain events...');
  for (final event in user1.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  user1.markEventsAsCommitted();

  for (final event in user2.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  user2.markEventsAsCommitted();

  // Publish an order event
  final orderId = UuidValue.generate();
  eventBus.publish(OrderPlacedEvent(
    orderId: orderId,
    customerId: user1.id.uuid,
    totalAmount: 299.99,
    currency: 'USD',
    itemCount: 3,
  ));

  await Future.delayed(Duration(milliseconds: 50));

  // Save to repository
  print('4. Saving aggregates to repository...');
  await repository.save(user1);
  await repository.save(user2);

  // Retrieve from repository
  print('5. Retrieving aggregates from repository...');
  await repository.getById(user1.id);
  await repository.getById(user2.id);

  // Delete an aggregate
  print('6. Deleting an aggregate...');
  await repository.deleteById(user2.id);

  // Try to retrieve deleted aggregate (will log error)
  print('7. Attempting to retrieve deleted aggregate (will fail)...');
  try {
    await repository.getById(user2.id);
  } catch (e) {
    // Expected error
  }

  // Clean up
  print('8. Closing EventBus...');
  await subscription.cancel();
  await eventBus.close();

  print('\n✓ All operations completed');
}

/// Display the contents of the log file
Future<void> _displayLogFile(String logFile) async {
  print('\n' + '=' * 60);
  print('📄 Log File Contents:');
  print('=' * 60);
  print('');

  final file = File(logFile);
  if (await file.exists()) {
    final contents = await file.readAsString();
    print(contents);
  } else {
    print('Log file not found!');
  }
}
