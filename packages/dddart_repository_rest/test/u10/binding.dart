/// Adapter-owned binding to a public shared model and serializer.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'shared_model.dart' as shared;
part 'binding.g.dart';

/// Marker owns only adapter code, never another aggregate or codec.
@GenerateRestRepository(
  aggregateType: shared.RemoteRecord,
  serializerType: shared.RemoteRecordJsonSerializer,
  generatedBaseName: 'Probe',
  resourcePath: 'records',
)
class ProbeBinding {}

/// Custom binding must preserve nested shared types and constant values.
@GenerateRestRepository(
  aggregateType: shared.RemoteRecord,
  serializerType: shared.RemoteRecordJsonSerializer,
  generatedBaseName: 'Callback',
  implements: shared.RemotePort,
  resourcePath: 'records',
)
class CallbackBinding {}
