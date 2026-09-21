/// Code generator for DynamoDB repository implementations.
library;

import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
// ignore_for_file: deprecated_member_use, avoid_redundant_argument_values

import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_dynamodb/src/annotations/generate_dynamo_repository.dart';
import 'package:source_gen/source_gen.dart';

/// Builder factory function for the DynamoDB repository generator.
///
/// This function is referenced in build.yaml and creates the builder
/// that generates DynamoDB repository implementations.
///
/// The builder uses [SharedPartBuilder] to generate `.dynamo_repository.g.dart`
/// files for classes annotated with [@GenerateDynamoRepository].
Builder dynamoRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder([DynamoRepositoryGenerator()], 'dynamo_repository');
}

/// Generator for DynamoDB repository implementations.
///
/// This generator processes classes annotated with [GenerateDynamoRepository]
/// and generates DynamoDB repository implementations that leverage existing
/// JSON serialization from dddart_json.
class DynamoRepositoryGenerator
    extends GeneratorForAnnotation<GenerateDynamoRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateDynamoRepository.',
        element: element,
      );
    }

    final external = _annotationType(annotation, 'aggregateType', element);
    final classElement = external?.element as ClassElement? ?? element;
    final className = classElement.name!;

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use '
        '@GenerateDynamoRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (external == null && !_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use '
        '@GenerateDynamoRepository.',
        element: element,
      );
    }

    // Extract configuration from annotation
    final tableName = _extractTableName(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);

    final modelType = external ?? classElement.thisType;
    final serializer = _annotationType(annotation, 'serializerType', element);
    final baseName =
        annotation.peek('generatedBaseName')?.literalValue as String? ??
        className;
    if (!RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(baseName)) {
      throw InvalidGenerationSourceError(
        'generatedBaseName must be a public class-name stem',
        element: element,
      );
    }
    if (external != null && serializer == null) {
      throw InvalidGenerationSourceError(
        'serializerType is required and must resolve; build the shared model/serializer package before the adapter (same-target generated types are unsupported)',
        element: element,
      );
    }
    if (serializer != null) {
      final serializerClass = serializer.element;
      if (serializerClass is! ClassElement ||
          serializerClass.isPrivate ||
          serializerClass.isAbstract ||
          serializerClass.unnamedConstructor == null ||
          serializerClass.unnamedConstructor!.formalParameters.any(
            (p) => p.isRequiredNamed || p.isRequiredPositional,
          ) ||
          !serializer.allSupertypes.any(
            (type) =>
                _isDeclaration(
                  type,
                  'package:dddart_json/src/json_serializer.dart',
                  'JsonSerializer',
                ) &&
                type.typeArguments.length == 1 &&
                type.typeArguments.single == modelType,
          )) {
        throw InvalidGenerationSourceError(
          'serializerType must be a public concrete JsonSerializer<$className> with an argument-free constructor',
          element: element,
        );
      }
    }
    if (customInterface != null &&
        (customInterface.nullabilitySuffix == NullabilitySuffix.question ||
            ![customInterface, ...customInterface.allSupertypes].any(
              (type) =>
                  _isDeclaration(
                    type,
                    'package:dddart/src/repository.dart',
                    'Repository',
                  ) &&
                  type.typeArguments.length == 1 &&
                  type.typeArguments.single == modelType,
            ))) {
      throw InvalidGenerationSourceError(
        'implements must be a Repository<$className> interface',
        element: element,
      );
    }
    final aggregateName = _visibleType(modelType, element.library);
    final serializerName = serializer == null
        ? '${className}JsonSerializer'
        : _visibleType(serializer, element.library);
    final interfaceName = customInterface == null
        ? null
        : _visibleType(customInterface, element.library);
    final methods = customInterface == null
        ? <MethodElement>[]
        : _getInterfaceMethods(customInterface);
    const baseMethods = {
      'getById',
      'save',
      'deleteById',
      'toString',
      'hashCode',
      'noSuchMethod',
      'runtimeType',
      '==',
      'hash',
      'hashAll',
      'hashAllUnordered',
    };
    final custom = <String, MethodElement>{};
    for (final method in methods) {
      if (!baseMethods.contains(method.name) &&
          !method.isOperator &&
          !method.isStatic) {
        custom.putIfAbsent(method.name!, () => method);
      }
    }
    if (custom.isEmpty) {
      return _generateConcreteRepository(
        aggregateName,
        tableName,
        implements: customInterface,
        repositoryName: '${baseName}DynamoRepository',
        serializerName: serializerName,
        interfaceName: interfaceName,
      );
    }
    return _generateAbstractBaseRepository(
      aggregateName,
      tableName,
      implements: customInterface!,
      abstractMethods: custom.values.toList(),
      scope: element.library,
      repositoryName: '${baseName}DynamoRepositoryBase',
      serializerName: serializerName,
      interfaceName: interfaceName!,
    );
  }

  bool _isDeclaration(InterfaceType type, String uri, String name) =>
      type.element.name == name && type.element.library.uri.toString() == uri;

  InterfaceType? _annotationType(
    ConstantReader annotation,
    String field,
    Element owner,
  ) {
    final value = annotation.peek(field);
    if (value == null || value.isNull) return null;
    final type = value.typeValue;
    if (type is! InterfaceType ||
        type.element is! ClassElement ||
        type.element.isPrivate ||
        type.nullabilitySuffix == NullabilitySuffix.question) {
      throw InvalidGenerationSourceError(
        '$field must name a public class',
        element: owner,
      );
    }
    return type;
  }

  String _visibleType(InterfaceType type, LibraryElement scope) {
    final element = type.element;
    var name = element.name!;
    if (element.library != scope && element.library.uri.scheme != 'dart') {
      String? visible;
      for (final imported in scope.firstFragment.libraryImports) {
        for (final entry in imported.namespace.definedNames2.entries) {
          if (entry.value != element) continue;
          final prefix = imported.prefix?.name;
          visible = prefix == null || entry.key.startsWith('$prefix.')
              ? entry.key
              : '$prefix.${entry.key}';
          break;
        }
        if (visible != null) break;
      }
      if (visible == null) {
        throw InvalidGenerationSourceError(
          'Type $name must be publicly imported into the adapter binding library',
        );
      }
      name = visible;
    }
    if (type.typeArguments.isNotEmpty) {
      name +=
          '<${type.typeArguments.map((argument) => _renderType(argument, scope)).join(', ')}>';
    }
    return type.nullabilitySuffix == NullabilitySuffix.question
        ? '$name?'
        : name;
  }

  /// Validates that a class extends AggregateRoot.
  ///
  /// Walks the inheritance hierarchy to find AggregateRoot.
  bool _extendsAggregateRoot(ClassElement element) {
    ClassElement? current = element;
    while (current != null) {
      if (current.name == 'AggregateRoot' &&
          current.library.uri.toString() ==
              'package:dddart/src/aggregate_root.dart') {
        return true;
      }
      final supertype = current.supertype;
      if (supertype == null) break;
      current = supertype.element as ClassElement?;
    }
    return false;
  }

  /// Validates that a class has the @Serializable annotation.
  bool _hasSerializableAnnotation(ClassElement element) {
    return element.metadata.annotations.any((annotation) {
      final value = annotation.computeConstantValue();
      if (value == null) return false;
      final typeName = value.type?.element?.name;
      return typeName == 'Serializable';
    });
  }

  /// Extracts the table name from the annotation or generates a default.
  ///
  /// If `tableName` is provided in the annotation, uses that value.
  /// Otherwise, converts the class name to snake_case.
  String _extractTableName(ConstantReader annotation, String className) {
    final tableName = annotation.peek('tableName')?.stringValue;
    final selected = tableName ?? _toSnakeCase(className);
    if (selected.length < 3 ||
        selected.length > 255 ||
        selected.startsWith('aws.') ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(selected)) {
      throw InvalidGenerationSourceError(
        'tableName must satisfy DynamoDB table naming rules',
      );
    }
    return selected;
  }

  /// Extracts the custom interface type from the annotation.
  ///
  /// Returns null if no custom interface is specified.
  InterfaceType? _extractImplementsInterface(ConstantReader annotation) {
    final implementsField = annotation.peek('implements');
    if (implementsField == null || implementsField.isNull) return null;

    return implementsField.typeValue as InterfaceType?;
  }

  /// Gets all methods from an interface type, including inherited methods.
  ///
  /// This includes methods from the interface itself and all superinterfaces
  /// (including Repository<T>), but excludes methods from Object and other
  /// system classes.
  List<MethodElement> _getInterfaceMethods(InterfaceType interfaceType) {
    final methods = <MethodElement>[];

    // Get methods from the interface itself
    methods.addAll(interfaceType.methods);

    // Get methods from all superinterfaces (including Repository<T>)
    // but exclude Object and system classes
    for (final supertype in interfaceType.allSupertypes) {
      final supertypeName = supertype.element.name!;
      // Skip Object and system classes
      if (supertypeName == 'Object' ||
          supertypeName.startsWith('_') ||
          supertype.element.library.isInSdk) {
        continue;
      }
      methods.addAll(supertype.methods);
    }

    return methods;
  }

  /// Converts a camelCase or PascalCase string to snake_case.
  ///
  /// Examples:
  /// - User → user
  /// - UserProfile → user_profile
  /// - OrderItem → order_item
  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading underscore
  }

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(String className) {
    return '''
  @override
  Future<$className> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );
      
      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          '$className with ID \$id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      // Convert DynamoDB AttributeValue map to JSON
      final json = AttributeValueConverter.attributeMapToJsonMap(response.item!);
      
      return _serializer.fromJson(json);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw _mapDynamoException(e, 'getById');
    }
  }''';
  }

  /// Generates the save method implementation.
  String _generateSaveMethod(String className) {
    return '''
  @override
  Future<void> save($className aggregate) async {
    try {
      final json = _serializer.toJson(aggregate);
      
      // Convert JSON to DynamoDB AttributeValue map
      final item = AttributeValueConverter.jsonMapToAttributeMap(json);
      
      // Upsert operation using PutItem
      await _connection.client.putItem(
        tableName: tableName,
        item: item,
      );
    } catch (e) {
      throw _mapDynamoException(e, 'save');
    }
  }''';
  }

  /// Generates the deleteById method implementation.
  String _generateDeleteByIdMethod(String className) {
    return '''
  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      // First check if item exists
      final getResponse = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
        consistentRead: readConsistency == DynamoReadConsistency.strong,
      );
      
      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          '$className with ID \$id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      // Delete the item
      await _connection.client.deleteItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw _mapDynamoException(e, 'deleteById');
    }
  }''';
  }

  /// Generates the getAll method implementation (full table scan).
  String _generateGetAllMethod(String className) {
    return '''
  @override
  Future<List<$className>> getAll() async {
    try {
      final response = await _connection.client.scan(
        tableName: tableName,
      );

      if (response.items == null || response.items!.isEmpty) {
        return [];
      }

      return response.items!.map((item) {
        final json = AttributeValueConverter.attributeMapToJsonMap(item);
        return _serializer.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapDynamoException(e, 'getAll');
    }
  }''';
  }

  /// Generates the DynamoDB exception mapping helper method.
  String _generateMapDynamoExceptionMethod() {
    return '''
  /// Maps typed SDK failures without exposing provider data or raw causes.
  RepositoryException _mapDynamoException(Object error, String operation) {
    return DynamoRepositoryException.map(error, operation);
  }
''';
  }

  /// Generates table creation utility methods.
  ///
  /// Includes:
  /// - createTable: Instance method to execute table creation
  /// - getCreateTableCommand: Returns AWS CLI command string
  /// - getCloudFormationTemplate: Returns CloudFormation YAML snippet
  String _generateTableCreationMethods(
    String repositoryName,
    String tableName,
  ) {
    return '''
  /// Creates the DynamoDB table for this repository.
  ///
  /// This is a convenience method that uses the connection's client to
  /// create the table with the appropriate schema.
  ///
  /// Throws [RepositoryException] if table creation fails.
  ///
  /// Example:
  /// ```dart
  /// final repo = $repositoryName(connection);
  /// await repo.createTable();
  /// ```
  Future<void> createTable() async {
    try {
      await _connection.client.createTable(
        tableName: tableName,
        keySchema: [
          KeySchemaElement(
            attributeName: 'id',
            keyType: KeyType.hash,
          ),
        ],
        attributeDefinitions: [
          AttributeDefinition(
            attributeName: 'id',
            attributeType: ScalarAttributeType.s,
          ),
        ],
        billingMode: BillingMode.payPerRequest,
      );
    } catch (e) {
      throw _mapDynamoException(e, 'createTable');
    }
  }

  /// Returns an AWS CLI command to create this table.
  ///
  /// This command can be executed in a terminal to create the table
  /// using the AWS CLI.
  ///
  /// Example:
  /// ```dart
  /// final command = $repositoryName.getCreateTableCommand('$tableName');
  /// print(command);
  /// // Copy and paste into terminal
  /// ```
  static String getCreateTableCommand(String tableName) {
    return \'\'\'
aws dynamodb create-table \\\\
  --table-name \$tableName \\\\
  --attribute-definitions AttributeName=id,AttributeType=S \\\\
  --key-schema AttributeName=id,KeyType=HASH \\\\
  --billing-mode PAY_PER_REQUEST
\'\'\'.trim();
  }

  /// Returns a CloudFormation YAML template for this table.
  ///
  /// This template can be included in a CloudFormation stack to
  /// provision the table as infrastructure as code.
  ///
  /// Example:
  /// ```dart
  /// final template = $repositoryName.getCloudFormationTemplate('$tableName');
  /// print(template);
  /// // Add to CloudFormation template
  /// ```
  static String getCloudFormationTemplate(String tableName) {
    return \'\'\'
Resources:
  \\\${tableName.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join()}Table:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: \$tableName
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      BillingMode: PAY_PER_REQUEST
\'\'\'.trim();
  }''';
  }

  /// Generates a concrete repository class implementation.
  ///
  /// This is used when:
  /// - No custom interface is specified
  /// - Custom interface only contains base Repository<T> methods
  ///
  /// The generated class can be instantiated directly.
  String _generateConcreteRepository(
    String className,
    String tableName, {
    required String repositoryName,
    required String serializerName,
    InterfaceType? implements,
    String? interfaceName,
  }) {
    final interfaceClause = implements != null
        ? 'implements $interfaceName'
        : 'implements QueryableRepository<$className>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated DynamoDB repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class can be used directly for basic CRUD operations or',
    );
    buffer.writeln('/// extended');
    buffer.writeln('/// to add custom query methods.');
    buffer.writeln('class $repositoryName $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A DynamoDB connection instance.');
    buffer.writeln('''
  $repositoryName(this._connection, {
    this.readConsistency = DynamoReadConsistency.eventual,
    String? tableName,
  }) : tableName = tableName ?? '$tableName' {
    if (tableName != null &&
        (tableName.length < 3 || tableName.length > 255 ||
         tableName.startsWith('aws.') ||
         !RegExp(r'^[A-Za-z0-9_.-]+\$').hasMatch(tableName))) {
      throw ArgumentError('Invalid DynamoDB table name');
    }
  }
  /// Point-read consistency policy.
  final DynamoReadConsistency readConsistency;
''');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The DynamoDB connection instance.');
    buffer.writeln('  final DynamoConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln('  final String tableName;');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = $serializerName();');
    buffer.writeln();

    // Generate CRUD methods
    buffer.writeln(_generateGetByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className));
    buffer.writeln();
    buffer.writeln(_generateGetAllMethod(className));
    buffer.writeln();
    // Generate exception mapping helper
    buffer.writeln(_generateMapDynamoExceptionMethod());
    buffer.writeln();

    // Generate table creation utilities
    buffer.writeln(_generateTableCreationMethods(repositoryName, tableName));

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates an abstract base repository class.
  ///
  /// This is used when a custom interface contains methods beyond the base
  /// Repository<T> interface. The generated abstract class implements the
  /// base CRUD methods and declares custom methods as abstract.
  ///
  /// Developers must extend this class and implement the custom methods.
  String _generateAbstractBaseRepository(
    String className,
    String tableName, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
    required LibraryElement scope,
    required String repositoryName,
    required String serializerName,
    required String interfaceName,
  }) {
    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated abstract base DynamoDB repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This abstract class implements the base Repository<$className> methods',
    );
    buffer.writeln(
      '/// (getById, save, deleteById) and declares custom methods as abstract.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// Extend this class and implement the abstract methods to complete',
    );
    buffer.writeln('/// the repository implementation.');
    buffer.writeln(
      'abstract class $repositoryName implements $interfaceName {',
    );

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A DynamoDB connection instance.');
    buffer.writeln('''
  $repositoryName(this._connection, {
    this.readConsistency = DynamoReadConsistency.eventual,
    String? tableName,
  }) : tableName = tableName ?? '$tableName' {
    if (tableName != null &&
        (tableName.length < 3 || tableName.length > 255 ||
         tableName.startsWith('aws.') ||
         !RegExp(r'^[A-Za-z0-9_.-]+\$').hasMatch(tableName))) {
      throw ArgumentError('Invalid DynamoDB table name');
    }
  }
  /// Point-read consistency policy.
  final DynamoReadConsistency readConsistency;
''');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The DynamoDB connection instance.');
    buffer.writeln('  final DynamoConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln('  final String tableName;');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = $serializerName();');
    buffer.writeln();

    // Generate concrete implementations of base Repository methods
    buffer.writeln(_generateGetByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateGetAllMethod(className));
    buffer.writeln();

    // Generate exception mapping helper
    buffer.writeln(_generateMapDynamoExceptionMethod());
    buffer.writeln();

    // Generate table creation utilities
    buffer.writeln(_generateTableCreationMethods(repositoryName, tableName));
    buffer.writeln();

    // Add abstract method declarations for custom methods
    if (abstractMethods.isNotEmpty) {
      buffer.writeln('  // Custom methods (must be implemented by subclass)');
      buffer.writeln();
      for (final method in abstractMethods) {
        buffer.writeln('  @override');
        buffer.writeln('  ${_generateMethodSignature(method, scope)};');
        buffer.writeln();
      }
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a method signature from a MethodElement.
  ///
  /// Includes return type, method name, and parameters with types.
  String _generateMethodSignature(MethodElement method, LibraryElement scope) {
    final generics = _typeParameters(method.typeParameters, scope);
    return '${_renderType(method.returnType, scope)} ${method.name}$generics(${_parameters(method.formalParameters, scope)})';
  }

  String _renderType(DartType type, LibraryElement scope) {
    if (type is InterfaceType) return _visibleType(type, scope);
    if (type is FunctionType) {
      final nullable = type.nullabilitySuffix == NullabilitySuffix.question
          ? '?'
          : '';
      return '${_renderType(type.returnType, scope)} Function${_typeParameters(type.typeParameters, scope)}(${_parameters(type.formalParameters, scope)})$nullable';
    }
    if (type is RecordType) {
      throw InvalidGenerationSourceError(
        'Record-valued custom signatures are not supported',
      );
    }
    return type.getDisplayString();
  }

  String _typeParameters(
    List<TypeParameterElement> parameters,
    LibraryElement scope,
  ) {
    if (parameters.isEmpty) return '';
    return '<${parameters.map((p) => '${p.name}${p.bound == null ? '' : ' extends ${_renderType(p.bound!, scope)}'}').join(', ')}>';
  }

  String _defaultLiteral(
    FormalParameterElement parameter,
    LibraryElement scope,
  ) {
    final value = parameter.computeConstantValue();
    if (value == null) {
      throw InvalidGenerationSourceError(
        'Cannot resolve default for ${parameter.name}',
      );
    }
    if (value.isNull) return 'null';
    final string = value.toStringValue();
    if (string != null) return jsonEncode(string).replaceAll(r'$', r'\$');
    final boolean = value.toBoolValue();
    if (boolean != null) return '$boolean';
    final integer = value.toIntValue();
    if (integer != null) return '$integer';
    final decimal = value.toDoubleValue();
    if (decimal != null && decimal.isFinite) return '$decimal';
    final type = value.type;
    if (type is InterfaceType && type.element is EnumElement) {
      final index = value.getField('index')?.toIntValue();
      for (final field in type.element.fields.where(
        (field) => field.isEnumConstant,
      )) {
        if (field.computeConstantValue()?.getField('index')?.toIntValue() ==
                index &&
            index != null) {
          return '${_visibleType(type, scope)}.${field.name}';
        }
      }
    }
    throw InvalidGenerationSourceError(
      'Unsupported default for ${parameter.name}; use a primitive, null, or publicly imported enum constant',
    );
  }

  String _parameters(
    List<FormalParameterElement> parameters,
    LibraryElement scope,
  ) {
    final positional = <String>[];
    final optional = <String>[];
    final named = <String>[];
    for (final parameter in parameters) {
      var code =
          '${parameter.isRequiredNamed ? 'required ' : ''}${_renderType(parameter.type, scope)}${parameter.name == null || parameter.name!.isEmpty ? '' : ' ${parameter.name}'}';
      if (parameter.defaultValueCode != null) {
        code += ' = ${_defaultLiteral(parameter, scope)}';
      }
      if (parameter.isNamed) {
        named.add(code);
      } else if (parameter.isOptionalPositional) {
        optional.add(code);
      } else {
        positional.add(code);
      }
    }
    return [
      ...positional,
      if (optional.isNotEmpty) '[${optional.join(', ')}]',
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ].join(', ');
  }
}
