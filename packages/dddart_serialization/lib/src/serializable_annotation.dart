import 'serialization_config.dart';

/// Annotation to mark classes as serializable.
/// 
/// Classes annotated with @Serializable() will have serialization code generated
/// for them by serialization packages like dddart_json.
/// 
/// Configuration can be provided at the annotation level as defaults,
/// and overridden at serialization time for flexibility.
/// 
/// Example:
/// ```dart
/// import 'package:dddart/dddart.dart';
/// import 'package:dddart_serialization/dddart_serialization.dart';
/// 
/// @Serializable()
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
/// }
/// 
/// // Use different configurations at serialization time
/// final serializer = UserJsonSerializer();
/// 
/// // Default camelCase
/// final camelJson = serializer.toJson(user);
/// // {"firstName": "John", "lastName": "Doe"}
/// 
/// // Snake case for API
/// final snakeConfig = SerializationConfig(fieldRename: FieldRename.snake);
/// final snakeJson = serializer.toJson(user, snakeConfig);
/// // {"first_name": "John", "last_name": "Doe"}
/// ```
class Serializable {
  /// Whether to include null fields in the serialized output.
  final bool includeNullFields;
  
  /// Field naming strategy to use during serialization.
  final FieldRename fieldRename;
  
  /// Creates a Serializable annotation.
  const Serializable({
    this.includeNullFields = false,
    this.fieldRename = FieldRename.none,
  });

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