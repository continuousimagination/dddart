# Implementation Plan

- [x] 1. Add logging package dependency to dddart
  - Add `logging: ^1.2.0` to pubspec.yaml dependencies section
  - Run `dart pub get` to fetch the dependency
  - _Requirements: 1.1_

- [x] 2. Create FileLogHandler class
  - [x] 2.1 Implement FileLogHandler class with file I/O
    - Create `lib/src/file_log_handler.dart`
    - Implement constructor accepting file path and optional formatter
    - Implement call() method to write LogRecords to file
    - Implement close() method to flush and close file
    - Handle file I/O errors gracefully (catch and print to stderr)
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.9_
  
  - [x] 2.2 Implement default log formatter
    - Create default formatter function in file_log_handler.dart
    - Format as: `[timestamp] [LEVEL] [logger] message`
    - Include error details when present
    - Include stack trace when present
    - _Requirements: 3.6, 3.7, 3.8_
  
  - [x] 2.3 Write unit tests for FileLogHandler
    - Test file creation when file doesn't exist
    - Test appending to existing file
    - Test default formatter output format
    - Test custom formatter usage
    - Test error details in output
    - Test stack trace in output
    - Test graceful handling of file write errors
    - Test close() flushes and closes file
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 3. Export logging package classes from dddart
  - Update `lib/dddart.dart` to export Logger and Level from logging package
  - Add documentation comments explaining the logging integration
  - _Requirements: 1.2_

- [x] 4. Integrate logging into EventBus
  - [x] 4.1 Add logger to EventBus class
    - Create logger instance: `Logger('dddart.eventbus')`
    - Add FINE level logging when event is published
    - Add FINE level logging when subscription is created
    - Add SEVERE level logging when handler throws exception
    - Add INFO level logging when EventBus is closed
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [x] 4.2 Write integration tests for EventBus logging
    - Test event publishing logs at FINE level
    - Test subscription creation logs at FINE level
    - Test handler exception logs at SEVERE level with stack trace
    - Test EventBus close logs at INFO level
    - _Requirements: 9.5_

- [x] 5. Integrate logging into InMemoryRepository
  - [x] 5.1 Add logger to InMemoryRepository class
    - Create logger instance: `Logger('dddart.repository')`
    - Add FINE level logging for save() operations
    - Add FINE level logging for getById() operations
    - Add FINE level logging for deleteById() operations
    - Add SEVERE level logging for operation failures with exception details
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [x] 5.2 Write integration tests for Repository logging
    - Test save operation logs at FINE level
    - Test getById operation logs at FINE level
    - Test deleteById operation logs at FINE level
    - Test operation failure logs at SEVERE level with exception
    - _Requirements: 9.6_

- [x] 6. Add logging package dependency to dddart_rest
  - Add `logging: ^1.2.0` to dddart_rest pubspec.yaml dependencies
  - Run `dart pub get` in dddart_rest directory
  - _Requirements: 1.1_

- [x] 7. Integrate logging into CrudResource
  - [x] 7.1 Add logger to CrudResource class
    - Create logger instance: `Logger('dddart.rest')`
    - Add INFO level logging for incoming requests (method, path, aggregate type)
    - Add FINE level logging for responses (status code)
    - Add WARNING level logging for deserialization failures
    - Add SEVERE level logging for exceptions with stack trace
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [x] 7.2 Write integration tests for CrudResource logging
    - Test request logging at INFO level
    - Test response logging at FINE level
    - Test deserialization error logging at WARNING level
    - Test exception logging at SEVERE level with stack trace
    - _Requirements: 9.7_

- [x] 8. Update dddart package README with logging documentation
  - Add "Logging" section to README.md
  - Explain hierarchical logger structure
  - Provide console logging example
  - Provide file logging example
  - Provide component-specific level configuration example
  - Explain how to disable logging (no configuration needed)
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 9. Create logging examples
  - [x] 9.1 Create console logging example
    - Create `example/logging_console.dart`
    - Demonstrate basic console logging setup
    - Show EventBus and Repository logging output
    - _Requirements: 8.2, 8.6_
  
  - [x] 9.2 Create file logging example
    - Create `example/logging_file.dart`
    - Demonstrate FileLogHandler usage
    - Show proper cleanup with close()
    - _Requirements: 8.3, 8.6_
  
  - [x] 9.3 Create hierarchical configuration example
    - Create `example/logging_hierarchical.dart`
    - Demonstrate setting different levels per component
    - Show how parent logger settings affect children
    - _Requirements: 8.5, 8.6_

- [x] 10. Write configuration tests
  - Test hierarchical logger configuration
  - Test setting level on root 'dddart' logger affects all components
  - Test setting level on specific component overrides parent
  - Test multiple handlers can be attached
  - Test logging works when no handlers configured (no-op)
  - _Requirements: 9.10_

- [x] 11. Verify optional logging behavior
  - Manually test that DDDart components work without any logging configuration
  - Verify no crashes or exceptions when logging is not configured
  - Verify minimal performance overhead when logging is disabled
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
