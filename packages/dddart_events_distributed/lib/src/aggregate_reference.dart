import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// A stable aggregate contract kind and its concrete scoped identity.
///
/// For example, kind "game" and a particular GameId identify one logical event
/// stream. The kind is explicit and survives Dart class renames. Physical
/// transport channel IDs are separate, replaceable infrastructure metadata.
final class AggregateReference<I extends Identity> extends Value {
  /// Creates a reference with a nonempty stable contract [kind].
  AggregateReference({required this.kind, required this.id}) {
    if (kind.isEmpty || kind.trim() != kind) {
      throw ArgumentError.value(
        kind,
        'kind',
        'Expected a stable aggregate kind',
      );
    }
  }

  /// Restores a reference with the shared explicit identity codecs.
  factory AggregateReference.fromJson(
    Map<String, dynamic> json, {
    required IdentityCodecRegistry identityCodecs,
  }) {
    final identity = identityCodecs.fromTaggedJson(json['id']);
    if (identity is! I || json['kind'] is! String) {
      throw const DeserializationException('Invalid aggregate reference');
    }
    return AggregateReference<I>(kind: json['kind'] as String, id: identity);
  }

  /// Stable aggregate contract discriminator, independent of runtimeType.
  final String kind;

  /// Aggregate identity, including any application-defined scope.
  final I id;

  /// Collision-free canonical logical key; backend limits remain adapter-owned.
  String toKey(IdentityCodecRegistry identityCodecs) {
    final tagged = identityCodecs.toTaggedKey(id);
    String component(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    return [kind, tagged['type']!, tagged['key']!].map(component).join('.');
  }

  /// Public event-reference representation, not aggregate internals.
  Map<String, dynamic> toJson(IdentityCodecRegistry identityCodecs) => {
        'kind': kind,
        'id': identityCodecs.toTaggedJson(id),
      };

  @override
  List<Object?> get props => [kind, id];

  /// Logical equality also holds when decoding through the Identity boundary.
  @override
  bool operator ==(Object other) =>
      other is AggregateReference<Identity> &&
      kind == other.kind &&
      id == other.id;

  @override
  int get hashCode => Object.hash(kind, id);
}
