import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

import 'lib/user_aggregate.dart';
import 'lib/user_registered_event.dart';

/// Hierarchical logging configuration example for DDDart.
///
/// This example demonstrates:
/// - Setting different log levels per component
/// - How parent logger settings affect children
/// - Hierarchical logger structure (dddart.eventbus, dddart.repository)
/// - Fine-grained control over logging verbosity
///
/// Run with: dart run example/logging_hierarchical.dart
Future<void> main() async {
  print('🌳 DDDart Hierarchical Logging Configuration Example\n');
  print('=' * 60);
  
  // Enable hierarchical logging globally
  hierarchicalLoggingEnabled = true;

  await _demonstrateDefaultConfiguration();
  await _demonstrateComponentSpecificLevels();
  await _demonstrateParentChildRelationship();
  await _demonstrateSelectiveLogging();

  print('\n' + '=' * 60);
  print('✅ Hierarchical logging example completed!');
  print('=' * 60);
}

/// Demonstrate default configuration with all logging enabled
Future<void> _demonstrateDefaultConfiguration() async {
  print('1️⃣  Default Configuration (All Logging Enabled)');
  print('=' * 60);

  // Configure console logging with ALL level
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('  ${record.level.name.padRight(7)} [${record.loggerName}] ${record.message}');
  });

  print('Configuration: Logger.root.level = Level.ALL\n');

  await _performOperations('Scenario 1');

  print('');
}

/// Demonstrate setting different levels for different components
Future<void> _demonstrateComponentSpecificLevels() async {
  print('2️⃣  Component-Specific Levels');
  print('=' * 60);

  // Clear previous handlers
  Logger.root.clearListeners();

  // Set root to INFO (less verbose)
  Logger.root.level = Level.INFO;

  // Enable detailed logging for EventBus only
  Logger('dddart.eventbus').level = Level.FINE;

  // Keep Repository at INFO level (inherits from root)
  // Logger('dddart.repository').level is not set, so it uses root level

  Logger.root.onRecord.listen((record) {
    print('  ${record.level.name.padRight(7)} [${record.loggerName}] ${record.message}');
  });

  print('Configuration:');
  print('  - Logger.root.level = Level.INFO');
  print('  - Logger(\'dddart.eventbus\').level = Level.FINE');
  print('  - Logger(\'dddart.repository\') uses root level (INFO)\n');
  print('Result: EventBus shows FINE messages, Repository only shows INFO+\n');

  await _performOperations('Scenario 2');

  print('');
}

/// Demonstrate parent-child logger relationship
Future<void> _demonstrateParentChildRelationship() async {
  print('3️⃣  Parent-Child Logger Relationship');
  print('=' * 60);

  // Clear previous handlers
  Logger.root.clearListeners();

  // Reset root level to allow all messages through
  Logger.root.level = Level.ALL;

  // Set the parent 'dddart' logger to SEVERE
  // This means child loggers will only emit SEVERE messages
  Logger('dddart').level = Level.SEVERE;

  Logger.root.onRecord.listen((record) {
    print('  ${record.level.name.padRight(7)} [${record.loggerName}] ${record.message}');
  });

  print('Configuration:');
  print('  - hierarchicalLoggingEnabled = true');
  print('  - Logger(\'dddart\').level = Level.SEVERE');
  print('  - Child loggers (eventbus, repository) inherit SEVERE level\n');
  print('Result: Only SEVERE messages are emitted\n');

  await _performOperations('Scenario 3');

  print('');
}

/// Demonstrate selective logging (disable specific components)
Future<void> _demonstrateSelectiveLogging() async {
  print('4️⃣  Selective Logging (Disable Specific Components)');
  print('=' * 60);

  // Clear previous handlers and reset levels
  Logger.root.clearListeners();
  
  Logger('dddart').level = null; // Reset parent
  Logger('dddart.eventbus').level = null; // Reset

  // Enable all logging at root
  Logger.root.level = Level.ALL;

  // Disable EventBus logging completely
  Logger('dddart.eventbus').level = Level.OFF;

  // Keep Repository logging at FINE level
  Logger('dddart.repository').level = Level.FINE;

  Logger.root.onRecord.listen((record) {
    print('  ${record.level.name.padRight(7)} [${record.loggerName}] ${record.message}');
  });

  print('Configuration:');
  print('  - Logger.root.level = Level.ALL');
  print('  - Logger(\'dddart.eventbus\').level = Level.OFF (disabled)');
  print('  - Logger(\'dddart.repository\').level = Level.FINE\n');
  print('Result: Only Repository logs are shown, EventBus is silent\n');

  await _performOperations('Scenario 4');

  print('');
}

/// Perform operations that generate log messages
Future<void> _performOperations(String scenario) async {
  final eventBus = EventBus();

  // Create subscription
  final subscription = eventBus.on<UserRegisteredEvent>().listen((event) {
    // Handler doesn't log, but subscription creation does
  });

  // Create repository
  final repository = InMemoryRepository<UserAggregate>();

  // Register user
  final user = UserAggregate.register(
    email: '$scenario@example.com',
    fullName: 'User for $scenario',
    organizationId: 'org-hierarchical',
  );

  // Publish event
  for (final event in user.getUncommittedEvents()) {
    eventBus.publish(event);
  }
  user.markEventsAsCommitted();

  await Future.delayed(Duration(milliseconds: 50));

  // Repository operations
  await repository.save(user);
  await repository.getById(user.id);

  // Try to trigger an error (SEVERE level)
  try {
    await repository.getById(UuidValue.generate());
  } catch (e) {
    // Expected error
  }

  // Clean up
  await subscription.cancel();
  await eventBus.close();
}
