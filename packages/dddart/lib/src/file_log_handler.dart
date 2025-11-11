import 'dart:io';
import 'package:logging/logging.dart';

/// Type alias for log record formatter functions.
typedef LogRecordFormatter = String Function(LogRecord record);

/// Default formatter for log records.
///
/// Formats log records as: `[timestamp] [LEVEL] [logger] message`
/// Includes error details and stack traces when present.
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

/// A log handler that writes log records to a file.
///
/// Example usage:
/// ```dart
/// final handler = FileLogHandler('app.log');
/// Logger.root.level = Level.ALL;
/// Logger.root.onRecord.listen(handler);
///
/// // Use logging...
///
/// await handler.close();
/// ```
class FileLogHandler {
  /// Creates a FileLogHandler that writes to the specified file path.
  ///
  /// The [filePath] specifies where log records will be written.
  /// The optional [formatter] allows custom formatting of log records.
  /// If no formatter is provided, [defaultFormatter] is used.
  ///
  /// The file will be created if it doesn't exist, or appended to if it does.
  FileLogHandler(
    String filePath, {
    LogRecordFormatter? formatter,
  })  : _sink = File(filePath).openWrite(mode: FileMode.append),
        _formatter = formatter ?? defaultFormatter;
  final IOSink _sink;
  final LogRecordFormatter _formatter;

  /// Writes a log record to the file.
  ///
  /// This method is designed to be used as a listener for Logger.onRecord:
  /// ```dart
  /// Logger.root.onRecord.listen(handler);
  /// ```
  ///
  /// If an error occurs during writing, it will be printed to stderr
  /// but will not crash the application.
  void call(LogRecord record) {
    try {
      final formatted = _formatter(record);
      _sink.writeln(formatted);
    } catch (e) {
      // Print to stderr but don't crash
      stderr.writeln('FileLogHandler error: $e');
    }
  }

  /// Flushes any buffered data and closes the file.
  ///
  /// This should be called when the application is shutting down
  /// to ensure all log records are written to disk.
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
