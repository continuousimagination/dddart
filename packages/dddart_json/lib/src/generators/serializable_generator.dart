/// Code generator for DDDart JSON serialization.
library;

// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:source_gen/source_gen.dart';

/// Builder function for the serializable generator.
Builder serializableBuilder(BuilderOptions options) =>
    SharedPartBuilder([SerializableGenerator()], 'json_serializable');

/// Generator for DDDart serialization code.
class SerializableGenerator extends GeneratorForAnnotation<Serializable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @Serializable.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Validate that the class extends AggregateRoot or Value
    final classAnalysis = _analyzeClass(classElement);

    // Extract annotation configuration
    final config = _extractAnnotationConfig(annotation);

    // Generate serialization code based on class type
    switch (classAnalysis.type) {
      case ClassType.aggregateRoot:
        return _generateAggregateRootSerialization(
          classElement,
          classAnalysis,
          config,
        );
      case ClassType.value:
        return _generateValueSerialization(classElement, classAnalysis, config);
      case ClassType.entity:
        return _generateEntitySerialization(
          classElement,
          classAnalysis,
          config,
        );
      case ClassType.invalid:
        throw InvalidGenerationSourceError(
          'Class $className must extend either AggregateRoot or Value to use @Serializable annotation.',
          element: element,
        );
    }
  }

  /// Generates serialization code for AggregateRoot classes.
  String _generateAggregateRootSerialization(
    ClassElement classElement,
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final className = analysis.className;

    // Generate the basic toJson and fromJson method bodies
    final toJsonBody = _generateAggregateRootToJson(analysis, config);
    final fromJsonBody = _generateAggregateRootFromJson(analysis, config);

    // Generate the complete JsonSerializer class
    return _generateJsonSerializerClass(
      className,
      toJsonBody,
      fromJsonBody,
      analysis,
    );
  }

  /// Generates serialization code for Value classes.
  String _generateValueSerialization(
    ClassElement classElement,
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final className = analysis.className;

    // Generate the basic toJson and fromJson method bodies
    final toJsonBody = _generateValueToJson(analysis, config);
    final fromJsonBody = _generateValueFromJson(analysis, config);

    // Generate the complete JsonSerializer class
    return _generateJsonSerializerClass(
      className,
      toJsonBody,
      fromJsonBody,
      analysis,
    );
  }

  /// Generates serialization code for Entity classes.
  ///
  /// Entities are similar to AggregateRoots but are serialized as part of
  /// their containing aggregate. They have id, createdAt, and updatedAt fields
  /// from the Entity base class.
  String _generateEntitySerialization(
    ClassElement classElement,
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final className = analysis.className;

    // Generate the basic toJson and fromJson method bodies
    // Entities are serialized like AggregateRoots (they have id, timestamps)
    final toJsonBody = _generateAggregateRootToJson(analysis, config);
    final fromJsonBody = _generateAggregateRootFromJson(analysis, config);

    // Generate the complete JsonSerializer class
    return _generateJsonSerializerClass(
      className,
      toJsonBody,
      fromJsonBody,
      analysis,
    );
  }

  /// Extracts configuration from the @Serializable annotation.
  SerializationConfig _extractAnnotationConfig(ConstantReader annotation) {
    // For now, return default config. In the future, we can extract config from annotation parameters
    return const SerializationConfig();
  }

  /// Analyzes a class to determine its type and extract field information.
  ClassAnalysis _analyzeClass(ClassElement classElement) {
    final className = classElement.name;
    final supertype = classElement.supertype;

    if (supertype == null) {
      return ClassAnalysis(
        type: ClassType.invalid,
        className: className,
        fields: [],
      );
    }

    // Check inheritance hierarchy
    final classType = _determineClassType(classElement);

    // Extract field information
    final fields = _extractFields(classElement, classType);

    return ClassAnalysis(
      type: classType,
      className: className,
      fields: fields,
    );
  }

  /// Determines the type of a class based on its inheritance hierarchy.
  ClassType _determineClassType(ClassElement classElement) {
    // Walk up the inheritance hierarchy to find the base type
    ClassElement? current = classElement;

    while (current != null) {
      final supertype = current.supertype;
      if (supertype == null) break;

      final supertypeName = supertype.element.name;

      // Check for direct inheritance from DDDart base classes
      switch (supertypeName) {
        case 'AggregateRoot':
          return ClassType.aggregateRoot;
        case 'Entity':
          return ClassType.entity;
        case 'Value':
          return ClassType.value;
      }

      current = supertype.element as ClassElement?;
    }

    return ClassType.invalid;
  }

  /// Extracts field information from a class element.
  List<FieldInfo> _extractFields(
    ClassElement classElement,
    ClassType classType,
  ) {
    final fields = <FieldInfo>[];

    // For Entity classes, we need to explicitly include the inherited fields
    // from the Entity base class (id, createdAt, updatedAt) since they're needed
    // for persistence
    if (classType == ClassType.entity) {
      // Add Entity base class fields
      final supertype = classElement.supertype;
      if (supertype != null) {
        for (final field in supertype.element.fields) {
          if (['id', 'createdAt', 'updatedAt'].contains(field.name) &&
              !field.isStatic &&
              !field.isSynthetic) {
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
        }
      }
    }

    // Get all fields from the class (excluding inherited ones from DDDart base classes)
    for (final field in classElement.fields) {
      // Skip static fields and synthetic fields
      if (field.isStatic || field.isSynthetic) continue;

      // Skip fields that are part of the DDDart base classes
      // For AggregateRoot, skip id, createdAt, updatedAt (handled specially)
      // For Entity, we already added these above
      if (['id', 'createdAt', 'updatedAt'].contains(field.name) &&
          (classType == ClassType.aggregateRoot ||
              classType == ClassType.entity)) {
        continue;
      }

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

  /// Generates a complete JsonSerializer class with constructor + optional parameter design.
  String _generateJsonSerializerClass(
    String className,
    String toJsonBody,
    String fromJsonBody,
    ClassAnalysis analysis,
  ) {
    // Generate configurable versions of the methods
    final toJsonWithConfigBody = _generateToJsonWithConfig(className, analysis);
    final fromJsonWithConfigBody =
        _generateFromJsonWithConfig(className, analysis);

    return '''
class ${className}JsonSerializer implements JsonSerializer<$className> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;
  
  /// Creates a serializer with the specified default configuration.
  ${className}JsonSerializer([SerializationConfig? defaultConfig])
      : _defaultConfig = defaultConfig ?? const SerializationConfig();
  
  @override
  Map<String, dynamic> toJson($className instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
$toJsonWithConfigBody
  }
  
  @override
  $className fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
$fromJsonWithConfigBody
  }
  
  @override
  String serialize($className object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }
  
  @override
  $className deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got \${json.runtimeType}',
        expectedType: '$className',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }
  
  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode($className instance, [SerializationConfig? config]) {
    return ${className}JsonSerializer().toJson(instance, config);
  }
  
  /// Convenience method for static access with default configuration
  static $className decode(dynamic json, [SerializationConfig? config]) {
    return ${className}JsonSerializer().fromJson(json, config);
  }
}''';
  }

  /// Generates configurable toJson method body.
  String _generateToJsonWithConfig(String className, ClassAnalysis analysis) {
    final buffer = StringBuffer();
    buffer.writeln('    final json = <String, dynamic>{');

    // Add Entity base fields with runtime field naming
    if (analysis.type == ClassType.aggregateRoot) {
      buffer.writeln(
        "      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename): instance.id.toString(),",
      );
      buffer.writeln(
        "      SerializationUtils.applyFieldRename('createdAt', effectiveConfig.fieldRename): instance.createdAt.toIso8601String(),",
      );
      buffer.writeln(
        "      SerializationUtils.applyFieldRename('updatedAt', effectiveConfig.fieldRename): instance.updatedAt.toIso8601String(),",
      );
    }

    // Sort custom fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(analysis.fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Add custom fields with runtime field naming
    for (final field in sortedFields) {
      final fieldName = field.name;

      if (field.isNullable) {
        buffer.writeln(
          '      if (instance.$fieldName != null || effectiveConfig.includeNullFields)',
        );
        buffer.writeln(
          "        SerializationUtils.applyFieldRename('$fieldName', effectiveConfig.fieldRename): ${_generateFieldSerialization(field, 'instance.')},",
        );
      } else {
        buffer.writeln(
          "      SerializationUtils.applyFieldRename('$fieldName', effectiveConfig.fieldRename): ${_generateFieldSerialization(field, 'instance.')},",
        );
      }
    }

    buffer.writeln('    };');
    buffer.writeln('    return json;');

    return buffer.toString();
  }

  /// Generates configurable fromJson method body.
  String _generateFromJsonWithConfig(String className, ClassAnalysis analysis) {
    final buffer = StringBuffer();

    buffer.writeln('    if (json == null) {');
    buffer.writeln('      throw DeserializationException(');
    buffer.writeln("        'Cannot deserialize $className from null JSON',");
    buffer.writeln("        expectedType: '$className',");
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('    if (json is! Map<String, dynamic>) {');
    buffer.writeln('      throw DeserializationException(');
    buffer.writeln(
      r"        'Expected Map<String, dynamic> but got ${json.runtimeType}',",
    );
    buffer.writeln("        expectedType: '$className',");
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('    try {');
    buffer.writeln('      return $className(');

    // Sort custom fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(analysis.fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Add custom field parameters with runtime field naming
    for (final field in sortedFields) {
      final fieldName = field.name;
      final deserialization = _generateFieldDeserializationWithConfig(field);
      buffer.writeln('        $fieldName: $deserialization,');
    }

    // Add Entity base field parameters with runtime field naming
    if (analysis.type == ClassType.aggregateRoot) {
      buffer.writeln(
        "        id: UuidValue.fromString(json[SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename)] as String),",
      );
      buffer.writeln(
        "        createdAt: json[SerializationUtils.applyFieldRename('createdAt', effectiveConfig.fieldRename)] != null ? DateTime.parse(json[SerializationUtils.applyFieldRename('createdAt', effectiveConfig.fieldRename)] as String) : DateTime.now(),",
      );
      buffer.writeln(
        "        updatedAt: json[SerializationUtils.applyFieldRename('updatedAt', effectiveConfig.fieldRename)] != null ? DateTime.parse(json[SerializationUtils.applyFieldRename('updatedAt', effectiveConfig.fieldRename)] as String) : DateTime.now(),",
      );
    }

    buffer.writeln('      );');
    buffer.writeln('    } catch (e, stackTrace) {');
    buffer.writeln('      throw DeserializationException(');
    buffer.writeln("        'Failed to deserialize $className: \$e',");
    buffer.writeln("        expectedType: '$className',");
    buffer.writeln('      );');
    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Generates field deserialization with runtime configuration.
  String _generateFieldDeserializationWithConfig(FieldInfo field) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final fieldName = field.name;
    final jsonAccess =
        "json[SerializationUtils.applyFieldRename('$fieldName', effectiveConfig.fieldRename)]";

    // Handle nullable types first
    if (field.isNullable) {
      // Handle nullable special types
      if (typeName == 'UuidValue') {
        return '$jsonAccess != null ? UuidValue.fromString($jsonAccess as String) : null';
      }
      if (typeName == 'DateTime') {
        return '$jsonAccess != null ? DateTime.parse($jsonAccess as String) : null';
      }

      // Handle nullable enum types
      if (_isEnumType(field.type)) {
        return '$jsonAccess != null ? $typeName.values.byName($jsonAccess as String) : null';
      }

      // Handle nullable DDDart types
      if (_isDDDartType(field.type)) {
        return '$jsonAccess != null ? ${typeName}JsonSerializer().fromJson($jsonAccess as Map<String, dynamic>, effectiveConfig) : null';
      }

      // Handle nullable collections
      if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
        return '$jsonAccess != null ? ${_generateCollectionDeserializationWithConfig(field, jsonAccess)} : null';
      }

      if (typeName.startsWith('Map<')) {
        return '$jsonAccess != null ? ${_generateMapDeserializationWithConfig(field, jsonAccess)} : null';
      }

      // Handle nullable double type with int-to-double conversion
      if (typeName == 'double') {
        return '$jsonAccess != null ? ($jsonAccess is int ? ($jsonAccess as int).toDouble() : $jsonAccess as double) : null';
      }

      // Default nullable primitive types with casting
      return '$jsonAccess as $typeName?';
    }

    // Handle non-nullable special types
    if (typeName == 'UuidValue') {
      return 'UuidValue.fromString($jsonAccess as String)';
    }

    if (typeName == 'DateTime') {
      return 'DateTime.parse($jsonAccess as String)';
    }

    // Handle non-nullable enum types
    if (_isEnumType(field.type)) {
      return '$typeName.values.byName($jsonAccess as String)';
    }

    // Handle non-nullable collections
    if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
      return _generateCollectionDeserializationWithConfig(field, jsonAccess);
    }

    if (typeName.startsWith('Map<')) {
      return _generateMapDeserializationWithConfig(field, jsonAccess);
    }

    // Check if it's a DDDart type
    if (_isDDDartType(field.type)) {
      return '${typeName}JsonSerializer().fromJson($jsonAccess as Map<String, dynamic>, effectiveConfig)';
    }

    // Handle double type with int-to-double conversion
    if (typeName == 'double') {
      return '($jsonAccess is int ? ($jsonAccess as int).toDouble() : $jsonAccess as double)';
    }

    // Default: primitive types with casting
    return '$jsonAccess as $typeName';
  }

  /// Generates the toJson method body for AggregateRoot classes.
  String _generateAggregateRootToJson(
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('    final json = <String, dynamic>{');

    // Add Entity base fields with consistent naming
    buffer.writeln(
      "      '${_applyFieldRename('id', config.fieldRename)}': instance.id.toString(),",
    );
    buffer.writeln(
      "      '${_applyFieldRename('createdAt', config.fieldRename)}': instance.createdAt.toIso8601String(),",
    );
    buffer.writeln(
      "      '${_applyFieldRename('updatedAt', config.fieldRename)}': instance.updatedAt.toIso8601String(),",
    );

    // Sort custom fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(analysis.fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Add custom fields
    for (final field in sortedFields) {
      final fieldName = field.name;
      final jsonKey = _applyFieldRename(fieldName, config.fieldRename);

      if (field.isNullable && !config.includeNullFields) {
        buffer.writeln(
          "      if (instance.$fieldName != null) '$jsonKey': ${_generateFieldSerializationNonNull(field, 'instance.')},",
        );
      } else {
        buffer.writeln(
          "      '$jsonKey': ${_generateFieldSerialization(field, 'instance.')},",
        );
      }
    }

    buffer.writeln('    };');
    buffer.writeln('    return json;');

    return buffer.toString();
  }

  /// Generates the fromJson method body for AggregateRoot classes.
  String _generateAggregateRootFromJson(
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final className = analysis.className;
    final buffer = StringBuffer();

    buffer.writeln('    try {');
    buffer.writeln('      return $className(');

    // Sort custom fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(analysis.fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Add custom field parameters
    for (final field in sortedFields) {
      final fieldName = field.name;
      final jsonKey = _applyFieldRename(fieldName, config.fieldRename);
      final deserialization = _generateFieldDeserialization(field, jsonKey);
      buffer.writeln('        $fieldName: $deserialization,');
    }

    // Add Entity base field parameters with consistent naming
    final idKey = _applyFieldRename('id', config.fieldRename);
    final createdAtKey = _applyFieldRename('createdAt', config.fieldRename);
    final updatedAtKey = _applyFieldRename('updatedAt', config.fieldRename);

    buffer
        .writeln("        id: UuidValue.fromString(json['$idKey'] as String),");
    buffer.writeln(
      "        createdAt: DateTime.parse(json['$createdAtKey'] as String),",
    );
    buffer.writeln(
      "        updatedAt: DateTime.parse(json['$updatedAtKey'] as String),",
    );

    buffer.writeln('      );');
    buffer.writeln('    } catch (e, stackTrace) {');
    buffer.writeln('      throw DeserializationException(');
    buffer.writeln("        'Failed to deserialize $className: \$e',");
    buffer.writeln("        expectedType: '$className',");
    buffer.writeln('      );');
    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Generates the toJson method body for Value classes.
  String _generateValueToJson(
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('    final json = <String, dynamic>{');

    // Sort custom fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(analysis.fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Add custom fields
    for (final field in sortedFields) {
      final fieldName = field.name;
      final jsonKey = _applyFieldRename(fieldName, config.fieldRename);

      if (field.isNullable && !config.includeNullFields) {
        buffer.writeln(
          "      if (instance.$fieldName != null) '$jsonKey': ${_generateFieldSerializationNonNull(field, 'instance.')},",
        );
      } else {
        buffer.writeln(
          "      '$jsonKey': ${_generateFieldSerialization(field, 'instance.')},",
        );
      }
    }

    buffer.writeln('    };');
    buffer.writeln('    return json;');

    return buffer.toString();
  }

  /// Generates the fromJson method body for Value classes.
  String _generateValueFromJson(
    ClassAnalysis analysis,
    SerializationConfig config,
  ) {
    final className = analysis.className;
    final buffer = StringBuffer();

    buffer.writeln('    try {');
    buffer.writeln('      return $className(');

    // Sort custom fields alphabetically for deterministic ordering
    final sortedFields = List<FieldInfo>.from(analysis.fields)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Add custom field parameters
    for (final field in sortedFields) {
      final fieldName = field.name;
      final jsonKey = _applyFieldRename(fieldName, config.fieldRename);
      final deserialization = _generateFieldDeserialization(field, jsonKey);
      buffer.writeln('        $fieldName: $deserialization,');
    }

    buffer.writeln('      );');
    buffer.writeln('    } catch (e, stackTrace) {');
    buffer.writeln('      throw DeserializationException(');
    buffer.writeln("        'Failed to deserialize $className: \$e',");
    buffer.writeln("        expectedType: '$className',");
    buffer.writeln('      );');
    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Applies field renaming based on the configuration.
  String _applyFieldRename(String fieldName, FieldRename fieldRename) {
    switch (fieldRename) {
      case FieldRename.none:
        return fieldName;
      case FieldRename.snake:
        return _toSnakeCase(fieldName);
      case FieldRename.kebab:
        return _toKebabCase(fieldName);
    }
  }

  /// Converts a camelCase string to snake_case.
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Converts a camelCase string to kebab-case.
  String _toKebabCase(String input) {
    return input.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '-${match.group(0)!.toLowerCase()}',
    );
  }

  /// Generates serialization code for a field assuming it's not null.
  String _generateFieldSerializationNonNull(
    FieldInfo field, [
    String prefix = '',
  ]) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final fieldRef = '$prefix${field.name}';

    // Handle special types with standardized formats
    if (typeName == 'UuidValue') {
      return '$fieldRef.toString()';
    }

    if (typeName == 'DateTime') {
      return '$fieldRef.toIso8601String()';
    }

    // Handle enum types
    if (_isEnumType(field.type)) {
      return '$fieldRef!.name';
    }

    // Handle collections
    if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
      return _generateCollectionSerialization(field, fieldRef);
    }

    if (typeName.startsWith('Map<')) {
      return _generateMapSerialization(field, fieldRef);
    }

    // Check if it's a DDDart type (Entity or Value) - assume non-null
    if (_isDDDartType(field.type)) {
      final serializerName = '${typeName}JsonSerializer';
      // Use non-null assertion since we're in a context where we know it's not null
      return '$serializerName().toJson($fieldRef!, effectiveConfig)';
    }

    // Default: primitive types
    return fieldRef;
  }

  /// Generates serialization code for a field.
  String _generateFieldSerialization(FieldInfo field, [String prefix = '']) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final fieldRef = '$prefix${field.name}';

    // Handle nullable types first
    if (field.isNullable) {
      // Handle nullable special types
      if (typeName == 'UuidValue') {
        return '$fieldRef?.toString()';
      }
      if (typeName == 'DateTime') {
        return '$fieldRef?.toIso8601String()';
      }

      // Handle nullable enum types
      if (_isEnumType(field.type)) {
        return '$fieldRef?.name';
      }

      // Handle nullable collections
      if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
        return '$fieldRef != null ? ${_generateCollectionSerialization(field, '$fieldRef!')} : null';
      }

      if (typeName.startsWith('Map<')) {
        return '$fieldRef != null ? ${_generateMapSerialization(field, '$fieldRef!')} : null';
      }

      // Handle nullable DDDart types
      if (_isDDDartType(field.type)) {
        final serializerName = '${typeName}JsonSerializer';
        return '$fieldRef != null ? $serializerName().toJson($fieldRef!, effectiveConfig) : null';
      }

      // Default nullable primitive types
      return fieldRef;
    }

    // Handle non-nullable special types
    if (typeName == 'UuidValue') {
      return '$fieldRef.toString()';
    }

    if (typeName == 'DateTime') {
      return '$fieldRef.toIso8601String()';
    }

    // Handle non-nullable enum types
    if (_isEnumType(field.type)) {
      return '$fieldRef.name';
    }

    // Handle non-nullable collections
    if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
      return _generateCollectionSerialization(field, fieldRef);
    }

    if (typeName.startsWith('Map<')) {
      return _generateMapSerialization(field, fieldRef);
    }

    // Check if it's a DDDart type (Entity or Value)
    if (_isDDDartType(field.type)) {
      final serializerName = '${typeName}JsonSerializer';
      return '$serializerName().toJson($fieldRef, effectiveConfig)';
    }

    // Default: primitive types
    return fieldRef;
  }

  /// Generates deserialization code for a field.
  String _generateFieldDeserialization(FieldInfo field, String jsonKey) {
    final typeName = field.type.getDisplayString(withNullability: false);

    // Handle special types with standardized formats
    if (typeName == 'UuidValue') {
      return "UuidValue.fromString(json['$jsonKey'] as String)";
    }

    if (typeName == 'DateTime') {
      return "DateTime.parse(json['$jsonKey'] as String)";
    }

    // Handle nullable special types
    if (field.isNullable) {
      if (typeName == 'UuidValue') {
        return "json['$jsonKey'] != null ? UuidValue.fromString(json['$jsonKey'] as String) : null";
      }
      if (typeName == 'DateTime') {
        return "json['$jsonKey'] != null ? DateTime.parse(json['$jsonKey'] as String) : null";
      }

      // Handle nullable enum types
      if (_isEnumType(field.type)) {
        return "json['$jsonKey'] != null ? $typeName.values.byName(json['$jsonKey'] as String) : null";
      }

      // Handle nullable DDDart types
      if (_isDDDartType(field.type)) {
        return "json['$jsonKey'] != null ? ${typeName}JsonSerializer().fromJson(json['$jsonKey'], effectiveConfig) : null";
      }
    }

    // Handle non-nullable enum types
    if (_isEnumType(field.type)) {
      return "$typeName.values.byName(json['$jsonKey'] as String)";
    }

    // Handle collections
    if (typeName.startsWith('List<') || typeName.startsWith('Set<')) {
      return _generateCollectionDeserialization(field, jsonKey);
    }

    if (typeName.startsWith('Map<')) {
      return _generateMapDeserialization(field, jsonKey);
    }

    // Check if it's a DDDart type
    if (_isDDDartType(field.type)) {
      return "${typeName}JsonSerializer().fromJson(json['$jsonKey'], effectiveConfig)";
    }

    // Default: primitive types with casting
    return "json['$jsonKey'] as $typeName";
  }

  /// Generates serialization code for collections (List, Set).
  String _generateCollectionSerialization(FieldInfo field, String fieldRef) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final typeArgs = field.type is ParameterizedType
        ? (field.type as ParameterizedType).typeArguments
        : <DartType>[];

    if (typeArgs.isEmpty) {
      // Untyped collection, serialize as-is
      return fieldRef;
    }

    final itemType = typeArgs.first;
    final itemTypeName = itemType.getDisplayString(withNullability: false);

    // Handle special item types
    if (itemTypeName == 'UuidValue') {
      return '$fieldRef.map((item) => item.toString()).toList()';
    }

    if (itemTypeName == 'DateTime') {
      return '$fieldRef.map((item) => item.toIso8601String()).toList()';
    }

    // Handle enum item types
    if (_isEnumType(itemType)) {
      return '$fieldRef.map((item) => item.name).toList()';
    }

    // Handle DDDart types
    if (_isDDDartType(itemType)) {
      return '$fieldRef.map((item) => ${itemTypeName}JsonSerializer().toJson(item, effectiveConfig)).toList()';
    }

    // Handle nested collections
    if (itemTypeName.startsWith('List<') ||
        itemTypeName.startsWith('Set<') ||
        itemTypeName.startsWith('Map<')) {
      // For nested collections, we need to recursively handle them
      // This is complex, so for now we'll serialize as-is and let Dart handle it
      return fieldRef;
    }

    // Primitive types - convert Set to List for JSON compatibility
    if (typeName.startsWith('Set<')) {
      return '$fieldRef.toList()';
    }

    // Other primitive types - serialize as-is
    return fieldRef;
  }

  /// Generates serialization code for maps.
  String _generateMapSerialization(FieldInfo field, String fieldRef) {
    final typeArgs = field.type is ParameterizedType
        ? (field.type as ParameterizedType).typeArguments
        : <DartType>[];

    if (typeArgs.length < 2) {
      // Untyped map, serialize as-is
      return fieldRef;
    }

    final keyType = typeArgs[0];
    final valueType = typeArgs[1];
    final keyTypeName = keyType.getDisplayString(withNullability: false);
    final valueTypeName = valueType.getDisplayString(withNullability: false);

    // Only handle String keys for now (JSON limitation)
    if (keyTypeName != 'String') {
      return fieldRef;
    }

    // Handle special value types
    if (valueTypeName == 'UuidValue') {
      return '$fieldRef.map((key, value) => MapEntry(key, value.toString()))';
    }

    if (valueTypeName == 'DateTime') {
      return '$fieldRef.map((key, value) => MapEntry(key, value.toIso8601String()))';
    }

    // Handle enum value types
    if (_isEnumType(valueType)) {
      return '$fieldRef.map((key, value) => MapEntry(key, value.name))';
    }

    // Handle DDDart value types
    if (_isDDDartType(valueType)) {
      return '$fieldRef.map((key, value) => MapEntry(key, ${valueTypeName}JsonSerializer().toJson(value, effectiveConfig)))';
    }

    // Primitive values - serialize as-is
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
    final itemTypeNameWithNull =
        itemType.getDisplayString(withNullability: true);
    final isSet = typeName.startsWith('Set<');
    final collectionMethod = isSet ? 'toSet()' : 'toList()';

    // Handle special item types
    if (itemTypeName == 'UuidValue') {
      return "(json['$jsonKey'] as List).map((item) => UuidValue.fromString(item as String)).$collectionMethod";
    }

    if (itemTypeName == 'DateTime') {
      return "(json['$jsonKey'] as List).map((item) => DateTime.parse(item as String)).$collectionMethod";
    }

    // Handle enum item types
    if (_isEnumType(itemType)) {
      return "(json['$jsonKey'] as List).map((item) => $itemTypeName.values.byName(item as String)).$collectionMethod";
    }

    // Handle DDDart types
    if (_isDDDartType(itemType)) {
      return "(json['$jsonKey'] as List).map((item) => ${itemTypeName}JsonSerializer().fromJson(item, effectiveConfig)).$collectionMethod";
    }

    // Handle primitive types
    if (_isPrimitiveType(itemTypeName)) {
      return "(json['$jsonKey'] as List).map((item) => item as $itemTypeNameWithNull).$collectionMethod";
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
      // Untyped map - use Map.from to handle dynamic keys
      return "Map.from(json['$jsonKey'] as Map)";
    }

    final keyType = typeArgs[0];
    final valueType = typeArgs[1];
    final keyTypeName = keyType.getDisplayString(withNullability: false);
    final valueTypeName = valueType.getDisplayString(withNullability: false);

    // Only handle String keys for now (JSON limitation)
    if (keyTypeName != 'String') {
      return "Map.from(json['$jsonKey'] as Map)";
    }

    // Handle special value types
    if (valueTypeName == 'UuidValue') {
      return "Map<String, dynamic>.from(json['$jsonKey'] as Map).map((key, value) => MapEntry(key, UuidValue.fromString(value as String)))";
    }

    if (valueTypeName == 'DateTime') {
      return "Map<String, dynamic>.from(json['$jsonKey'] as Map).map((key, value) => MapEntry(key, DateTime.parse(value as String)))";
    }

    // Handle enum value types
    if (_isEnumType(valueType)) {
      return "Map<String, dynamic>.from(json['$jsonKey'] as Map).map((key, value) => MapEntry(key, $valueTypeName.values.byName(value as String)))";
    }

    // Handle DDDart value types
    if (_isDDDartType(valueType)) {
      return "Map<String, dynamic>.from(json['$jsonKey'] as Map).map((key, value) => MapEntry(key, ${valueTypeName}JsonSerializer().fromJson(value, effectiveConfig)))";
    }

    // Handle primitive value types (including dynamic)
    if (_isPrimitiveType(valueTypeName) || valueTypeName == 'dynamic') {
      return "Map<String, dynamic>.from(json['$jsonKey'] as Map).map((key, value) => MapEntry(key, value as $valueTypeName))";
    }

    // Default case - use Map.from for safe casting
    return "Map<String, dynamic>.from(json['$jsonKey'] as Map)";
  }

  /// Generates deserialization code for collections with runtime configuration.
  String _generateCollectionDeserializationWithConfig(
    FieldInfo field,
    String jsonAccess,
  ) {
    final typeName = field.type.getDisplayString(withNullability: false);
    final typeArgs = field.type is ParameterizedType
        ? (field.type as ParameterizedType).typeArguments
        : <DartType>[];

    if (typeArgs.isEmpty) {
      // Untyped collection
      return '$jsonAccess as $typeName';
    }

    final itemType = typeArgs.first;
    final itemTypeName = itemType.getDisplayString(withNullability: false);
    final itemTypeNameWithNull =
        itemType.getDisplayString(withNullability: true);
    final isSet = typeName.startsWith('Set<');
    final collectionMethod = isSet ? 'toSet()' : 'toList()';

    // Handle special item types
    if (itemTypeName == 'UuidValue') {
      return '($jsonAccess as List).map((item) => UuidValue.fromString(item as String)).$collectionMethod';
    }

    if (itemTypeName == 'DateTime') {
      return '($jsonAccess as List).map((item) => DateTime.parse(item as String)).$collectionMethod';
    }

    // Handle enum item types
    if (_isEnumType(itemType)) {
      return '($jsonAccess as List).map((item) => $itemTypeName.values.byName(item as String)).$collectionMethod';
    }

    // Handle DDDart types
    if (_isDDDartType(itemType)) {
      return '($jsonAccess as List).map((item) => ${itemTypeName}JsonSerializer().fromJson(item as Map<String, dynamic>, effectiveConfig)).$collectionMethod';
    }

    // Handle primitive types
    if (_isPrimitiveType(itemTypeName)) {
      return '($jsonAccess as List).map((item) => item as $itemTypeNameWithNull).$collectionMethod';
    }

    // Default case
    return '$jsonAccess as $typeName';
  }

  /// Generates deserialization code for maps with runtime configuration.
  String _generateMapDeserializationWithConfig(
    FieldInfo field,
    String jsonAccess,
  ) {
    final typeArgs = field.type is ParameterizedType
        ? (field.type as ParameterizedType).typeArguments
        : <DartType>[];

    if (typeArgs.length < 2) {
      // Untyped map - use Map.from to handle dynamic keys
      return 'Map.from($jsonAccess as Map)';
    }

    final keyType = typeArgs[0];
    final valueType = typeArgs[1];
    final keyTypeName = keyType.getDisplayString(withNullability: false);
    final valueTypeName = valueType.getDisplayString(withNullability: false);

    // Only handle String keys for now (JSON limitation)
    if (keyTypeName != 'String') {
      return 'Map.from($jsonAccess as Map)';
    }

    // Handle special value types
    if (valueTypeName == 'UuidValue') {
      return 'Map<String, dynamic>.from($jsonAccess as Map).map((key, value) => MapEntry(key, UuidValue.fromString(value as String)))';
    }

    if (valueTypeName == 'DateTime') {
      return 'Map<String, dynamic>.from($jsonAccess as Map).map((key, value) => MapEntry(key, DateTime.parse(value as String)))';
    }

    // Handle enum value types
    if (_isEnumType(valueType)) {
      return 'Map<String, dynamic>.from($jsonAccess as Map).map((key, value) => MapEntry(key, $valueTypeName.values.byName(value as String)))';
    }

    // Handle DDDart value types
    if (_isDDDartType(valueType)) {
      return 'Map<String, dynamic>.from($jsonAccess as Map).map((key, value) => MapEntry(key, ${valueTypeName}JsonSerializer().fromJson(value as Map<String, dynamic>, effectiveConfig)))';
    }

    // Handle primitive value types (including dynamic)
    if (_isPrimitiveType(valueTypeName) || valueTypeName == 'dynamic') {
      return 'Map<String, dynamic>.from($jsonAccess as Map).map((key, value) => MapEntry(key, value as $valueTypeName))';
    }

    // Default case - use Map.from for safe casting
    return 'Map<String, dynamic>.from($jsonAccess as Map)';
  }

  /// Checks if a type name represents a primitive type.
  bool _isPrimitiveType(String typeName) {
    return ['String', 'int', 'double', 'bool', 'num', 'dynamic']
        .contains(typeName);
  }

  /// Checks if a type is an enum type.
  bool _isEnumType(DartType type) {
    final element = type.element;
    if (element == null) return false;

    // In newer analyzer versions, enums are represented by EnumElement
    // Check the element's runtime type name since we might not have direct access to EnumElement
    final elementTypeName = element.runtimeType.toString();
    if (elementTypeName.contains('Enum')) {
      return true;
    }

    // Fallback: Check if it's a ClassElement with Enum supertype
    if (element is ClassElement) {
      var currentElement = element;
      while (true) {
        final supertype = currentElement.supertype;
        if (supertype == null) break;

        // Check if the supertype is named 'Enum' (from dart:core)
        final supertypeName = supertype.element.name;
        if (supertypeName == 'Enum') {
          return true;
        }

        // Move up the chain
        final supertypeElement = supertype.element;
        if (supertypeElement is! ClassElement) break;
        currentElement = supertypeElement;
      }
    }

    return false;
  }

  /// Checks if a type is a DDDart type (AggregateRoot, Entity, or Value).
  bool _isDDDartType(DartType type) {
    final element = type.element;
    if (element is! ClassElement) return false;

    // Walk up the inheritance hierarchy
    ClassElement? current = element;
    while (current != null) {
      final supertype = current.supertype;
      if (supertype == null) break;

      final supertypeName = supertype.element.name;
      if (['AggregateRoot', 'Entity', 'Value'].contains(supertypeName)) {
        return true;
      }

      current = supertype.element as ClassElement?;
    }

    return false;
  }
}

/// Represents the analysis result of a class.
class ClassAnalysis {
  const ClassAnalysis({
    required this.type,
    required this.className,
    required this.fields,
  });
  final ClassType type;
  final String className;
  final List<FieldInfo> fields;
}

/// Represents information about a field.
class FieldInfo {
  const FieldInfo({
    required this.name,
    required this.type,
    required this.isNullable,
  });
  final String name;
  final DartType type;
  final bool isNullable;
}

/// Enumeration of class types for serialization.
enum ClassType {
  aggregateRoot,
  entity,
  value,
  invalid,
}
