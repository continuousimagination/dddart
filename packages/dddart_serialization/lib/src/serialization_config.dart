/// Configuration options for serialization.
class SerializationConfig {
  /// Field naming strategy to use during serialization.
  final FieldRename fieldRename;
  
  /// Whether to include null fields in the serialized output.
  final bool includeNullFields;
  
  /// Creates a serialization configuration.
  const SerializationConfig({
    this.fieldRename = FieldRename.none,
    this.includeNullFields = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SerializationConfig &&
        other.fieldRename == fieldRename &&
        other.includeNullFields == includeNullFields;
  }

  @override
  int get hashCode => Object.hash(fieldRename, includeNullFields);

  @override
  String toString() {
    return 'SerializationConfig(fieldRename: $fieldRename, includeNullFields: $includeNullFields)';
  }
}

/// Field naming strategies for serialization.
enum FieldRename {
  /// Keep field names as-is.
  none,
  
  /// Convert field names to snake_case.
  snake,
  
  /// Convert field names to kebab-case.
  kebab,
}