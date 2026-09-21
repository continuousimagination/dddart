/// Shared model owns its serializer; adapter bindings live in another library.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
part 'shared_model.g.dart';

/// Shared synthetic aggregate.
@Serializable()
class RemoteRecord extends AggregateRoot {
  /// Creates a complete model.
  RemoteRecord({
    required this.text,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Synthetic stored text.
  final String text;
}

const _defaultPageSize = 20;

/// Public constant intentionally contains interpolation-like text.
const defaultLabel = r'$label';

/// Public enum used in adapter-owned generated default parameters.
enum FilterMode {
  /// Selects all fixture records.
  all,
}

/// Shared custom contract exercises nested callback and constant rendering.
abstract interface class RemotePort implements Repository<RemoteRecord> {
  /// Returns a portable model callback with a library-private default.
  Future<RemoteRecord Function(RemoteRecord)> callback({
    int take = _defaultPageSize,
    String label = defaultLabel,
    FilterMode mode = FilterMode.all,
  });
}
