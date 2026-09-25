/// Adapter-owned binding to a public shared model and serializer.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'shared_model.dart' as shared;
part 'binding.g.dart';

/// Marker owns only adapter code, never another aggregate or codec.
@GenerateDynamoRepository(
  aggregateType: shared.RemoteRecord,
  serializerType: shared.RemoteRecordJsonSerializer,
  generatedBaseName: 'Probe',
  tableName: 'records',
)
class ProbeBinding {}

/// Custom binding must preserve nested shared types and constant values.
@GenerateDynamoRepository(
  aggregateType: shared.RemoteRecord,
  serializerType: shared.RemoteRecordJsonSerializer,
  generatedBaseName: 'Callback',
  implements: shared.RemotePort,
  tableName: 'records',
)
class CallbackBinding {}
