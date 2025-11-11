/// DDDart - A lightweight Domain-Driven Design (DDD) framework for Dart.
///
/// This library provides base classes and utilities to help developers
/// implement DDD principles in their applications.
library dddart;

/// ## Logging Integration
///
/// DDDart integrates with the official Dart [logging](https://pub.dev/packages/logging)
/// package to provide optional diagnostic logging across all components.
///
/// ### Hierarchical Logger Structure
///
/// DDDart uses hierarchical logger names with 'dddart' as the root:
/// - `dddart.eventbus` - EventBus component logging
/// - `dddart.repository` - Repository component logging
/// - `dddart.http` - HTTP framework logging (in dddart_http package)
///
/// ### Enabling Logging
///
/// Logging is completely optional. To enable it, configure handlers on the
/// root logger or specific component loggers:
///
/// ```dart
/// import 'package:logging/logging.dart';
/// import 'package:dddart/dddart.dart';
///
/// void main() {
///   // Enable console logging for all DDDart components
///   Logger.root.level = Level.ALL;
///   Logger.root.onRecord.listen((record) {
///     print('${record.level.name}: ${record.time}: ${record.message}');
///   });
///
///   // Or enable file logging
///   final fileHandler = FileLogHandler('app.log');
///   Logger.root.onRecord.listen(fileHandler);
///
///   // Or configure specific components
///   Logger('dddart.eventbus').level = Level.FINE;
///   Logger('dddart.repository').level = Level.OFF;
/// }
/// ```
///
/// ### Log Levels
///
/// DDDart components use the following log levels:
/// - `Level.FINE` - Detailed tracing (event publishing, repository operations)
/// - `Level.INFO` - Informational messages (EventBus closed, HTTP requests)
/// - `Level.WARNING` - Warnings (deserialization failures)
/// - `Level.SEVERE` - Errors (exceptions with stack traces)
///
/// See the [logging package documentation](https://pub.dev/packages/logging)
/// for complete configuration options.
export 'package:logging/logging.dart' show Level, Logger;

// Export all public classes
export 'src/aggregate_root.dart';
export 'src/domain_event.dart';
export 'src/entity.dart';
export 'src/event_bus.dart';
export 'src/file_log_handler.dart';
export 'src/in_memory_repository.dart';
export 'src/repository.dart';
export 'src/repository_exception.dart';
export 'src/uuid_value.dart';
export 'src/value.dart';
