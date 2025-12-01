/// MySQL database repository implementation for DDDart aggregate roots.
///
/// This package provides MySQL-specific implementations of the repository
/// pattern for DDDart aggregate roots, with automatic code generation support.
///
/// Key features:
/// - MySQL-specific connection management with connection pooling
/// - Automatic schema generation with InnoDB and utf8mb4 support
/// - Value object embedding with prefixed columns
/// - Transaction support with nested transaction handling
/// - Comprehensive error mapping to RepositoryException types
/// - Custom repository interface support
///
/// Example usage:
/// ```dart
/// @Serializable()
/// @GenerateMysqlRepository(tableName: 'orders')
/// class Order extends AggregateRoot {
///   // Your domain model
/// }
///
/// // Generated repository will be available after running build_runner
/// final connection = MysqlConnection(
///   host: 'localhost',
///   port: 3306,
///   database: 'myapp',
///   user: 'user',
///   password: 'password',
/// );
///
/// await connection.open();
/// final repository = OrderMysqlRepository(connection);
/// await repository.createTables();
/// ```
library dddart_repository_mysql;

export 'src/annotations/generate_mysql_repository.dart';
export 'src/connection/mysql_connection.dart';
export 'src/dialect/mysql_dialect.dart';
