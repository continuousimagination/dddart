/// Annotation for generating SQLite repository implementations.
///
/// This annotation is used to mark aggregate root classes for which
/// a SQLite repository implementation should be generated.
///
/// Example:
/// ```dart
/// @Serializable()
/// @GenerateSqliteRepository()
/// class Order extends AggregateRoot {
///   // ...
/// }
/// ```
library;

/// Annotation to generate a SQLite repository for an aggregate root.
///
/// The annotated class must:
/// - Extend AggregateRoot
/// - Have a @Serializable annotation
///
/// Optional parameters:
/// - [tableName]: Custom table name (defaults to snake_case of class name)
/// - [implements]: Custom repository interface to implement
class GenerateSqliteRepository {
  /// Creates a repository generation annotation.
  const GenerateSqliteRepository({
    this.tableName,
    this.implements,
  });

  /// Custom table name for the aggregate root.
  ///
  /// If not specified, the class name will be converted to snake_case.
  final String? tableName;

  /// Custom repository interface to implement.
  ///
  /// If specified, the generator will create an abstract base class
  /// that implements this interface, allowing you to add custom methods.
  final Type? implements;
}
