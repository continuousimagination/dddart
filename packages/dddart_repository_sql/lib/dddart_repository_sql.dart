/// Base SQL repository abstractions for DDDart.
///
/// This package provides the foundational abstractions and utilities for
/// implementing SQL database repositories for DDDart aggregate roots.
/// It includes:
///
/// - SQL connection abstractions
/// - SQL dialect support for database-specific syntax
/// - Schema generation from aggregate root definitions
/// - Object-relational mapping utilities
/// - Relationship analysis and foreign key management
///
/// This package is designed to be extended by concrete implementations
/// like `dddart_repository_sqlite`, `dddart_repository_postgres`, etc.
library dddart_repository_sql;

// Annotations
export 'src/annotations/generate_sql_repository.dart';

// Connection
export 'src/connection/sql_connection.dart';

// Dialect
export 'src/dialect/sql_dialect.dart';

// Note: Exception handling uses RepositoryException from dddart package.
// See src/exceptions/sql_repository_exception.dart for mapping documentation.

// Mapping
export 'src/mapping/graph_traverser.dart';
export 'src/mapping/object_mapper.dart';

// Query
export 'src/query/join_builder.dart';
export 'src/query/query_builder.dart';

// Schema
export 'src/schema/collection_analyzer.dart';
export 'src/schema/relationship_analyzer.dart'
    hide CollectionKind; // Use CollectionKind from collection_analyzer
export 'src/schema/schema_generator.dart';
export 'src/schema/table_definition.dart';
export 'src/schema/type_mapper.dart';
