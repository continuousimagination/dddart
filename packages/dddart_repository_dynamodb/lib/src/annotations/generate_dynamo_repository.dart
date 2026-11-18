/// Generates a DynamoDB repository for a serializable aggregate with a concrete identity.
///
/// Add this annotation and `@Serializable()` to the aggregate that owns the
/// generated part. Set [tableName] to control where instances are stored.
/// For example, the default name for `UserProfile` is `user_profile`.
///
/// Supply a repository interface in [implements] to declare application queries.
/// If it adds methods beyond CRUD, the generator provides an abstract base.
/// Extend it in the aggregate's library to implement those methods. See the
/// [custom query example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_dynamodb/example/custom_interface_example.dart).
class GenerateDynamoRepository {
  /// Creates a GenerateDynamoRepository annotation.
  ///
  /// [tableName] - Optional custom table name. If not provided,
  /// the aggregate class name will be converted to snake_case.
  /// For example, `UserProfile` becomes `user_profile`.
  ///
  /// [implements] - Optional custom repository interface. If provided and
  /// the interface contains custom methods beyond `Repository<T, I>`, an abstract
  /// base class will be generated requiring the developer to implement
  /// custom methods. If the interface only contains base `Repository<T, I>`
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
  /// If null, generates a concrete class implementing `Repository<T, I>`.
  ///
  /// If provided:
  /// - Interface contains only base `Repository<T, I>` methods → generates
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
