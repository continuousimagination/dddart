/// dddart_repository_dynamodb: supported DDDart application and extension APIs.
///
/// Complete setup and runnable examples:
/// https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/dynamodb/README.md
///
/// Supported imports and extension contracts:
/// https://github.com/continuousimagination/dddart/blob/main/docs/PUBLIC_API.md
library dddart_repository_dynamodb;

export 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';

export 'src/annotations/generate_dynamo_repository.dart';
export 'src/connection/dynamo_connection.dart';
export 'src/exceptions/dynamo_repository_exception.dart';
export 'src/utils/attribute_value_converter.dart';
export 'src/utils/identity_key.dart';
