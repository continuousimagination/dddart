/// Annotation to mark aggregate roots for DynamoDB repository generation.
///
/// This annotation triggers code generation that creates a DynamoDB repository
/// implementation for the annotated aggregate root class. The generated
/// repository implements the `Repository<T, UuidValue>` interface from the dddart package
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
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/README.md).
///
/// ## DynamoDB Local Development
///
/// For local development, use the `DynamoConnection.local()` factory:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/README.md).
///
/// ## Custom Interface (Abstract Base Repository)
///
/// When a custom interface is specified that contains methods beyond the base
/// `Repository<T, UuidValue>` interface, an abstract base class is generated. The
/// developer must extend this base class and implement the custom methods:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/README.md).
///
/// Then extend the generated base from `user_dynamo_repository.dart`, which is
/// a handwritten part of the aggregate library:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/README.md).
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
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/README.md).
///
/// ## Implementation Swapping
///
/// By defining a custom interface, you can swap repository implementations
/// for different environments:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/README.md).
class GenerateDynamoRepository {
  /// Creates a GenerateDynamoRepository annotation.
  ///
  /// [tableName] - Optional custom table name. If not provided,
  /// the aggregate class name will be converted to snake_case.
  /// For example, `UserProfile` becomes `user_profile`.
  ///
  /// [implements] - Optional custom repository interface. If provided and
  /// the interface contains custom methods beyond `Repository<T, UuidValue>`, an abstract
  /// base class will be generated requiring the developer to implement
  /// custom methods. If the interface only contains base `Repository<T, UuidValue>`
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
  /// If null, generates a concrete class implementing `Repository<T, UuidValue>`.
  ///
  /// If provided:
  /// - Interface contains only base `Repository<T, UuidValue>` methods → generates
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
