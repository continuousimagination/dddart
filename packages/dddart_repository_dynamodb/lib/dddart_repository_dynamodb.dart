/// DynamoDB repository implementation for DDDart aggregate roots.
///
/// This library provides code-generated DynamoDB repository implementations
/// that leverage existing JSON serialization from dddart_json and the AWS SDK
/// for Dart for DynamoDB connectivity.
///
/// ## Features
///
/// - Code generation for repository implementations
/// - Reuse of dddart_json serializers
/// - Support for custom repository interfaces
/// - AWS credential management
/// - DynamoDB Local support
/// - Exception mapping to standard RepositoryException types
///
/// ## Usage
///
/// ```dart
/// import 'package:dddart/dddart.dart';
/// import 'package:dddart_serialization/dddart_serialization.dart';
/// import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
///
/// part 'user.g.dart';
/// part 'user.dynamo_repository.g.dart';
///
/// @Serializable()
/// @GenerateDynamoRepository(tableName: 'users')
/// class User extends AggregateRoot {
///   User({
///     required UuidValue id,
///     required this.email,
///     required this.name,
///   }) : super(id);
///
///   final String email;
///   final String name;
/// }
///
/// void main() async {
///   final connection = DynamoConnection(region: 'us-east-1');
///   final userRepo = UserDynamoRepository(connection);
///
///   final user = User(
///     id: UuidValue.generate(),
///     email: 'john@example.com',
///     name: 'John Doe',
///   );
///
///   await userRepo.save(user);
///   final retrieved = await userRepo.getById(user.id);
///
///   connection.dispose();
/// }
/// ```
library dddart_repository_dynamodb;

export 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';

export 'src/annotations/generate_dynamo_repository.dart';
export 'src/connection/dynamo_connection.dart';
export 'src/exceptions/dynamo_repository_exception.dart';
export 'src/utils/attribute_value_converter.dart';
