/// Adapter owns repository code; shared package owns model and codec.
library;

import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart' as shared;
part 'conditional_binding.g.dart';

@GenerateDynamoRepository(
  aggregateType: shared.VersionedRecord,
  serializerType: shared.VersionedRecordJsonSerializer,
  generatedBaseName: 'ConditionalProbe',
  conditionalWrites: true,
  tableName: 'VersionedRecord',
)
class ConditionalBinding {}

@GenerateDynamoRepository(
  aggregateType: shared.VersionedRecord,
  serializerType: shared.VersionedRecordJsonSerializer,
  generatedBaseName: 'CustomConditionalProbe',
  conditionalWrites: true,
  implements: shared.VersionedPort,
  tableName: 'VersionedRecord',
)
class CustomConditionalBinding {}
