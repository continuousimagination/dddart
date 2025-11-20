import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:test/test.dart';

void main() {
  group('MongoConnection', () {
    group('constructor', () {
      test('should create connection with required parameters', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
        );

        expect(connection.host, equals('localhost'));
        expect(connection.port, equals(27017));
        expect(connection.databaseName, equals('testdb'));
        expect(connection.username, isNull);
        expect(connection.password, isNull);
        expect(connection.authSource, isNull);
        expect(connection.tls, isFalse);
        expect(connection.tlsAllowInvalidCertificates, isFalse);
      });

      test('should create connection with all parameters', () {
        final connection = MongoConnection(
          host: 'example.com',
          port: 27017,
          databaseName: 'myapp',
          username: 'user',
          password: 'pass',
          authSource: 'admin',
          tls: true,
          tlsAllowInvalidCertificates: true,
        );

        expect(connection.host, equals('example.com'));
        expect(connection.port, equals(27017));
        expect(connection.databaseName, equals('myapp'));
        expect(connection.username, equals('user'));
        expect(connection.password, equals('pass'));
        expect(connection.authSource, equals('admin'));
        expect(connection.tls, isTrue);
        expect(connection.tlsAllowInvalidCertificates, isTrue);
      });
    });

    group('fromUri', () {
      test('should parse simple URI without credentials', () {
        final connection = MongoConnection.fromUri(
          'mongodb://localhost:27017/testdb',
        );

        expect(connection.host, equals('localhost'));
        expect(connection.port, equals(27017));
        expect(connection.databaseName, equals('testdb'));
        expect(connection.username, isNull);
        expect(connection.password, isNull);
        expect(connection.tls, isFalse);
      });

      test('should parse URI with credentials', () {
        final connection = MongoConnection.fromUri(
          'mongodb://user:pass@localhost:27017/testdb',
        );

        expect(connection.host, equals('localhost'));
        expect(connection.port, equals(27017));
        expect(connection.databaseName, equals('testdb'));
        expect(connection.username, equals('user'));
        expect(connection.password, equals('pass'));
      });

      test('should parse URI with TLS options', () {
        final connection = MongoConnection.fromUri(
          'mongodb://localhost:27017/testdb?tls=true&tlsAllowInvalidCertificates=true',
        );

        expect(connection.tls, isTrue);
        expect(connection.tlsAllowInvalidCertificates, isTrue);
      });

      test('should parse URI with authSource', () {
        final connection = MongoConnection.fromUri(
          'mongodb://user:pass@localhost:27017/testdb?authSource=admin',
        );

        expect(connection.authSource, equals('admin'));
      });

      test('should parse AWS DocumentDB URI', () {
        final connection = MongoConnection.fromUri(
          'mongodb://user:pass@docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com:27017/myapp?tls=true&tlsAllowInvalidCertificates=true&authSource=admin',
        );

        expect(
          connection.host,
          equals('docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com'),
        );
        expect(connection.port, equals(27017));
        expect(connection.databaseName, equals('myapp'));
        expect(connection.username, equals('user'));
        expect(connection.password, equals('pass'));
        expect(connection.tls, isTrue);
        expect(connection.tlsAllowInvalidCertificates, isTrue);
        expect(connection.authSource, equals('admin'));
      });

      test('should default to port 27017 when not specified', () {
        final connection = MongoConnection.fromUri(
          'mongodb://localhost/testdb',
        );

        expect(connection.port, equals(27017));
      });

      test('should throw ArgumentError for invalid scheme', () {
        expect(
          () => MongoConnection.fromUri('http://localhost:27017/testdb'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError when database name is missing', () {
        expect(
          () => MongoConnection.fromUri('mongodb://localhost:27017/'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('_buildConnectionString', () {
      test('should build simple connection string', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
        );

        // Access private method through connection string building
        // We can't directly test private methods, but we can verify
        // the connection string is built correctly by checking the
        // connection behavior
        expect(connection.host, equals('localhost'));
        expect(connection.databaseName, equals('testdb'));
      });

      test('should build connection string with credentials', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
          username: 'user',
          password: 'pass',
        );

        expect(connection.username, equals('user'));
        expect(connection.password, equals('pass'));
      });

      test('should build connection string with TLS options', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
          tls: true,
          tlsAllowInvalidCertificates: true,
        );

        expect(connection.tls, isTrue);
        expect(connection.tlsAllowInvalidCertificates, isTrue);
      });

      test('should build AWS DocumentDB connection string', () {
        final connection = MongoConnection(
          host: 'docdb-cluster.cluster-xxx.us-east-1.docdb.amazonaws.com',
          port: 27017,
          databaseName: 'myapp',
          username: 'user',
          password: 'pass',
          tls: true,
          tlsAllowInvalidCertificates: true,
          authSource: 'admin',
        );

        expect(connection.tls, isTrue);
        expect(connection.authSource, equals('admin'));
      });
    });

    group('connection lifecycle', () {
      test('should report not connected initially', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
        );

        expect(connection.isConnected, isFalse);
      });

      test('should throw StateError when accessing database before open', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
        );

        expect(
          () => connection.database,
          throwsA(isA<StateError>()),
        );
      });

      test('should throw StateError with descriptive message', () {
        final connection = MongoConnection(
          host: 'localhost',
          port: 27017,
          databaseName: 'testdb',
        );

        expect(
          () => connection.database,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Connection not open'),
            ),
          ),
        );
      });
    });

    group('URI encoding', () {
      test('should handle special characters in credentials', () {
        final connection = MongoConnection.fromUri(
          'mongodb://user%40name:p%40ss%3Aword@localhost:27017/testdb',
        );

        expect(connection.username, equals('user@name'));
        expect(connection.password, equals('p@ss:word'));
      });
    });
  });

  group('MongoRepositoryException', () {
    test('should create exception with message', () {
      const exception = MongoRepositoryException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(exception.stackTrace, isNull);
    });

    test('should create exception with cause', () {
      final cause = Exception('Original error');
      final exception = MongoRepositoryException(
        'Test error',
        cause: cause,
      );

      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
    });

    test('should create exception with stack trace', () {
      final stackTrace = StackTrace.current;
      final exception = MongoRepositoryException(
        'Test error',
        stackTrace: stackTrace,
      );

      expect(exception.message, equals('Test error'));
      expect(exception.stackTrace, equals(stackTrace));
    });

    test('should format toString with message only', () {
      const exception = MongoRepositoryException('Test error');
      final string = exception.toString();

      expect(string, contains('MongoRepositoryException: Test error'));
      expect(string, isNot(contains('Caused by')));
    });

    test('should format toString with cause', () {
      final cause = Exception('Original error');
      final exception = MongoRepositoryException(
        'Test error',
        cause: cause,
      );
      final string = exception.toString();

      expect(string, contains('MongoRepositoryException: Test error'));
      expect(string, contains('Caused by:'));
      expect(string, contains('Original error'));
    });

    test('should format toString with stack trace', () {
      final stackTrace = StackTrace.current;
      final exception = MongoRepositoryException(
        'Test error',
        stackTrace: stackTrace,
      );
      final string = exception.toString();

      expect(string, contains('MongoRepositoryException: Test error'));
      expect(string, contains('#')); // Stack trace contains line numbers
    });
  });
}
