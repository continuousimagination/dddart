/// dddart: supported DDDart application and extension APIs.
///
/// Complete setup and runnable examples:
/// https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/core/README.md
///
/// Supported imports and extension contracts:
/// https://github.com/continuousimagination/dddart/blob/main/docs/PUBLIC_API.md
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
/// - `dddart.rest` - REST API framework logging (in dddart_rest package)
///
/// ### Enabling Logging
///
/// Logging is completely optional. To enable it, configure handlers on the
/// root logger or specific component loggers:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
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
export 'src/conditional_aggregate_repository.dart';
export 'src/conditional_repository.dart';
export 'src/domain_event.dart';
export 'src/entity.dart';
export 'src/event_bus.dart';
export 'src/event_publisher.dart';
export 'src/event_publishing_repository.dart';
export 'src/file_log_handler.dart';
export 'src/identity.dart';
export 'src/in_memory_conditional_repository.dart';
export 'src/in_memory_repository.dart';
export 'src/repository.dart';
export 'src/repository_exception.dart';
export 'src/save_with_events.dart';
export 'src/uuid_value.dart';
export 'src/value.dart';
