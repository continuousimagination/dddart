import 'package:dddart_config/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigException', () {
    test('should format message without key', () {
      final exception = ConfigException('Something went wrong');

      expect(exception.message, equals('Something went wrong'));
      expect(exception.key, isNull);
      expect(
        exception.toString(),
        equals('ConfigException: Something went wrong'),
      );
    });

    test('should format message with key', () {
      final exception = ConfigException('Something went wrong', key: 'app.key');

      expect(exception.message, equals('Something went wrong'));
      expect(exception.key, equals('app.key'));
      expect(
        exception.toString(),
        equals('ConfigException: Something went wrong (key: app.key)'),
      );
    });
  });

  group('MissingConfigException', () {
    test('should create exception for missing key', () {
      final exception = MissingConfigException('database.host');

      expect(exception.message, equals('Required configuration key not found'));
      expect(exception.key, equals('database.host'));
      expect(
        exception.toString(),
        equals(
          'ConfigException: Required configuration key not found (key: database.host)',
        ),
      );
    });
  });

  group('TypeConversionException', () {
    test('should create exception with type and value details', () {
      final exception = TypeConversionException('database.port', 'int', 'abc');

      expect(exception.message, equals('Cannot convert "abc" to int'));
      expect(exception.key, equals('database.port'));
      expect(exception.expectedType, equals('int'));
      expect(exception.actualValue, equals('abc'));
      expect(
        exception.toString(),
        equals(
          'ConfigException: Cannot convert "abc" to int (key: database.port)',
        ),
      );
    });
  });

  group('ValidationException', () {
    test('should create exception with single failure', () {
      final exception = ValidationException(['database.host is required']);

      expect(exception.failures, hasLength(1));
      expect(exception.failures.first, equals('database.host is required'));
      expect(
        exception.toString(),
        equals(
          'ConfigException: Configuration validation failed: database.host is required',
        ),
      );
    });

    test('should create exception with multiple failures', () {
      final exception = ValidationException([
        'database.host is required',
        'logging.level must be one of [debug, info, warn, error]',
      ]);

      expect(exception.failures, hasLength(2));
      expect(
        exception.toString(),
        contains('database.host is required'),
      );
      expect(
        exception.toString(),
        contains('logging.level must be one of [debug, info, warn, error]'),
      );
    });
  });

  group('FileAccessException', () {
    test('should create exception with file path and cause', () {
      final cause = Exception('No such file or directory');
      final exception = FileAccessException('config.yaml', cause);

      expect(exception.filePath, equals('config.yaml'));
      expect(exception.cause, equals(cause));
      expect(
        exception.toString(),
        contains('Cannot access configuration file: config.yaml'),
      );
      expect(
        exception.toString(),
        contains('No such file or directory'),
      );
    });
  });
}
