import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'identity_models.g.dart';

/// Externally assigned case-sensitive issue identifier.
class NativeId extends Identity {
  /// Keeps the remote identifier exactly as supplied.
  const NativeId(this.value);

  /// Native opaque value.
  final String value;
  @override
  List<Object?> get props => [value];
}

/// Native identity codec; empty keys are invalid.
class NativeIdCodec implements IdentityCodec<NativeId> {
  /// Creates a native codec.
  const NativeIdCodec();
  @override
  String toJson(NativeId identity) => identity.value;
  @override
  NativeId fromJson(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Expected nonempty native ID');
    }
    return NativeId(value);
  }

  @override
  String toKey(NativeId identity) => identity.value;
  @override
  NativeId fromKey(String value) => fromJson(value);
}

/// Repository-scoped issue number.
class ScopedId extends Identity {
  /// Creates a scoped identity.
  const ScopedId(this.repository, this.number);

  /// Full case-sensitive repository identifier.
  final String repository;

  /// Repository-local issue number.
  final int number;
  @override
  List<Object?> get props => [repository, number];
}

/// Structural JSON and an unambiguous canonical tuple key.
class ScopedIdCodec implements IdentityCodec<ScopedId> {
  /// Creates a scoped codec.
  const ScopedIdCodec();
  @override
  Map<String, Object> toJson(ScopedId identity) => {
        'repository': identity.repository,
        'number': identity.number,
      };
  @override
  ScopedId fromJson(Object? value) {
    if (value is! Map ||
        value['repository'] is! String ||
        (value['repository'] as String).isEmpty ||
        value['number'] is! int ||
        (value['number'] as int) <= 0) {
      throw const FormatException('Expected scoped ID');
    }
    return ScopedId(value['repository'] as String, value['number'] as int);
  }

  @override
  String toKey(ScopedId identity) =>
      jsonEncode([identity.repository, identity.number]);
  @override
  ScopedId fromKey(String value) {
    final tuple = jsonDecode(value) as List<dynamic>;
    if (tuple.length != 2) throw const FormatException('Expected pair');
    return fromJson({'repository': tuple[0], 'number': tuple[1]});
  }
}

/// Test-local codecs, never global state.
IdentityCodecRegistry issueIdentityCodecs() => IdentityCodecRegistry()
  ..register<NativeId>('native-issue', const NativeIdCodec())
  ..register<ScopedId>('scoped-issue', const ScopedIdCodec());

@Serializable()
@DistributedEvent('issue.native.opened.v1')
class NativeIssueOpened extends DomainEvent<NativeId> {
  NativeIssueOpened({
    required super.aggregateId,
    required this.title,
    super.eventId,
    super.occurredAt,
    super.context,
  });
  final String title;
}

@Serializable()
@DistributedEvent('issue.scoped.opened.v1')
class ScopedIssueOpened extends DomainEvent<ScopedId> {
  ScopedIssueOpened({
    required super.aggregateId,
    required this.title,
    super.eventId,
    super.occurredAt,
    super.context,
  });
  final String title;
}

@Serializable()
@DistributedEvent('uuid.changed.v1')
class StockChanged extends DomainEvent<UuidValue> {
  StockChanged({
    required super.aggregateId,
    super.eventId,
    super.occurredAt,
    super.context,
  });
}
