/// Code generator for JWT claims serialization.
library;

// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_rest/src/jwt_serializable_annotation.dart';
import 'package:source_gen/source_gen.dart';

/// Builder function for the JWT claims generator.
Builder jwtClaimsBuilder(BuilderOptions options) =>
    SharedPartBuilder([JwtClaimsGenerator()], 'jwt_claims');

/// Generator for JWT claims serialization extension methods.
///
/// Generates extension methods on JwtAuthHandler<TClaims> that provide
/// parseClaimsFromJson and claimsToJson methods for the annotated claims class.
class JwtClaimsGenerator extends GeneratorForAnnotation<JwtSerializable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @JwtSerializable.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Extract field information
    final fields = _extractFields(classElement);

    // Generate extension methods
    return _generateExtensionMethods(className, fields);
  }

  /// Extracts field information from a class element.
  List<FieldInfo> _extractFields(ClassElement classElement) {
    final fields = <FieldInfo>[];

    // Get all fields from the class
    for (final field in classElement.fields) {
      // Skip static fields and synthetic fields
      if (field.isStatic || field.isSynthetic) continue;

      final fieldType = field.type;
      final isNullable =
          fieldType.nullabilitySuffix == NullabilitySuffix.question;

      fields.add(
        FieldInfo(
          name: field.name,
          type: fieldType,
          isNullable: isNullable,
        ),
      );
    }

    return fields;
  }

  /// Generates extension methods for JWT claims serialization.
  String _generateExtensionMethods(String className, List<FieldInfo> fields) {
    final buffer = StringBuffer();

    // Generate extension on JwtAuthHandler<TClaims>
    buffer.writeln(
      '/// Extension methods for JWT claims serialization of $className',
    );
    buffer.writeln(
      'extension JwtAuthHandler${className}Extension on JwtAuthHandler<$className, dynamic> {',
    );
    buffer.writeln();

    // Generate parseClaimsFromJson method
    buffer.writeln('  /// Parses $className from JWT payload JSON');
    buffer.writeln(
      '  $className parseClaimsFromJson(Map<String, dynamic> json) {',
    );
    buffer.writeln('    return $className(');

    // Sort fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final field in sortedFields) {
      final fieldName = field.name;
      final deserialization = _generateFieldDeserialization(field);
      buffer.writeln('      $fieldName: $deserialization,');
    }

    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate claimsToJson method
    buffer.writeln('  /// Converts $className to JWT payload JSON');
    buffer.writeln(
      '  Map<String, dynamic> claimsToJson($className claims) {',
    );
    buffer.writeln('    return {');

    for (final field in sortedFields) {
      final fieldName = field.name;
      final serialization = _generateFieldSerialization(field);

      if (field.isNullable) {
        buffer.writeln(
          "      if (claims.$fieldName != null) '$fieldName': $serialization,",
        );
      } else {
        buffer.writeln("      '$fieldName': $serialization,");
      }
    }

    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates serialization code for a field.
  String _generateFieldSerialization(FieldInfo field) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final fieldRef = 'claims.${field.name}';

    // Handle nullable types
    if (field.isNullable) {
      // Handle nullable collections
      if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
        return '$fieldRef != null ? ${_generateCollectionSerialization(field, fieldRef)} : null';
      }

      if (typeName.startsWith('Map<')) {
        return '$fieldRef != null ? ${_generateMapSerialization(field, fieldRef)} : null';
      }

      // Default nullable primitive types
      return fieldRef;
    }

    // Handle non-nullable collections
    if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
      return _generateCollectionSerialization(field, fieldRef);
    }

    if (typeName.startsWith('Map<')) {
      return _generateMapSerialization(field, fieldRef);
    }

    // Default: primitive types
    return fieldRef;
  }

  /// Generates deserialization code for a field.
  String _generateFieldDeserialization(FieldInfo field) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final fieldName = field.name;

    // Handle nullable types
    if (field.isNullable) {
      // Handle nullable collections
      if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
        return "json['$fieldName'] != null ? ${_generateCollectionDeserialization(field, fieldName)} : null";
      }

      if (typeName.startsWith('Map<')) {
        return "json['$fieldName'] != null ? ${_generateMapDeserialization(field, fieldName)} : null";
      }

      // Handle nullable double with int-to-double conversion
      if (typeName == 'double') {
        return "json['$fieldName'] != null ? (json['$fieldName'] is int ? (json['$fieldName'] as int).toDouble() : json['$fieldName'] as double) : null";
      }

      // Default nullable primitive types
      return "json['$fieldName'] as $typeName?";
    }

    // Handle non-nullable collections
    if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
      return _generateCollectionDeserialization(field, fieldName);
    }

    if (typeName.startsWith('Map<')) {
      return _generateMapDeserialization(field, fieldName);
    }

    // Handle double with int-to-double conversion
    if (typeName == 'double') {
      return "(json['$fieldName'] is int ? (json['$fieldName'] as int).toDouble() : json['$fieldName'] as double)";
    }

    // Default: primitive types with casting
    return "json['$fieldName'] as $typeName";
  }

  /// Generates serialization code for collections (List, Set).
  String _generateCollectionSerialization(FieldInfo field, String fieldRef) {
    final typeName = field.type.getDisplayString(withNullability: false);

    // Convert Set to List for JSON compatibility
    if (typeName.startsWith('Set<')) {
      return '$fieldRef.toList()';
    }

    // Lists serialize as-is
    return fieldRef;
  }

  /// Generates serialization code for maps.
  String _generateMapSerialization(FieldInfo field, String fieldRef) {
    // Maps serialize as-is (assuming String keys and primitive values)
    return fieldRef;
  }

  /// Generates deserialization code for collections (List, Set).
  String _generateCollectionDeserialization(FieldInfo field, String jsonKey) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final typeArgs = field.type is ParameterizedType
        ? (field.type as ParameterizedType).typeArguments
        : <DartType>[];

    if (typeArgs.isEmpty) {
      // Untyped collection
      return "json['$jsonKey'] as $typeName";
    }

    final itemType = typeArgs.first;
    final itemTypeName = itemType.getDisplayString(withNullability: false);
    final isSet = typeName.startsWith('Set<');
    final collectionMethod = isSet ? 'toSet()' : 'toList()';

    // Handle primitive types
    if (_isPrimitiveType(itemTypeName)) {
      return "(json['$jsonKey'] as List).map((item) => item as $itemTypeName).$collectionMethod";
    }

    // Default case
    return "json['$jsonKey'] as $typeName";
  }

  /// Generates deserialization code for maps.
  String _generateMapDeserialization(FieldInfo field, String jsonKey) {
    final typeArgs = field.type is ParameterizedType
        ? (field.type as ParameterizedType).typeArguments
        : <DartType>[];

    if (typeArgs.length < 2) {
      // Untyped map
      return "Map.from(json['$jsonKey'] as Map)";
    }

    final keyType = typeArgs[0];
    final valueType = typeArgs[1];
    final keyTypeName = keyType.getDisplayString(withNullability: false);
    final valueTypeName = valueType.getDisplayString(withNullability: false);

    // Only handle String keys (JSON limitation)
    if (keyTypeName != 'String') {
      return "Map.from(json['$jsonKey'] as Map)";
    }

    // Handle primitive value types
    if (_isPrimitiveType(valueTypeName) || valueTypeName == 'dynamic') {
      return "Map<String, dynamic>.from(json['$jsonKey'] as Map).map((key, value) => MapEntry(key, value as $valueTypeName))";
    }

    // Default case
    return "Map<String, dynamic>.from(json['$jsonKey'] as Map)";
  }

  /// Checks if a type name represents a primitive type.
  bool _isPrimitiveType(String typeName) {
    return ['String', 'int', 'double', 'bool', 'num', 'dynamic']
        .contains(typeName);
  }
}

/// Represents information about a field.
class FieldInfo {
  /// Creates field information
  const FieldInfo({
    required this.name,
    required this.type,
    required this.isNullable,
  });

  /// Field name
  final String name;

  /// Field type
  final DartType type;

  /// Whether the field is nullable
  final bool isNullable;
}
