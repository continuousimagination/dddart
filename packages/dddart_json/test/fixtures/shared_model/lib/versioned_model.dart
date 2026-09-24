/// Shared versioned fixture; only this library owns its generated codec.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'versioned_model.g.dart';

/// Portable aggregate shared by separately generated adapter bindings.
@Serializable()
class VersionedRecord extends VersionedAggregateRoot {
  /// Creates explicit persisted or proposed fixture state.
  VersionedRecord({
    required this.text,
    required this.tags,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.revision,
  });

  /// Synthetic content.
  final String text;

  /// Mutable collection exercises deep snapshot independence.
  final List<String> tags;
}

const _defaultPageSize = 20;

/// Generic redeclarations must retain the exact conditional CRUD contract.
abstract interface class VersionedRepositoryPort<
  T extends VersionedAggregateRoot
>
    implements ConditionalRepository<T> {
  @override
  Future<T> getById(UuidValue key);

  @override
  Future<T> save(T value, {required WritePrecondition precondition});

  @override
  Future<void> deleteById(
    UuidValue key, {
    required WritePrecondition precondition,
  });
}

/// Custom contract exercises prefixed nested types and inherited
/// conditional CRUD.
abstract interface class VersionedPort
    implements VersionedRepositoryPort<VersionedRecord> {
  /// Returns a model callback through the generated abstract adapter base.
  Future<VersionedRecord Function(VersionedRecord)> callback({
    int take = _defaultPageSize,
  });
}
