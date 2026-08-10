/// Annotation to mark aggregate roots for DynamoDB repository generation.
///
/// This annotation triggers code generation that creates a DynamoDB repository
/// implementation for the annotated aggregate root class. The generated
/// repository implements the `Repository<T>` interface from the dddart package
/// and uses the aggregate's JSON serializer from dddart_json for persistence.
///
/// ## Requirements
///
/// The annotated class must:
/// - Extend `AggregateRoot` from the dddart package
/// - Be annotated with `@Serializable()` from dddart_serialization
///
/// ## Basic Usage (Concrete Repository)
///
/// When used without a custom interface, generates a concrete repository class
/// that can be instantiated directly:
///
/// ```dart
/// part 'user.g.dart';
///
/// @Serializable()
/// @GenerateDynamoRepository(tableName: 'users')
/// class User extends AggregateRoot {
///   User({
///     required UuidValue id,
///     required this.firstName,
///     required this.lastName,
///   }) : super(id);
///
///   final String firstName;
///   final String lastName;
/// }
/// // Usage:
/// final connection = DynamoConnection(
///   region: 'us-east-1',
///   credentials: AwsClientCredentials(
///     accessKey: 'YOUR_ACCESS_KEY',
///     secretKey: 'YOUR_SECRET_KEY',
///   ),
/// );
///
/// final userRepo = UserDynamoRepository(connection);
/// await userRepo.save(user);
/// final retrieved = await userRepo.getById(user.id);
/// connection.dispose();
/// ```
///
/// ## DynamoDB Local Development
///
/// For local development, use the `DynamoConnection.local()` factory:
///
/// ```dart
/// final connection = DynamoConnection.local(port: 8000);
/// final userRepo = UserDynamoRepository(connection);
///
/// // Create table before first use
/// await userRepo.createTable();
///
/// // Now use the repository
/// await userRepo.save(user);
/// ```
///
/// ## Custom Interface (Abstract Base Repository)
///
/// When a custom interface is specified that contains methods beyond the base
/// `Repository<T>` interface, an abstract base class is generated. The
/// developer must extend this base class and implement the custom methods:
///
/// ```dart
/// part 'user.g.dart';
/// part 'user_dynamo_repository.dart';
///
/// // Define custom repository interface
/// abstract interface class UserRepository implements Repository<User> {
///   Future<User?> findByEmail(String email);
///   Future<List<User>> findByLastName(
///     String lastName, {
///     required int limit,
///   });
/// }
///
/// @Serializable()
/// @GenerateDynamoRepository(
///   tableName: 'users',
///   implements: UserRepository,
/// )
/// class User extends AggregateRoot {
///   User({
///     required UuidValue id,
///     required this.firstName,
///     required this.lastName,
///     required this.email,
///   }) : super(id);
///
///   final String firstName;
///   final String lastName;
///   final String email;
/// }
/// ```
///
/// Then extend the generated base from `user_dynamo_repository.dart`, which is
/// a handwritten part of the aggregate library:
///
/// ```dart
/// part of 'user.dart';
///
/// class UserDynamoRepository extends UserDynamoRepositoryBase {
///   UserDynamoRepository(super.connection);
///
///   @override
///   Future<User?> findByEmail(String email) async {
///     try {
///       final result = await _connection.client.query(
///         tableName: tableName,
///         indexName: 'email-index', // Requires GSI on email
///         keyConditionExpression: 'email = :email',
///         expressionAttributeValues: {
///           ':email': AttributeValue(s: email),
///         },
///         limit: 1,
///       );
///
///       if (result.items == null || result.items!.isEmpty) {
///         return null;
///       }
///
///       final json = AttributeValueConverter.attributeMapToJsonMap(
///         result.items!.first,
///       );
///       return _serializer.fromJson(json);
///     } catch (error) {
///       throw _mapDynamoException(error, 'findByEmail');
///     }
///   }
///
///   @override
///   Future<List<User>> findByLastName(
///     String lastName, {
///     required int limit,
///   }) async {
///     RangeError.checkValueInInterval(limit, 1, 100, 'limit');
///
///     try {
///       final result = await _connection.client.query(
///         tableName: tableName,
///         indexName: 'last-name-index', // Requires GSI on lastName
///         keyConditionExpression: 'lastName = :lastName',
///         expressionAttributeValues: {
///           ':lastName': AttributeValue(s: lastName),
///         },
///         limit: limit,
///       );
///
///       if (result.items == null || result.items!.isEmpty) {
///         return [];
///       }
///
///       return result.items!.map((item) {
///         final json = AttributeValueConverter.attributeMapToJsonMap(item);
///         return _serializer.fromJson(json);
///       }).toList();
///     } catch (error) {
///       throw _mapDynamoException(error, 'findByLastName');
///     }
///   }
/// }
/// ```
///
/// ## Table Naming
///
/// If [tableName] is not provided, the table name defaults to the
/// aggregate class name converted to snake_case. For example:
/// - `User` → `user`
/// - `OrderItem` → `order_item`
/// - `UserProfile` → `user_profile`
///
/// ## Table Creation Utilities
///
/// The generated repository includes helper methods for table creation:
///
/// ```dart
/// // Create the configured table with the instance method
/// await userRepo.createTable();
///
/// // Get AWS CLI command
/// final cliCommand = UserDynamoRepository.getCreateTableCommand('users');
/// print(cliCommand);
///
/// // Get CloudFormation template
/// final cfTemplate = UserDynamoRepository.getCloudFormationTemplate('users');
/// print(cfTemplate);
/// ```
///
/// ## Implementation Swapping
///
/// By defining a custom interface, you can swap repository implementations
/// for different environments:
///
/// ```dart
/// // Production: DynamoDB implementation
/// UserRepository repo = UserDynamoRepository(dynamoConnection);
///
/// // Testing: focused fake implementing the same domain-specific reads
/// UserRepository repo = FakeUserRepository();
///
/// // Development: MongoDB implementation
/// UserRepository repo = UserMongoRepository(mongoDatabase);
/// ```
class GenerateDynamoRepository {
  /// Creates a GenerateDynamoRepository annotation.
  ///
  /// [tableName] - Optional custom table name. If not provided,
  /// the aggregate class name will be converted to snake_case.
  /// For example, `UserProfile` becomes `user_profile`.
  ///
  /// [implements] - Optional custom repository interface. If provided and
  /// the interface contains custom methods beyond `Repository<T>`, an abstract
  /// base class will be generated requiring the developer to implement
  /// custom methods. If the interface only contains base `Repository<T>`
  /// methods, a concrete class will be generated.
  const GenerateDynamoRepository({
    this.tableName,
    this.implements,
  });

  /// The DynamoDB table name for this aggregate type.
  ///
  /// If null, defaults to snake_case conversion of the class name.
  /// Must follow DynamoDB table naming rules:
  /// - Between 3 and 255 characters long
  /// - Can contain only alphanumeric characters, underscores, hyphens, and dots
  /// - Cannot start with "aws." prefix (reserved)
  final String? tableName;

  /// The custom repository interface to implement.
  ///
  /// If null, generates a concrete class implementing `Repository<T>`.
  ///
  /// If provided:
  /// - Interface contains only base `Repository<T>` methods → generates
  ///   concrete class implementing the interface
  /// - Interface contains custom methods → generates abstract base class
  ///   with concrete implementations of base methods and abstract
  ///   declarations of custom methods
  ///
  /// The generated base exposes `tableName` publicly. Its underscore-prefixed
  /// members (`_connection`, `_serializer`, and `_mapDynamoException`) are Dart
  /// library-private, so a handwritten implementation can use them only when it
  /// is declared as a `part` of the aggregate library. Subclassing from another
  /// library does not provide access.
  final Type? implements;
}
