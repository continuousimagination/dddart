/// RESTful CRUD API framework for DDDart
///
/// Provides a declarative, type-safe way to expose aggregate roots through
/// RESTful HTTP endpoints with support for content negotiation, custom query
/// handlers, and extensible error handling.
library dddart_rest;

export 'src/auth_endpoints.dart';
export 'src/auth_error_mapper.dart';
export 'src/auth_handler.dart';
export 'src/auth_result.dart';
export 'src/crud_resource.dart';
export 'src/device_code.dart';
export 'src/error_mapper.dart';
export 'src/exceptions.dart';
export 'src/http_server.dart';
export 'src/jwt_auth_handler.dart';
export 'src/jwt_serializable_annotation.dart';
export 'src/oauth_jwt_auth_handler.dart';
export 'src/query_handler.dart';
export 'src/refresh_token.dart';
export 'src/response_builder.dart';
export 'src/security_utils.dart';
export 'src/standard_claims.dart';
export 'src/tokens.dart';
