/// RESTful CRUD API framework for DDDart
///
/// Provides a declarative, type-safe way to expose aggregate roots through
/// RESTful HTTP endpoints with support for content negotiation, custom query
/// handlers, and extensible error handling.
library dddart_rest;

export 'src/crud_resource.dart';
export 'src/error_mapper.dart';
export 'src/exceptions.dart';
export 'src/http_server.dart';
export 'src/query_handler.dart';
export 'src/response_builder.dart';
