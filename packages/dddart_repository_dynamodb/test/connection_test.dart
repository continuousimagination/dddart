import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart_repository_dynamodb/src/connection/dynamo_connection.dart';
import 'package:test/test.dart';

void main() {
  group('DynamoConnection', () {
    group('constructor', () {
      test('should create connection with required region', () {
        final connection = DynamoConnection(region: 'us-east-1');

        expect(connection.region, equals('us-east-1'));
        expect(connection.credentials, isNull);
        expect(connection.endpoint, isNull);
      });

      test('should create connection with credentials', () {
        final credentials = AwsClientCredentials(
          accessKey: 'test-key',
          secretKey: 'test-secret',
        );
        final connection = DynamoConnection(
          region: 'us-west-2',
          credentials: credentials,
        );

        expect(connection.region, equals('us-west-2'));
        expect(connection.credentials, equals(credentials));
        expect(connection.endpoint, isNull);
      });

      test('should create connection with custom endpoint', () {
        final connection = DynamoConnection(
          region: 'us-east-1',
          endpoint: 'http://localhost:8000',
        );

        expect(connection.region, equals('us-east-1'));
        expect(connection.endpoint, equals('http://localhost:8000'));
      });

      test('should create connection with all parameters', () {
        final credentials = AwsClientCredentials(
          accessKey: 'test-key',
          secretKey: 'test-secret',
        );
        final connection = DynamoConnection(
          region: 'eu-west-1',
          credentials: credentials,
          endpoint: 'http://localstack:4566',
        );

        expect(connection.region, equals('eu-west-1'));
        expect(connection.credentials, equals(credentials));
        expect(connection.endpoint, equals('http://localstack:4566'));
      });
    });

    group('local factory', () {
      test('should create connection for DynamoDB Local with default port', () {
        final connection = DynamoConnection.local();

        expect(connection.region, equals('us-east-1'));
        expect(connection.credentials, isNotNull);
        expect(connection.credentials!.accessKey, equals('dummy'));
        expect(connection.credentials!.secretKey, equals('dummy'));
        expect(connection.endpoint, equals('http://localhost:8000'));
      });

      test('should create connection for DynamoDB Local with custom port', () {
        final connection = DynamoConnection.local(port: 8001);

        expect(connection.region, equals('us-east-1'));
        expect(connection.credentials, isNotNull);
        expect(connection.endpoint, equals('http://localhost:8001'));
      });
    });

    group('client getter', () {
      test('should lazily initialize DynamoDB client', () {
        final connection = DynamoConnection(region: 'us-east-1');

        // Client should be created on first access
        final client = connection.client;
        expect(client, isNotNull);
        expect(client, isA<DynamoDB>());

        // Should return same instance on subsequent calls
        final client2 = connection.client;
        expect(client2, same(client));

        connection.dispose();
      });

      test('should initialize client with correct region', () {
        final connection = DynamoConnection(region: 'eu-central-1');

        final client = connection.client;
        expect(client, isNotNull);

        connection.dispose();
      });

      test('should initialize client with credentials', () {
        final credentials = AwsClientCredentials(
          accessKey: 'test-key',
          secretKey: 'test-secret',
        );
        final connection = DynamoConnection(
          region: 'us-east-1',
          credentials: credentials,
        );

        final client = connection.client;
        expect(client, isNotNull);

        connection.dispose();
      });

      test('should initialize client with custom endpoint', () {
        final connection = DynamoConnection(
          region: 'us-east-1',
          endpoint: 'http://localhost:8000',
        );

        final client = connection.client;
        expect(client, isNotNull);

        connection.dispose();
      });
    });

    group('dispose', () {
      test('should dispose client resources', () {
        final connection = DynamoConnection(region: 'us-east-1');

        // Initialize client
        final client = connection.client;
        expect(client, isNotNull);

        // Dispose should clean up
        connection.dispose();

        // After dispose, accessing client should create a new instance
        final newClient = connection.client;
        expect(newClient, isNotNull);
        expect(newClient, isNot(same(client)));

        connection.dispose();
      });

      test('should be safe to call dispose multiple times', () {
        final connection = DynamoConnection(region: 'us-east-1')..client;

        // Multiple dispose calls should not throw
        expect(connection.dispose, returnsNormally);
        expect(connection.dispose, returnsNormally);
        expect(connection.dispose, returnsNormally);
      });

      test('should be safe to call dispose without initializing client', () {
        final connection = DynamoConnection(region: 'us-east-1');

        // Dispose without accessing client should not throw
        expect(connection.dispose, returnsNormally);
      });
    });
  });
}
