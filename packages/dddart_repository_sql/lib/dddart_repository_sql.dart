/// dddart_repository_sql: supported DDDart application and extension APIs.
///
/// Complete setup and runnable examples:
/// https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/sqlite/README.md
///
/// Supported imports and extension contracts:
/// https://github.com/continuousimagination/dddart/blob/main/docs/PUBLIC_API.md
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
