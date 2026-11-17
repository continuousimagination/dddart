/// Base SQL repository abstractions for DDDart.
///
/// This package provides the foundational abstractions and utilities for
/// implementing SQL database repositories for DDDart aggregate roots.
/// It includes:
///
/// - SQL connection abstractions
/// - SQL dialect support for database-specific syntax
/// - Runtime schema values for dialect and query extensions
/// - Object-relational mapping utilities
/// - Foreign key management
///
/// Build-time schema analysis is available from `generator.dart`.
///
/// This package is designed to be extended by concrete implementations
/// like `dddart_repository_sqlite`, `dddart_repository_postgres`, etc.
library dddart_repository_sql;

// Annotations
export 'src/annotations/generate_sql_repository.dart';

// Connection
export 'src/connection/sql_connection.dart';
export 'src/connection/sql_connection_coordinator.dart';

// Dialect
export 'src/dialect/sql_dialect.dart';

// Note: Exception handling uses RepositoryException from dddart package.
// See src/exceptions/sql_repository_exception.dart for mapping documentation.

// Mapping
export 'src/mapping/object_mapper.dart';

// Query
export 'src/query/join_builder.dart';
export 'src/query/query_builder.dart';

// Runtime schema values used by dialect and query extension APIs.
export 'src/schema/table_definition.dart';
