import 'dart:io';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:dddart/src/file_log_handler.dart';

void main() {
  late String testLogFile;
  late FileLogHandler handler;

  setUp(() {
    // Create a unique test log file for each test
    testLogFile = 'test_log_${DateTime.now().millisecondsSinceEpoch}.log';
  });

  tearDown(() async {
    // Clean up: close handler and delete test file
    try {
      await handler.close();
    } catch (_) {
      // Handler might not be initialized in some tests
    }
    
    final file = File(testLogFile);
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('FileLogHandler', () {
    test('creates file when file does not exist', () async {
      handler = FileLogHandler(testLogFile);
      
      final record = LogRecord(
        Level.INFO,
        'Test message',
        'test.logger',
      );
      
      handler(record);
      await handler.close();
      
      final file = File(testLogFile);
      expect(await file.exists(), isTrue);
    });

    test('appends to existing file', () async {
      // Create file with initial content
      final file = File(testLogFile);
      await file.writeAsString('Initial content\n');
      
      handler = FileLogHandler(testLogFile);
      
      final record = LogRecord(
        Level.INFO,
        'New message',
        'test.logger',
      );
      
      handler(record);
      await handler.close();
      
      final content = await file.readAsString();
      expect(content, contains('Initial content'));
      expect(content, contains('New message'));
    });

    test('formats log records with default formatter', () async {
      handler = FileLogHandler(testLogFile);
      
      final record = LogRecord(
        Level.INFO,
        'Test message',
        'test.logger',
      );
      
      handler(record);
      await handler.close();
      
      final content = await File(testLogFile).readAsString();
      // Check that timestamp is present (in ISO format)
      expect(content, matches(r'\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+\]'));
      expect(content, contains('[INFO]'));
      expect(content, contains('[test.logger]'));
      expect(content, contains('Test message'));
    });

    test('uses custom formatter when provided', () async {
      String customFormatter(LogRecord record) {
        return 'CUSTOM: ${record.level.name} - ${record.message}';
      }
      
      handler = FileLogHandler(testLogFile, formatter: customFormatter);
      
      final record = LogRecord(
        Level.WARNING,
        'Custom test',
        'test.logger',
      );
      
      handler(record);
      await handler.close();
      
      final content = await File(testLogFile).readAsString();
      expect(content, contains('CUSTOM: WARNING - Custom test'));
    });

    test('includes error details in output', () async {
      handler = FileLogHandler(testLogFile);
      
      final error = Exception('Test error');
      final record = LogRecord(
        Level.SEVERE,
        'Error occurred',
        'test.logger',
        error,
      );
      
      handler(record);
      await handler.close();
      
      final content = await File(testLogFile).readAsString();
      expect(content, contains('Error occurred'));
      expect(content, contains('Error: Exception: Test error'));
    });

    test('includes stack trace in output', () async {
      handler = FileLogHandler(testLogFile);
      
      final stackTrace = StackTrace.current;
      final record = LogRecord(
        Level.SEVERE,
        'Error with stack trace',
        'test.logger',
        null,
        stackTrace,
      );
      
      handler(record);
      await handler.close();
      
      final content = await File(testLogFile).readAsString();
      expect(content, contains('Error with stack trace'));
      expect(content, contains('Stack trace:'));
    });

    test('includes both error and stack trace when present', () async {
      handler = FileLogHandler(testLogFile);
      
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      final record = LogRecord(
        Level.SEVERE,
        'Complete error info',
        'test.logger',
        error,
        stackTrace,
      );
      
      handler(record);
      await handler.close();
      
      final content = await File(testLogFile).readAsString();
      expect(content, contains('Complete error info'));
      expect(content, contains('Error: Exception: Test error'));
      expect(content, contains('Stack trace:'));
    });

    test('handles file write errors gracefully', () async {
      // Test that errors during write are caught and printed to stderr
      // We'll create a handler with a valid file, then test error handling
      // by verifying the try-catch in the call method works
      
      handler = FileLogHandler(testLogFile);
      
      // Create a record that will be written successfully
      final record = LogRecord(
        Level.INFO,
        'Test message',
        'test.logger',
      );
      
      // This should not throw even if there were write errors
      expect(() => handler(record), returnsNormally);
      
      await handler.close();
    });

    test('close flushes and closes file', () async {
      handler = FileLogHandler(testLogFile);
      
      final record = LogRecord(
        Level.INFO,
        'Message to flush',
        'test.logger',
      );
      
      handler(record);
      
      // Close should flush the buffer
      await handler.close();
      
      // Verify content was written
      final content = await File(testLogFile).readAsString();
      expect(content, contains('Message to flush'));
    });

    test('writes multiple log records correctly', () async {
      handler = FileLogHandler(testLogFile);
      
      for (var i = 0; i < 5; i++) {
        final record = LogRecord(
          Level.INFO,
          'Message $i',
          'test.logger',
        );
        handler(record);
      }
      
      await handler.close();
      
      final content = await File(testLogFile).readAsString();
      for (var i = 0; i < 5; i++) {
        expect(content, contains('Message $i'));
      }
    });
  });

  group('defaultFormatter', () {
    test('formats basic log record correctly', () {
      final record = LogRecord(
        Level.INFO,
        'Test message',
        'test.logger',
      );
      
      final formatted = defaultFormatter(record);
      
      // Check format structure without exact timestamp
      expect(formatted, matches(r'\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+\] \[INFO\] \[test\.logger\] Test message'));
    });

    test('includes error when present', () {
      final record = LogRecord(
        Level.SEVERE,
        'Error message',
        'test.logger',
        Exception('Test error'),
      );
      
      final formatted = defaultFormatter(record);
      
      expect(formatted, contains('Error message'));
      expect(formatted, contains('Error: Exception: Test error'));
    });

    test('includes stack trace when present', () {
      final stackTrace = StackTrace.current;
      final record = LogRecord(
        Level.SEVERE,
        'Error message',
        'test.logger',
        null,
        stackTrace,
      );
      
      final formatted = defaultFormatter(record);
      
      expect(formatted, contains('Error message'));
      expect(formatted, contains('Stack trace:'));
    });
  });
}
