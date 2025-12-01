/// SQLite repository implementation for DDDart aggregate roots.
///
/// This package provides code generation for SQLite repositories that persist
/// DDDart aggregate roots to SQLite databases with full normalization.
///
/// Features:
/// - Automatic schema generation from aggregate roots
/// - Multi-table persistence with foreign key relationships
/// - Value object embedding with prefixed columns
/// - Transaction support for atomic operations
/// - CRUD operations with type safety
/// - Custom repository interface support
///
/// Example:
/// ```dart
/// @Serializable()
/// @GenerateSqliteRepository()
/// class Order extends AggregateRoot {
///   Order({required UuidValue id, required this.items}) : super(id);
///   final List<OrderItem> items;
/// }
/// ```
library dddart_repository_sqlite;

export 'src/annotations/generate_sqlite_repository.dart';
export 'src/connection/sqlite_connection.dart';
export 'src/dialect/sqlite_dialect.dart';
export 'src/generators/sqlite_repository_generator.dart';
