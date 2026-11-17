/// dddart_repository_mongodb: supported DDDart application and extension APIs.
///
/// Complete setup and runnable examples:
/// https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/mongodb/README.md
///
/// Supported imports and extension contracts:
/// https://github.com/continuousimagination/dddart/blob/main/docs/PUBLIC_API.md
library dddart_repository_mongodb;

// Annotations
export 'src/annotations/generate_mongo_repository.dart';

// Connection management
export 'src/connection/mongo_connection.dart';

// Exceptions
export 'src/exceptions/mongo_repository_exception.dart';
export 'src/identity_key.dart';
export 'src/write_result.dart';
