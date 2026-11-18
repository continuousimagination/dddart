import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

class ExternalEventId extends Identity {
  const ExternalEventId(this.source, this.value);
  final String source;
  final String value;
  @override
  List<Object?> get props => [source, value];
}

class ExternalEventIdCodec implements IdentityCodec<ExternalEventId> {
  const ExternalEventIdCodec();
  @override
  Object toJson(ExternalEventId id) => [id.source, id.value];
  @override
  ExternalEventId fromJson(Object? value) {
    final parts = value! as List;
    if (parts.length != 2)
      throw const FormatException('Expected source and ID');
    return ExternalEventId(parts[0] as String, parts[1] as String);
  }

  @override
  String toKey(ExternalEventId id) => jsonEncode(toJson(id));
  @override
  ExternalEventId fromKey(String value) => fromJson(jsonDecode(value));
}

IdentityCodecRegistry eventIdentityCodecs() => IdentityCodecRegistry()
  ..register<ExternalEventId>('external-event', const ExternalEventIdCodec());
