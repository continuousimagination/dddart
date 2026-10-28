/// Code generator for DDDart JSON serialization.
library;

// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart/dddart.dart'
    show AggregateRoot, Entity, Identity, UuidValue, Value;
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:source_gen/source_gen.dart';

/// Builder function for the serializable generator.
Builder serializableBuilder(BuilderOptions options) =>
    SharedPartBuilder([SerializableGenerator()], 'json_serializable');

/// Generator for DDDart serialization code.
class SerializableGenerator extends GeneratorForAnnotation<Serializable> {
  static const _aggregateRootType = TypeChecker.fromRuntime(AggregateRoot);
  static const _entityType = TypeChecker.fromRuntime(Entity);
  static const _valueType = TypeChecker.fromRuntime(Value);
  static const _identityType = TypeChecker.fromRuntime(Identity);
  static const _uuidType = TypeChecker.fromRuntime(UuidValue);

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
    if (classElement.typeParameters.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Annotate a concrete non-generic consuming class; generic base classes may remain unannotated.',
        element: classElement,
      );
    }

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
      config,
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
      config,
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
      config,
    );
  }

  /// Extracts configuration from the @Serializable annotation.
  SerializationConfig _extractAnnotationConfig(ConstantReader annotation) {
    final fieldRenameIndex = annotation
        .read('fieldRename')
        .objectValue
        .getField('index')
        ?.toIntValue();

    if (fieldRenameIndex == null ||
        fieldRenameIndex < 0 ||
        fieldRenameIndex >= FieldRename.values.length) {
      throw InvalidGenerationSourceError(
        'The @Serializable fieldRename setting is invalid.',
      );
    }

    return SerializationConfig(
      includeNullFields: annotation.read('includeNullFields').boolValue,
      fieldRename: FieldRename.values[fieldRenameIndex],
    );
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

    DartType? identityType;
    if (classType == ClassType.aggregateRoot || classType == ClassType.entity) {
      final entity = classElement.allSupertypes.firstWhere(
        (type) => _entityType.isExactly(type.element),
      );
      identityType = entity.typeArguments.single;
      if (identityType is! InterfaceType ||
          _identityType.isExactly(identityType.element)) {
        throw InvalidGenerationSourceError(
          'Class $className must specify a concrete identity type. Use UuidAggregateRoot/UuidEntity or an explicit Identity subtype.',
          element: classElement,
        );
      }
    }

    return ClassAnalysis(
      type: classType,
      className: className,
      fields: fields,
      identityType: identityType,
    );
  }

  /// Determines the type of a class based on its inheritance hierarchy.
  ClassType _determineClassType(ClassElement classElement) {
    // Walk up the inheritance hierarchy to find the base type
    ClassElement? current = classElement;

    while (current != null) {
      final supertype = current.supertype;
      if (supertype == null) break;

      final supertypeElement = supertype.element;

      if (_aggregateRootType.isExactly(supertypeElement)) {
        return ClassType.aggregateRoot;
      }
      if (_entityType.isExactly(supertypeElement)) {
        return ClassType.entity;
      }
      if (_valueType.isExactly(supertypeElement)) {
        return ClassType.value;
      }

      current = supertypeElement as ClassElement?;
    }

    return ClassType.invalid;
  }

  /// Extracts field information from a class element.
  List<FieldInfo> _extractFields(
    ClassElement classElement,
    ClassType classType,
  ) {
    final fields = <FieldInfo>[];

    final frameworkBaseType = switch (classType) {
      ClassType.aggregateRoot => _aggregateRootType,
      ClassType.entity => _entityType,
      ClassType.value => _valueType,
      ClassType.invalid => null,
    };
    if (frameworkBaseType == null) return fields;

    final fieldNames = <String>{};
    InterfaceType? current = classElement.thisType;
    while (current != null && !frameworkBaseType.isExactly(current.element)) {
      final isInherited = current.element != classElement;

      for (final field in current.element.fields) {
        if (field.isStatic || field.isSynthetic) continue;
        if ((classType == ClassType.aggregateRoot ||
                classType == ClassType.entity) &&
            ['id', 'createdAt', 'updatedAt'].contains(field.name)) {
          continue;
        }

        if (!fieldNames.add(field.name)) {
          throw InvalidGenerationSourceError(
            'Cannot generate JSON serializer for ${classElement.name}: '
            'application field "${field.name}" is declared more than once '
            'in its superclass chain.',
            element: classElement,
          );
        }

        if (isInherited) {
          _validateInheritedFieldReconstruction(classElement, field);
        }

        final fieldType =
            current.getGetter(field.name)?.returnType ?? field.type;
        fields.add(
          FieldInfo(
            name: field.name,
            type: fieldType,
            isNullable:
                fieldType.nullabilitySuffix == NullabilitySuffix.question,
          ),
        );
      }

      current = current.superclass;
    }

    return fields;
  }

  void _validateInheritedFieldReconstruction(
    ClassElement classElement,
    FieldElement field,
  ) {
    final constructor = classElement.unnamedConstructor;
    SuperFormalParameterElement? reconstructionParameter;

    if (constructor != null) {
      for (final parameter in constructor.parameters) {
        if (parameter.name == field.name &&
            parameter.isNamed &&
            parameter is SuperFormalParameterElement) {
          reconstructionParameter = parameter;
          break;
        }
      }
    }

    ParameterElement? currentParameter = reconstructionParameter;
    while (currentParameter is SuperFormalParameterElement) {
      currentParameter = currentParameter.superConstructorParameter;
    }

    final reconstructedField = currentParameter is FieldFormalParameterElement
        ? currentParameter.field
        : null;
    if (reconstructedField?.declaration == field.declaration) return;

    throw InvalidGenerationSourceError(
      'Cannot generate JSON serializer for ${classElement.name}: inherited '
      'application field "${field.name}" has no reconstruction path through '
      "${classElement.name}'s unnamed constructor and named super-parameter "
      'chain.',
      element: classElement,
    );
  }

  /// Generates a complete JsonSerializer class with constructor + optional parameter design.
  String _generateJsonSerializerClass(
    String className,
    String toJsonBody,
    String fromJsonBody,
    ClassAnalysis analysis,
    SerializationConfig annotationConfig,
  ) {
    // Generate configurable versions of the methods
    final toJsonWithConfigBody = _generateToJsonWithConfig(className, analysis);
    final fromJsonWithConfigBody =
        _generateFromJsonWithConfig(className, analysis);
    final annotationConfigSource = _generateConfigSource(annotationConfig);

    return '''
class ${className}JsonSerializer implements JsonSerializer<$className> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;
  final IdentityCodecRegistry _identityCodecs;

  /// Identity codecs shared with nested serializers and composition code.
  IdentityCodecRegistry get identityCodecs => _identityCodecs;
  
  /// Creates a serializer with the specified default configuration.
  ${className}JsonSerializer([SerializationConfig? defaultConfig])
      : this.withIdentityCodecs(IdentityCodecRegistry(), defaultConfig);

  /// Creates a serializer with explicit, shared identity encodings.
  ${className}JsonSerializer.withIdentityCodecs(
    this._identityCodecs, [SerializationConfig? defaultConfig])
      : _defaultConfig = defaultConfig ?? $annotationConfigSource;
  
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
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object but got \${json.runtimeType}',
          expectedType: '$className',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } catch (e) {
      if (e is DeserializationException) rethrow;
      throw DeserializationException(
        'Failed to deserialize JSON: \$e',
        expectedType: '$className',
      );
    }
  }
  
  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode($className instance, [SerializationConfig? config, IdentityCodecRegistry? identityCodecs]) {
    return ${className}JsonSerializer.withIdentityCodecs(identityCodecs ?? IdentityCodecRegistry()).toJson(instance, config);
  }
  
  /// Convenience method for static access with default configuration
  static $className decode(dynamic json, [SerializationConfig? config, IdentityCodecRegistry? identityCodecs]) {
    return ${className}JsonSerializer.withIdentityCodecs(identityCodecs ?? IdentityCodecRegistry()).fromJson(json, config);
  }
}''';
  }

  String _generateConfigSource(SerializationConfig config) {
    return 'const SerializationConfig('
        'fieldRename: FieldRename.${config.fieldRename.name}, '
        'includeNullFields: ${config.includeNullFields},'
        ')';
  }

  /// Generates configurable toJson method body.
  String _generateToJsonWithConfig(String className, ClassAnalysis analysis) {
    final buffer = StringBuffer();
    buffer.writeln('    final json = <String, dynamic>{');

    // Add Entity base fields with runtime field naming
    if (analysis.type == ClassType.aggregateRoot ||
        analysis.type == ClassType.entity) {
      buffer.writeln(
        "      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename): ${_encodeValue(analysis.identityType!, 'instance.id')},",
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
    if (analysis.type == ClassType.aggregateRoot ||
        analysis.type == ClassType.entity) {
      buffer.writeln(
        "        id: ${_decodeValue(analysis.identityType!, "json[SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename)]")},",
      );
      buffer.writeln(
        "        createdAt: json[SerializationUtils.applyFieldRename('createdAt', effectiveConfig.fieldRename)] != null ? DateTime.parse(json[SerializationUtils.applyFieldRename('createdAt', effectiveConfig.fieldRename)] as String) : DateTime.now(),",
      );
      buffer.writeln(
        "        updatedAt: json[SerializationUtils.applyFieldRename('updatedAt', effectiveConfig.fieldRename)] != null ? DateTime.parse(json[SerializationUtils.applyFieldRename('updatedAt', effectiveConfig.fieldRename)] as String) : DateTime.now(),",
      );
    }

    buffer.writeln('      );');
    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw DeserializationException(');
    buffer.writeln("        'Failed to deserialize $className: \$e',");
    buffer.writeln("        expectedType: '$className',");
    buffer.writeln('      );');
    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Generates field deserialization with runtime configuration.
  String _generateFieldDeserializationWithConfig(FieldInfo field) {
    final access =
        "json[SerializationUtils.applyFieldRename('${field.name}', effectiveConfig.fieldRename)]";
    return _decodeValue(field.type, access);
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
      "      '${_applyFieldRename('id', config.fieldRename)}': ${_encodeValue(analysis.identityType!, 'instance.id')},",
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

    buffer.writeln(
        "        id: ${_decodeValue(analysis.identityType!, "json['$idKey']")},");
    buffer.writeln(
      "        createdAt: DateTime.parse(json['$createdAtKey'] as String),",
    );
    buffer.writeln(
      "        updatedAt: DateTime.parse(json['$updatedAtKey'] as String),",
    );

    buffer.writeln('      );');
    buffer.writeln('    } catch (e) {');
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
    buffer.writeln('    } catch (e) {');
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

  /// Generates serialization for a field selected by an enclosing null check.
  String _generateFieldSerializationNonNull(FieldInfo field,
          [String prefix = '']) =>
      _encodeValue(field.type, '$prefix${field.name}');

  /// Generates serialization through the same recursive structural contract.
  String _generateFieldSerialization(FieldInfo field, [String prefix = '']) =>
      _encodeValue(field.type, '$prefix${field.name}');

  /// Generates deserialization for an already resolved JSON key.
  String _generateFieldDeserialization(FieldInfo field, String jsonKey) =>
      _decodeValue(field.type, "json['$jsonKey']");

  bool _coreCollection(DartType type, String name) =>
      type is InterfaceType &&
      type.element.name == name &&
      type.element.library.source.uri.toString() == 'dart:core';

  bool _identity(DartType type) => _identityType.isAssignableFromType(type);

  void _validateIdentity(DartType type) {
    if (type is! InterfaceType || _identityType.isExactly(type.element)) {
      throw InvalidGenerationSourceError(
        'Identity values require a concrete identity type and an explicit codec.',
      );
    }
  }

  String _encodeValue(DartType type, String value, {bool nonNull = false}) {
    if (!nonNull && type.nullabilitySuffix == NullabilitySuffix.question) {
      // Collection callback parameters promote after the null check; public
      // instance fields and computed expressions still require an assertion.
      final present =
          {'item', 'key', 'value'}.contains(value) ? value : '$value!';
      return '$value != null ? ${_encodeValue(type, present, nonNull: true)} : null';
    }
    final name = type.getDisplayString(withNullability: false);
    if (type is InterfaceType && _uuidType.isExactly(type.element)) {
      return 'const UuidIdentityCodec().toJson($value)';
    }
    if (_identity(type)) {
      _validateIdentity(type);
      return '_identityCodecs.toJson<$name>($value)';
    }
    if (name == 'DateTime') return '$value.toIso8601String()';
    if (_isEnumType(type)) return '$value.name';
    if (_coreCollection(type, 'List') || _coreCollection(type, 'Set')) {
      final item = (type as InterfaceType).typeArguments.single;
      return '$value.map((item) => ${_encodeValue(item, 'item')}).toList()';
    }
    if (_coreCollection(type, 'Map')) {
      final arguments = (type as InterfaceType).typeArguments;
      final key = arguments[0];
      final keyName = key.getDisplayString(withNullability: false);
      final String encodedKey;
      if (keyName == 'String' &&
          key.nullabilitySuffix != NullabilitySuffix.question) {
        encodedKey = 'key';
      } else if (_identity(key) &&
          key.nullabilitySuffix != NullabilitySuffix.question) {
        _validateIdentity(key);
        encodedKey = key is InterfaceType && _uuidType.isExactly(key.element)
            ? 'const UuidIdentityCodec().toKey(key)'
            : '_identityCodecs.toKey<$keyName>(key)';
      } else {
        throw InvalidGenerationSourceError(
          'JSON map keys must be non-null strings or concrete identities with key codecs.',
        );
      }
      return '$value.map((key, value) => MapEntry($encodedKey, ${_encodeValue(arguments[1], 'value')}))';
    }
    if (_isDDDartType(type)) {
      if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
        throw InvalidGenerationSourceError(
            'Use a concrete non-generic serializable value subtype.');
      }
      return '${name}JsonSerializer.withIdentityCodecs(_identityCodecs).toJson($value, effectiveConfig)';
    }
    if (_isPrimitiveType(name) || name == 'Object' || name == 'Null')
      return value;
    throw InvalidGenerationSourceError('Unsupported JSON field type: $name');
  }

  String _decodeValue(DartType type, String value, {bool nonNull = false}) {
    if (!nonNull && type.nullabilitySuffix == NullabilitySuffix.question) {
      return '$value != null ? ${_decodeValue(type, value, nonNull: true)} : null';
    }
    final name = type.getDisplayString(withNullability: false);
    if (type is InterfaceType && _uuidType.isExactly(type.element)) {
      return 'const UuidIdentityCodec().fromJson($value)';
    }
    if (_identity(type)) {
      _validateIdentity(type);
      return '_identityCodecs.fromJson<$name>($value)';
    }
    if (name == 'DateTime') return 'DateTime.parse($value as String)';
    if (_isEnumType(type)) return '$name.values.byName($value as String)';
    if (_coreCollection(type, 'List') || _coreCollection(type, 'Set')) {
      final item = (type as InterfaceType).typeArguments.single;
      final method = _coreCollection(type, 'Set') ? 'toSet()' : 'toList()';
      return '($value as List).map((item) => ${_decodeValue(item, 'item')}).$method';
    }
    if (_coreCollection(type, 'Map')) {
      final arguments = (type as InterfaceType).typeArguments;
      final key = arguments[0];
      final keyName = key.getDisplayString(withNullability: false);
      final String decodedKey;
      if (keyName == 'String' &&
          key.nullabilitySuffix != NullabilitySuffix.question) {
        decodedKey = 'key';
      } else if (_identity(key) &&
          key.nullabilitySuffix != NullabilitySuffix.question) {
        _validateIdentity(key);
        decodedKey = key is InterfaceType && _uuidType.isExactly(key.element)
            ? 'const UuidIdentityCodec().fromKey(key)'
            : '_identityCodecs.fromKey<$keyName>(key)';
      } else {
        throw InvalidGenerationSourceError(
          'JSON map keys must be non-null strings or concrete identities with key codecs.',
        );
      }
      return 'Map<String, dynamic>.from($value as Map).map((key, value) => MapEntry($decodedKey, ${_decodeValue(arguments[1], 'value')}))';
    }
    if (_isDDDartType(type)) {
      if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
        throw InvalidGenerationSourceError(
            'Use a concrete non-generic serializable value subtype.');
      }
      return '${name}JsonSerializer.withIdentityCodecs(_identityCodecs).fromJson($value as Map<String, dynamic>, effectiveConfig)';
    }
    if (name == 'double') {
      return '($value is int ? ($value as int).toDouble() : $value as double)';
    }
    if (name == 'dynamic') return value;
    if (_isPrimitiveType(name) || name == 'Object' || name == 'Null')
      return '$value as $name';
    throw InvalidGenerationSourceError('Unsupported JSON field type: $name');
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
    this.identityType,
  });
  final ClassType type;
  final String className;
  final List<FieldInfo> fields;
  final DartType? identityType;
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
