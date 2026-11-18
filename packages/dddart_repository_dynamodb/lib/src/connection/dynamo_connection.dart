import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';

/// Manages DynamoDB client lifecycle and configuration.
///
/// Provides connection lifecycle management and DynamoDB client access.
/// Supports AWS credentials configuration and custom endpoints for
/// DynamoDB Local or LocalStack.
class DynamoConnection {
  /// Creates a [DynamoConnection] with the specified configuration.
  ///
  /// [region] - AWS region (e.g., 'us-east-1', 'eu-west-1')
  /// [credentials] - Optional AWS credentials. If not provided, uses the
  ///                 SDK's environment/shared-file credential resolution
  /// [endpoint] - Optional custom endpoint URL for DynamoDB Local or LocalStack
  DynamoConnection({
    required this.region,
    this.credentials,
    this.endpoint,
  });

  /// Creates a [DynamoConnection] configured for DynamoDB Local.
  ///
  /// DynamoDB Local is a downloadable version of DynamoDB for development
  /// and testing. By default, it runs on port 8000.
  ///
  /// [port] - Port number for DynamoDB Local (default: 8000)
  factory DynamoConnection.local({int port = 8000}) {
    return DynamoConnection(
      region: 'us-east-1',
      credentials: AwsClientCredentials(
        accessKey: 'dummy',
        secretKey: 'dummy',
      ),
      endpoint: 'http://localhost:$port',
    );
  }

  /// AWS region for DynamoDB operations.
  final String region;

  /// AWS credentials for authentication.
  ///
  /// If null, the SDK uses its credential resolver
  /// (environment variables and shared credential profiles in the pinned SDK).
  /// Automatic EC2/ECS role discovery is not supplied by this wrapper.
  final AwsClientCredentials? credentials;

  /// Custom endpoint URL for DynamoDB Local or LocalStack.
  ///
  /// If null, uses the standard AWS DynamoDB endpoint for the region.
  final String? endpoint;

  DynamoDB? _client;

  /// Gets the DynamoDB client instance.
  ///
  /// The client is lazily initialized on first access. Once created,
  /// the same client instance is returned on subsequent calls.
  ///
  /// Access after [dispose] lazily creates a new client.
  DynamoDB get client {
    _client ??= DynamoDB(
      region: region,
      credentials: credentials,
      endpointUrl: endpoint,
    );
    return _client!;
  }

  /// Disposes of the DynamoDB client resources.
  ///
  /// A subsequent [client] access creates a new client. This connection object
  /// is reusable; disposing it is not a permanent closed-state guard.
  ///
  /// It's safe to call dispose multiple times.
  void dispose() {
    _client?.close();
    _client = null;
  }
}
