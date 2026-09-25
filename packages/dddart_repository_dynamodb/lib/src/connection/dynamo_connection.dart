import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:http/http.dart' as http;

/// Manages DynamoDB client lifecycle and configuration.
///
/// Provides connection lifecycle management and DynamoDB client access.
/// Supports AWS credentials configuration and custom endpoints for
/// DynamoDB Local or LocalStack.
///
/// Example with AWS credentials:
/// ```dart
/// final connection = DynamoConnection(
///   region: 'us-east-1',
///   credentials: AwsClientCredentials(
///     accessKey: 'YOUR_ACCESS_KEY',
///     secretKey: 'YOUR_SECRET_KEY',
///   ),
/// );
/// final client = connection.client;
/// // Use client...
/// connection.dispose();
/// ```
///
/// Example with DynamoDB Local:
/// ```dart
/// final connection = DynamoConnection.local();
/// final client = connection.client;
/// // Use client...
/// connection.dispose();
/// ```
///
/// Example with custom endpoint:
/// ```dart
/// final connection = DynamoConnection(
///   region: 'us-east-1',
///   endpoint: 'http://localhost:8000',
/// );
/// ```
class DynamoConnection {
  /// Creates a [DynamoConnection] with the specified configuration.
  ///
  /// [region] - AWS region (e.g., 'us-east-1', 'eu-west-1')
  /// [credentials] - Optional AWS credentials. If not provided, uses the
  ///                 SDK environment/shared-credentials-file resolver
  /// [endpoint] - Optional custom endpoint URL for DynamoDB Local or LocalStack
  DynamoConnection({
    required this.region,
    this.credentials,
    this.endpoint,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// Creates a [DynamoConnection] configured for DynamoDB Local.
  ///
  /// DynamoDB Local is a downloadable version of DynamoDB for development
  /// and testing. By default, it runs on port 8000.
  ///
  /// [port] - Port number for DynamoDB Local (default: 8000)
  ///
  /// Example:
  /// ```dart
  /// final connection = DynamoConnection.local();
  /// // or with custom port
  /// final connection = DynamoConnection.local(port: 8001);
  /// ```
  factory DynamoConnection.local({int port = 8000}) {
    return DynamoConnection(
      region: 'us-east-1',
      credentials: AwsClientCredentials(accessKey: 'dummy', secretKey: 'dummy'),
      endpoint: 'http://localhost:$port',
    );
  }

  /// AWS region for DynamoDB operations.
  final String region;

  /// AWS credentials for authentication.
  ///
  /// If null, the AWS SDK will use the default credential provider chain
  /// (environment variables or the shared credentials file).
  /// Supply scoped temporary credentials explicitly in managed runtimes.
  final AwsClientCredentials? credentials;

  /// Custom endpoint URL for DynamoDB Local or LocalStack.
  ///
  /// If null, uses the standard AWS DynamoDB endpoint for the region.
  final String? endpoint;

  final http.Client? _httpClient;

  DynamoDB? _client;

  /// Gets the DynamoDB client instance.
  ///
  /// The client is lazily initialized on first access. Once created,
  /// the same client instance is returned on subsequent calls.
  ///
  /// After [dispose], accessing this getter lazily creates a new SDK client.
  DynamoDB get client {
    _client ??= DynamoDB(
      region: region,
      credentials: credentials,
      endpointUrl: endpoint,
      client: _httpClient,
    );
    return _client!;
  }

  /// Disposes of the DynamoDB client resources.
  ///
  /// A subsequently accessed [client] is recreated lazily. Injected HTTP clients
  /// are borrowed and are never closed by this connection; their caller owns
  /// disposal. The SDK closes an HTTP client it created internally.
  ///
  /// It's safe to call dispose multiple times.
  void dispose() {
    _client?.close();
    _client = null;
  }
}
