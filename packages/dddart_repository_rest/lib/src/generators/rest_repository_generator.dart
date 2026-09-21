import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_rest/src/annotations/generate_rest_repository.dart';
import 'package:source_gen/source_gen.dart';

/// Code generator for REST repository implementations.
///
/// This generator processes [GenerateRestRepository] annotations and
/// generates repository implementations that communicate with REST APIs
/// via HTTP.
///
/// The generator validates that:
/// - The annotated element is a class
/// - The class extends AggregateRoot
/// - The class has a @Serializable annotation
///
/// Based on the annotation parameters, it generates either:
/// - A concrete repository class (if no custom interface or only base methods)
/// - An abstract base class (if custom interface with additional methods)
class RestRepositoryGenerator
    extends GeneratorForAnnotation<GenerateRestRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateRestRepository.',
        element: element,
      );
    }

    final external = _annotationType(annotation, 'aggregateType', element);
    final classElement = external?.element as ClassElement? ?? element;
    final className = classElement.name!;
    final conditional =
        annotation.peek('conditionalWrites')?.boolValue ?? false;
    final versioned = classElement.allSupertypes.any(
      (type) => _isDeclaration(
        type,
        'package:dddart/src/versioned_aggregate_root.dart',
        'VersionedAggregateRoot',
      ),
    );
    if (conditional != versioned) {
      throw InvalidGenerationSourceError(
        'conditionalWrites must be true exactly for versioned aggregate roots.',
        element: element,
      );
    }
    if (conditional) _validateRevisionAuthority(classElement);

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use @GenerateRestRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (external == null && !_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use @GenerateRestRepository.',
        element: element,
      );
    }

    // Extract configuration from annotation
    final resourcePath = _extractResourcePath(annotation, className);
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
                    conditional
                        ? 'package:dddart/src/conditional_repository.dart'
                        : 'package:dddart/src/repository.dart',
                    conditional ? 'ConditionalRepository' : 'Repository',
                  ) &&
                  type.typeArguments.length == 1 &&
                  type.typeArguments.single == modelType,
            ))) {
      throw InvalidGenerationSourceError(
        'implements must match the selected conditional or ordinary Repository<$className> contract',
        element: element,
      );
    }
    if (conditional && customInterface != null) {
      _validateConditionalPort(customInterface, modelType, element);
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
          !method.isStatic)
        custom.putIfAbsent(method.name!, () => method);
    }
    if (conditional) {
      return _generateConditionalRepository(
        aggregateName,
        serializerName,
        '${baseName}RestRepository',
        resourcePath,
        interfaceName,
        custom.values.toList(),
        element.library,
      );
    }
    if (custom.isEmpty) {
      return _generateConcreteRepository(
        aggregateName,
        resourcePath,
        implements: customInterface,
        repositoryName: '${baseName}RestRepository',
        serializerName: serializerName,
        interfaceName: interfaceName,
      );
    }
    return _generateAbstractBaseRepository(
      aggregateName,
      resourcePath,
      implements: customInterface!,
      abstractMethods: custom.values.toList(),
      scope: element.library,
      repositoryName: '${baseName}RestRepositoryBase',
      serializerName: serializerName,
      interfaceName: interfaceName!,
    );
  }

  void _validateConditionalPort(
    InterfaceType port,
    InterfaceType model,
    Element owner,
  ) {
    final canonical = [port, ...port.allSupertypes].firstWhere(
      (type) =>
          _isDeclaration(
            type,
            'package:dddart/src/conditional_repository.dart',
            'ConditionalRepository',
          ) &&
          type.typeArguments.single == model,
    );
    for (final name in ['getById', 'save', 'deleteById']) {
      final expected = canonical.getMethod(name)!;
      // InterfaceType lookup retains generic substitution and selects the
      // effective declaration, including inherited/custom-interface members.
      final actual = port.lookUpMethod(name, owner.library!);
      if (actual == null || !_sameCrudSignature(actual, expected)) {
        throw InvalidGenerationSourceError(
          'Custom conditional member $name must match ConditionalRepository<${model.getDisplayString()}> exactly.',
          element: actual ?? owner,
        );
      }
    }
  }

  bool _sameCrudSignature(MethodElement actual, MethodElement expected) {
    if (actual.typeParameters.length != expected.typeParameters.length ||
        actual.returnType != expected.returnType ||
        actual.formalParameters.length != expected.formalParameters.length) {
      return false;
    }
    final actualPositional = actual.formalParameters
        .where((p) => p.isPositional)
        .toList();
    final expectedPositional = expected.formalParameters
        .where((p) => p.isPositional)
        .toList();
    if (actualPositional.length != expectedPositional.length) return false;
    for (var index = 0; index < expectedPositional.length; index++) {
      final a = actualPositional[index];
      final e = expectedPositional[index];
      if (a.type != e.type ||
          a.isRequiredPositional != e.isRequiredPositional) {
        return false;
      }
    }
    final named = {
      for (final p in actual.formalParameters.where((p) => p.isNamed))
        p.name: p,
    };
    for (final e in expected.formalParameters.where((p) => p.isNamed)) {
      final a = named[e.name];
      if (a == null ||
          a.type != e.type ||
          a.isRequiredNamed != e.isRequiredNamed) {
        return false;
      }
    }
    return true;
  }

  void _validateRevisionAuthority(ClassElement element) {
    InterfaceType? current = element.thisType;
    while (current != null &&
        !_isDeclaration(
          current,
          'package:dddart/src/versioned_aggregate_root.dart',
          'VersionedAggregateRoot',
        )) {
      if (current.element.fields.any(
        (field) => field.name == 'revision' || field.name == '__dddart_retired',
      )) {
        throw InvalidGenerationSourceError(
          'Reserved revision or retirement metadata is overridden.',
          element: element,
        );
      }
      current = current.superclass;
    }
    final canonical = current?.element.getGetter('revision');
    if (canonical == null ||
        element
                .lookUpGetter(name: 'revision', library: element.library)
                ?.baseElement !=
            canonical.baseElement) {
      throw InvalidGenerationSourceError(
        'The canonical inherited revision authority is required.',
        element: element,
      );
    }
  }

  String _generateConditionalRepository(
    String model,
    String codec,
    String name,
    String location,
    String? port,
    List<MethodElement> methods,
    LibraryElement scope,
  ) {
    final abstract = methods.isNotEmpty;
    final generatedName = abstract ? '${name}Base' : name;
    final literal = _stringLiteral(location);
    final buffer = StringBuffer();
    buffer.writeln('/// Generated conditional repository for [$model].');
    buffer.writeln(
      '${abstract ? "abstract " : ""}class $generatedName extends RestConditionalRepository<$model>${port == null ? "" : " implements $port"} {',
    );
    buffer.writeln(
      '  /// Creates the typed conditional adapter using trusted configuration.',
    );
    buffer.writeln('  $generatedName(RestConnection connection)');
    buffer.writeln(
      '      : super(connection, serializer: $codec(), resourcePath: $literal);',
    );
    for (final method in methods) {
      buffer.writeln('  @override');
      buffer.writeln('  ${_generateMethodSignature(method, scope)};');
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  bool _isDeclaration(InterfaceType type, String uri, String name) =>
      type.element.name == name && type.element.library.uri.toString() == uri;

  String _stringLiteral(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n');
    return "'$escaped'";
  }

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
      if (visible == null)
        throw InvalidGenerationSourceError(
          'Type $name must be publicly imported into the adapter binding library',
        );
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
              'package:dddart/src/aggregate_root.dart')
        return true;
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

  /// Extracts the resource path from the annotation or generates a default.
  ///
  /// If `resourcePath` is provided in the annotation, uses that value.
  /// Otherwise, converts the class name to lowercase plural form.
  String _extractResourcePath(ConstantReader annotation, String className) {
    final resourcePath = annotation.peek('resourcePath')?.stringValue;
    return resourcePath ?? _generateResourcePath(className);
  }

  /// Generates a resource path from a class name.
  ///
  /// Converts PascalCase to kebab-case and pluralizes.
  /// Examples:
  /// - User → users
  /// - OrderItem → order-items
  /// - Company → companies
  String _generateResourcePath(String className) {
    // Convert PascalCase to kebab-case
    final kebab = className
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '-${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading dash

    // Simple pluralization
    if (kebab.endsWith('y')) {
      return '${kebab.substring(0, kebab.length - 1)}ies';
    } else if (kebab.endsWith('s') ||
        kebab.endsWith('x') ||
        kebab.endsWith('ch')) {
      return '${kebab}es';
    } else {
      return '${kebab}s';
    }
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

  /// Generates a concrete repository class implementation.
  ///
  /// This is used when:
  /// - No custom interface is specified
  /// - Custom interface only contains base Repository<T> methods
  ///
  /// The generated class can be instantiated directly.
  String _generateConcreteRepository(
    String className,
    String resourcePath, {
    InterfaceType? implements,
    required String repositoryName,
    required String serializerName,
    String? interfaceName,
  }) {
    final interfaceClause = implements != null
        ? 'implements $interfaceName'
        : 'implements Repository<$className>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln('/// Generated REST repository for [$className] aggregate.');
    buffer.writeln('///');
    buffer.writeln(
      '/// This class can be used directly for basic CRUD operations or extended',
    );
    buffer.writeln('/// to add custom query methods.');
    buffer.writeln('class $repositoryName $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A REST connection to the API server.');
    buffer.writeln('  $repositoryName(this._connection);');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The REST connection instance.');
    buffer.writeln('  final RestConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The resource path for $className aggregates.');
    buffer.writeln(
      '  String get _resourcePath => ${_stringLiteral(resourcePath)};',
    );
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

    // Generate exception mapping helper
    buffer.writeln(_generateMapHttpExceptionMethod());

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
    String resourcePath, {
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
      '/// Generated abstract base REST repository for [$className] aggregate.',
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
    buffer.writeln('  /// [connection] - A REST connection to the API server.');
    buffer.writeln('  $repositoryName(this._connection);');
    buffer.writeln();

    // Generate fields and getters (same as concrete class)
    buffer.writeln('  /// The REST connection instance.');
    buffer.writeln('  final RestConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The resource path for $className aggregates.');
    buffer.writeln(
      '  String get _resourcePath => ${_stringLiteral(resourcePath)};',
    );
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

    buffer.writeln(_generateMapHttpExceptionMethod());
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

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(String className) {
    return '''
  @override
  Future<$className> getById(UuidValue id) async {
    try {
      final response = await _connection.client.get(
        Uri.parse('\${_connection.baseUrl}\$_resourcePath/\${id.uuid}'),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _serializer.fromJson(json);
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve $className',
        type: RepositoryExceptionType.unknown,
      );
    }
  }''';
  }

  /// Generates the save method implementation.
  String _generateSaveMethod(String className) {
    return '''
  @override
  Future<void> save($className aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    try {
      final json = _serializer.toJson(aggregate);
      final body = jsonEncode(json);
      
      final response = await _connection.client.put(
        Uri.parse('\${_connection.baseUrl}\$_resourcePath/\${aggregate.id.uuid}'),
        body: body,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to save $className',
        type: RepositoryExceptionType.unknown,
      );
    }
  }''';
  }

  /// Generates the deleteById method implementation.
  String _generateDeleteByIdMethod(String className) {
    return '''
  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final response = await _connection.client.delete(
        Uri.parse('\${_connection.baseUrl}\$_resourcePath/\${id.uuid}'),
      );
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to delete $className',
        type: RepositoryExceptionType.unknown,
      );
    }
  }''';
  }

  /// Generates the HTTP exception mapping helper method.
  String _generateMapHttpExceptionMethod() {
    return r"""
  /// Maps status codes without exposing response bodies or provider text.
  RepositoryException _mapHttpException(int statusCode, String _) {
    switch (statusCode) {
      case 400:
      case 412:
      case 422:
        return RepositoryException('Request validation failed', type: RepositoryExceptionType.constraint);
      case 401:
        return RepositoryException('Authentication required', type: RepositoryExceptionType.unauthorized);
      case 403:
        return RepositoryException('Access denied', type: RepositoryExceptionType.forbidden);
      case 404:
        return RepositoryException('Resource not found', type: RepositoryExceptionType.notFound);
      case 409:
        return RepositoryException('Resource conflict', type: RepositoryExceptionType.duplicate);
      case 408:
      case 504:
        return RepositoryException('Request timed out', type: RepositoryExceptionType.timeout);
      case >= 500:
        return RepositoryException('Remote service failed', type: RepositoryExceptionType.connection);
      default:
        return RepositoryException('Unexpected HTTP response', type: RepositoryExceptionType.unknown);
    }
  }
""";
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

/// Builder function for build_runner integration.
///
/// This function is referenced in build.yaml and called by build_runner
/// to create the generator.
Builder restRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder([RestRepositoryGenerator()], 'rest_repository');
}
