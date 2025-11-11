# Design Document

## Overview

This design integrates the official Dart `logging` package into the DDDart framework, providing optional diagnostic logging across all DDDart components. The design leverages the logging package's hierarchical logger structure and handler-based architecture to enable flexible, configurable logging without requiring any setup for users who don't need it.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Application                         │
│  - Configures logging (optional)                            │
│  - Attaches handlers to 'dddart' logger                     │
│  - Sets log levels per component                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Dart logging Package                        │
│  - Hierarchical logger tree                                 │
│  - Level filtering                                          │
│  - Handler dispatch                                         │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                ▼             ▼             ▼
         ┌──────────┐  ┌──────────┐  ┌──────────┐
         │ Console  │  │   File   │  │  Custom  │
         │ Handler  │  │ Handler  │  │ Handler  │
         └──────────┘  └──────────┘  └──────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  DDDart          │
                    │  Components      │
                    │  - EventBus      │
                    │  - Repository    │
                    │  - CrudResource  │
                    └──────────────────┘
```

### Logger Hierarchy

```
dddart (root)
├── dddart.eventbus
├── dddart.repository
└── dddart.http
```

Each component gets its own logger, allowing fine-grained control over logging levels.

## Components and Interfaces

### 1. FileLogHandler

A custom handler that writes log records to a file.

**Class Definition:**
```dart
class FileLogHandler {
  FileLogHandler(
    String filePath, {
    LogRecordFormatter? formatter,
  });
  
  void call(LogRecord record);
  Future<void> close();
}
```

**Responsibilities:**
- Open and manage file handle for writing
- Format LogRecords using provided or default formatter
- Write formatted messages to file
- Handle file I/O errors gracefully
- Flush and close file on shutdown

**Default Formatter:**
```
[2024-01-15T10:30:45.123456] [INFO] [dddart.eventbus] Event published: OrderPlaced
```

### 2. LogRecordFormatter

A type alias for formatter functions.

**Type Definition:**
```dart
typedef LogRecordFormatter = String Function(LogRecord record);
```

**Default Implementation:**
```dart
String defaultFormatter(LogRecord record) {
  final timestamp = record.time.toIso8601String();
  final level = record.level.name;
  final logger = record.loggerName;
  final message = record.message;
  
  var output = '[$timestamp] [$level] [$logger] $message';
  
  if (record.error != null) {
    output += '\nError: ${record.error}';
  }
  
  if (record.stackTrace != null) {
    output += '\nStack trace:\n${record.stackTrace}';
  }
  
  return output;
}
```

### 3. EventBus Integration

**Logger Name:** `dddart.eventbus`

**Logging Points:**
- Event published (FINE level)
- Subscription created (FINE level)
- Handler exception (SEVERE level)
- EventBus closed (INFO level)

**Implementation Approach:**
```dart
class EventBus {
  final Logger _logger = Logger('dddart.eventbus');
  
  void publish(DomainEvent event) {
    _logger.fine('Publishing event: ${event.runtimeType} for aggregate ${event.aggregateId}');
    // ... existing publish logic
  }
  
  Stream<T> on<T extends DomainEvent>() {
    _logger.fine('Creating subscription for event type: $T');
    // ... existing subscription logic
  }
}
```

### 4. InMemoryRepository Integration

**Logger Name:** `dddart.repository`

**Logging Points:**
- Save operation (FINE level)
- GetById operation (FINE level)
- DeleteById operation (FINE level)
- Operation failure (SEVERE level)

**Implementation Approach:**
```dart
class InMemoryRepository<T extends AggregateRoot> implements Repository<T> {
  final Logger _logger = Logger('dddart.repository');
  
  @override
  Future<void> save(T aggregate) async {
    _logger.fine('Saving ${T.toString()} with ID: ${aggregate.id}');
    // ... existing save logic
  }
  
  @override
  Future<T> getById(UuidValue id) async {
    _logger.fine('Retrieving ${T.toString()} with ID: $id');
    // ... existing getById logic
  }
}
```

### 5. CrudResource Integration (dddart_http)

**Logger Name:** `dddart.http`

**Logging Points:**
- Request received (INFO level)
- Response sent (FINE level)
- Deserialization error (WARNING level)
- Exception during handling (SEVERE level)

**Implementation Approach:**
```dart
class CrudResource<T extends AggregateRoot> {
  final Logger _logger = Logger('dddart.http');
  
  Future<Response> handleGetById(Request request, String id) async {
    _logger.info('GET /${path}/$id - Retrieving ${T.toString()}');
    
    try {
      // ... existing logic
      _logger.fine('GET /${path}/$id - 200 OK');
      return response;
    } catch (e, stackTrace) {
      _logger.severe('GET /${path}/$id - Error', e, stackTrace);
      return _handleException(e, stackTrace);
    }
  }
}
```

## Data Models

### LogRecord (from logging package)

The standard LogRecord class contains:
- `time`: DateTime with microsecond precision
- `level`: Level enum (FINE, INFO, WARNING, SEVERE, etc.)
- `message`: String message
- `loggerName`: Hierarchical logger name
- `error`: Optional error object
- `stackTrace`: Optional stack trace
- `sequenceNumber`: Monotonically increasing number
- `object`: Optional arbitrary object

### Level (from logging package)

Standard log levels in order of severity:
- `Level.ALL` (0) - Log everything
- `Level.FINEST` (300)
- `Level.FINER` (400)
- `Level.FINE` (500) - Used for detailed tracing
- `Level.CONFIG` (700)
- `Level.INFO` (800) - Used for informational messages
- `Level.WARNING` (900) - Used for warnings
- `Level.SEVERE` (1000) - Used for errors
- `Level.SHOUT` (1200) - Used for critical errors
- `Level.OFF` (2000) - Disable logging

## Error Handling

### File I/O Errors

**Strategy:** Graceful degradation

When FileLogHandler encounters file I/O errors:
1. Catch the exception
2. Print error to stderr (so developers know logging failed)
3. Continue execution (don't crash the application)

**Implementation:**
```dart
void call(LogRecord record) {
  try {
    final formatted = _formatter(record);
    _sink.writeln(formatted);
  } catch (e) {
    // Print to stderr but don't crash
    stderr.writeln('FileLogHandler error: $e');
  }
}
```

### Missing Logger Configuration

**Strategy:** No-op by default

The logging package automatically discards log messages when no handlers are attached. DDDart components simply log messages - if the user hasn't configured logging, the messages are silently discarded with minimal overhead.

## Testing Strategy

### Unit Tests for FileLogHandler

**Test Cases:**
1. Creates file if it doesn't exist
2. Appends to existing file
3. Formats log records correctly with default formatter
4. Uses custom formatter when provided
5. Includes error details in output
6. Includes stack trace in output
7. Handles file write errors gracefully
8. Flushes and closes file on close()
9. Handles concurrent writes correctly

### Integration Tests for DDDart Components

**Test Cases:**
1. EventBus logs event publishing at FINE level
2. EventBus logs subscriptions at FINE level
3. EventBus logs handler exceptions at SEVERE level
4. InMemoryRepository logs save operations at FINE level
5. InMemoryRepository logs retrieval operations at FINE level
6. InMemoryRepository logs delete operations at FINE level
7. InMemoryRepository logs failures at SEVERE level
8. CrudResource logs requests at INFO level
9. CrudResource logs responses at FINE level
10. CrudResource logs exceptions at SEVERE level

### Configuration Tests

**Test Cases:**
1. Hierarchical logger configuration works correctly
2. Setting level on 'dddart' affects all components
3. Setting level on specific component overrides parent
4. Multiple handlers can be attached
5. Logging works when no handlers configured (no-op)

## Usage Examples

### Example 1: Console Logging

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() {
  // Configure console logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  // Use DDDart components - they will log automatically
  final eventBus = EventBus();
  final repository = InMemoryRepository<User>();
  
  // Logs will appear in console
}
```

### Example 2: File Logging

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() async {
  // Configure file logging
  final fileHandler = FileLogHandler('app.log');
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(fileHandler);
  
  // Use DDDart components
  final eventBus = EventBus();
  final repository = InMemoryRepository<User>();
  
  // Logs will be written to app.log
  
  // Clean up
  await fileHandler.close();
}
```

### Example 3: Component-Specific Levels

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() {
  // Configure logging with different levels per component
  Logger.root.level = Level.INFO; // Default level
  
  // Enable detailed logging for EventBus only
  Logger('dddart.eventbus').level = Level.FINE;
  
  // Disable repository logging
  Logger('dddart.repository').level = Level.OFF;
  
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });
  
  // EventBus will log at FINE level
  // Repository will not log at all
}
```

### Example 4: Custom Formatter

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

String jsonFormatter(LogRecord record) {
  return jsonEncode({
    'timestamp': record.time.toIso8601String(),
    'level': record.level.name,
    'logger': record.loggerName,
    'message': record.message,
    'error': record.error?.toString(),
  });
}

void main() async {
  final fileHandler = FileLogHandler('app.json', formatter: jsonFormatter);
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(fileHandler);
  
  // Logs will be written as JSON
}
```

### Example 5: Multiple Handlers

```dart
import 'package:logging/logging.dart';
import 'package:dddart/dddart.dart';

void main() async {
  // Log to both console and file
  final fileHandler = FileLogHandler('app.log');
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Console handler
    print('${record.level.name}: ${record.message}');
    
    // File handler
    fileHandler(record);
  });
  
  // Logs go to both destinations
}
```

## Implementation Plan

### Phase 1: Core Logging Infrastructure (dddart package)

1. Add `logging` package dependency to pubspec.yaml
2. Create `FileLogHandler` class in `lib/src/file_log_handler.dart`
3. Create default formatter function
4. Export Logger and Level from logging package in `lib/dddart.dart`
5. Write comprehensive unit tests for FileLogHandler

### Phase 2: Component Integration (dddart package)

1. Add logging to EventBus
2. Add logging to InMemoryRepository
3. Write integration tests for component logging

### Phase 3: HTTP Integration (dddart_http package)

1. Add `logging` package dependency to dddart_http
2. Add logging to CrudResource
3. Write integration tests for HTTP logging

### Phase 4: Documentation and Examples

1. Update dddart README with logging section
2. Create example demonstrating console logging
3. Create example demonstrating file logging
4. Create example demonstrating hierarchical configuration
5. Document best practices for production logging

## Dependencies

### New Dependencies

**dddart package:**
- `logging: ^1.2.0` (production dependency)

**dddart_http package:**
- `logging: ^1.2.0` (production dependency)

### No Breaking Changes

This is a purely additive change. Existing code will continue to work without any modifications. Logging is completely optional.

## Performance Considerations

### Minimal Overhead When Disabled

When no handlers are configured, the logging package has minimal overhead:
- Logger creation: One-time cost per logger name
- Log method calls: Quick level check, then return if disabled
- No string formatting or I/O when disabled

### Lazy Message Evaluation

For expensive log messages, use lazy evaluation:

```dart
// Bad: String is always constructed
_logger.fine('Expensive operation: ${expensiveComputation()}');

// Good: Only evaluated if FINE level is enabled
if (_logger.isLoggable(Level.FINE)) {
  _logger.fine('Expensive operation: ${expensiveComputation()}');
}
```

### File I/O Performance

FileLogHandler writes synchronously to avoid complexity. For high-throughput scenarios, users can:
1. Use a higher log level to reduce volume
2. Implement a buffered handler
3. Use async I/O in a custom handler

## Security Considerations

### Sensitive Data in Logs

**Recommendation:** DDDart components should not log sensitive data (passwords, tokens, PII) by default.

**Implementation:**
- Log aggregate IDs and types, not full aggregate contents
- Log event types, not event payloads
- Log HTTP methods and paths, not request bodies

### File Permissions

FileLogHandler creates files with default permissions. Users should:
- Ensure log directory has appropriate permissions
- Consider log rotation and retention policies
- Avoid logging to world-readable locations

## Future Enhancements

### Potential Future Features

1. **Structured Logging Handler** - JSON-formatted logs for log aggregation services
2. **Rotating File Handler** - Automatic log rotation based on size or time
3. **Async File Handler** - Non-blocking I/O for high-throughput scenarios
4. **CloudWatch Handler** - Direct integration with AWS CloudWatch Logs
5. **Syslog Handler** - Integration with system logging facilities

These can be added as separate packages or contributed by the community.
