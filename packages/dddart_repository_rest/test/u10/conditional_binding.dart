/// Adapter owns repository code; shared package owns model and codec.
library;

import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart' as shared;
part 'conditional_binding.g.dart';

@GenerateRestRepository(
  aggregateType: shared.VersionedRecord,
  serializerType: shared.VersionedRecordJsonSerializer,
  generatedBaseName: 'ConditionalProbe',
  conditionalWrites: true,
  resourcePath: '/VersionedRecord',
)
class ConditionalBinding {}

@GenerateRestRepository(
  aggregateType: shared.VersionedRecord,
  serializerType: shared.VersionedRecordJsonSerializer,
  generatedBaseName: 'CustomConditionalProbe',
  conditionalWrites: true,
  implements: shared.VersionedPort,
  resourcePath: '/VersionedRecord',
)
class CustomConditionalBinding {}
