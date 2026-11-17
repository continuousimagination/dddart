/// Annotation to mark aggregate roots for MongoDB repository generation.
///
/// This annotation triggers code generation that creates a MongoDB repository
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
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_mongodb/README.md).
///
/// ## Custom Interface (Abstract Base Repository)
///
/// When a custom interface is specified that contains methods beyond the base
/// `Repository<T, UuidValue>` interface, an abstract base class is generated. The
/// developer must extend this base class and implement the custom methods:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_mongodb/README.md).
///
/// ## Collection Naming
///
/// If [collectionName] is not provided, the collection name defaults to the
/// aggregate class name converted to snake_case. For example:
/// - `User` → `users`
/// - `OrderItem` → `order_items`
/// - `UserProfile` → `user_profiles`
///
/// ## Implementation Swapping
///
/// By defining a custom interface, you can swap repository implementations
/// for different environments:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_repository_mongodb/README.md).
class GenerateMongoRepository {
  /// Creates a GenerateMongoRepository annotation.
  ///
  /// [collectionName] - Optional custom collection name. If not provided,
  /// the aggregate class name will be converted to snake_case.
  /// For example, `UserProfile` becomes `user_profiles`.
  ///
  /// [implements] - Optional custom repository interface. If provided and
  /// the interface contains custom methods beyond `Repository<T, UuidValue>`, an abstract
  /// base class will be generated requiring the developer to implement
  /// custom methods. If the interface only contains base `Repository<T, UuidValue>`
  /// methods, a concrete class will be generated.
  const GenerateMongoRepository({
    this.collectionName,
    this.implements,
  });

  /// The MongoDB collection name for this aggregate type.
  ///
  /// If null, defaults to snake_case conversion of the class name.
  /// Must follow MongoDB collection naming rules:
  /// - Cannot be empty
  /// - Cannot contain null characters
  /// - Cannot start with "system."
  final String? collectionName;

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
  final Type? implements;
}
