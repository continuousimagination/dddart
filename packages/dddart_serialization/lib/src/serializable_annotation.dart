import 'package:dddart_serialization/src/serialization_config.dart';

/// Annotation to mark classes as serializable.
///
/// Classes annotated with @Serializable() will have serialization code generated
/// for them by serialization packages like dddart_json.
///
/// Configuration can be provided at the annotation level as defaults,
/// and overridden at serialization time for flexibility.
class Serializable {
  /// Creates a Serializable annotation.
  const Serializable({
    this.includeNullFields = false,
    this.fieldRename = FieldRename.none,
  });

  /// Whether to include null fields in the serialized output.
  final bool includeNullFields;

  /// Field naming strategy to use during serialization.
  final FieldRename fieldRename;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Serializable &&
        other.includeNullFields == includeNullFields &&
        other.fieldRename == fieldRename;
  }

  @override
  int get hashCode => Object.hash(includeNullFields, fieldRename);

  @override
  String toString() {
    return 'Serializable(includeNullFields: $includeNullFields, fieldRename: $fieldRename)';
  }
}
