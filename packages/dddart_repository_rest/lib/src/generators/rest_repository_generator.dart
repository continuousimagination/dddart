import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart/dddart.dart';
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

    final classElement = element;
    final className = classElement.name;

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use @GenerateRestRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use @GenerateRestRepository.',
        element: element,
      );
    }

    final identityType = _concreteIdentityType(classElement);

    // Extract configuration from annotation
    final resourcePath = _extractResourcePath(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);

    // Determine what to generate based on interface analysis
    if (customInterface == null) {
      // No custom interface - generate concrete class
      return _generateConcreteRepository(className, resourcePath, identityType);
    }

    // Analyze interface to determine if abstract base is needed
    final interfaceMethods = _getInterfaceMethods(customInterface);
    final baseRepositoryMethods = {'getById', 'save', 'deleteById'};
    final objectMethods = {
      'toString',
      'hashCode',
      'noSuchMethod',
      'runtimeType',
      '==',
      'hash',
      'hashAll',
      'hashAllUnordered',
    };
    final customMethods = interfaceMethods
        .where(
          (m) =>
              !baseRepositoryMethods.contains(m.name) &&
              !objectMethods.contains(m.name) &&
              !m.isOperator &&
              !m.isStatic,
        )
        .toList();

    if (customMethods.isEmpty) {
      // Interface only has base Repository methods - generate concrete class
      return _generateConcreteRepository(
        className,
        resourcePath,
        identityType,
        implements: customInterface,
      );
    } else {
      // Interface has custom methods - generate abstract base class
      return _generateAbstractBaseRepository(
        className,
        resourcePath,
        identityType,
        implements: customInterface,
        abstractMethods: customMethods,
      );
    }
  }

  /// Validates that a class extends AggregateRoot.
  ///
  /// Walks the inheritance hierarchy to find AggregateRoot.
  bool _extendsAggregateRoot(ClassElement element) {
    return element.allSupertypes.any(
      (type) =>
          const TypeChecker.fromRuntime(AggregateRoot).isExactly(type.element),
    );
  }

  String _concreteIdentityType(ClassElement element) {
    final root = element.allSupertypes.firstWhere(
      (type) =>
          const TypeChecker.fromRuntime(AggregateRoot).isExactly(type.element),
    );
    final identity = root.typeArguments.single;
    if (element.typeParameters.isNotEmpty ||
        identity is! InterfaceType ||
        const TypeChecker.fromRuntime(Identity).isExactly(identity.element)) {
      throw InvalidGenerationSourceError(
        'Repository generation requires a concrete identity type.',
        element: element,
      );
    }
    return identity.getDisplayString(withNullability: false);
  }

  /// Validates that a class has the @Serializable annotation.
  bool _hasSerializableAnnotation(ClassElement element) {
    return element.metadata.any((annotation) {
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
  /// - User → /users
  /// - OrderItem → /order-items
  /// - Company → /companies
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
      return '/${kebab.substring(0, kebab.length - 1)}ies';
    } else if (kebab.endsWith('s') ||
        kebab.endsWith('x') ||
        kebab.endsWith('ch')) {
      return '/${kebab}es';
    } else {
      return '/${kebab}s';
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
  /// (including Repository<T, UuidValue>), but excludes methods from Object and other
  /// system classes.
  List<MethodElement> _getInterfaceMethods(InterfaceType interfaceType) {
    final methods = <String, MethodElement>{};

    // Get methods from the interface itself
    for (final method in interfaceType.methods) {
      methods.putIfAbsent(method.name, () => method);
    }

    // Get methods from all superinterfaces (including Repository<T, UuidValue>)
    // but exclude Object and system classes
    for (final supertype in interfaceType.allSupertypes) {
      final supertypeName = supertype.element.name;
      // Skip Object and system classes
      if (supertypeName == 'Object' ||
          supertypeName.startsWith('_') ||
          supertype.element.library.name.startsWith('dart.')) {
        continue;
      }
      for (final method in supertype.methods) {
        methods.putIfAbsent(method.name, () => method);
      }
    }

    return methods.values.toList();
  }

  /// Generates a concrete repository class implementation.
  ///
  /// This is used when:
  /// - No custom interface is specified
  /// - Custom interface only contains base Repository<T, UuidValue> methods
  ///
  /// The generated class can be instantiated directly.
  String _generateConcreteRepository(
    String className,
    String resourcePath,
    String identityType, {
    InterfaceType? implements,
  }) {
    final interfaceClause = implements != null
        ? 'implements ${implements.element.name}'
        : 'implements Repository<$className, $identityType>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated REST repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class can be used directly for basic CRUD operations or extended',
    );
    buffer.writeln('/// to add custom query methods.');
    buffer.writeln('class ${className}RestRepository $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A REST connection to the API server.');
    buffer.writeln(
        '  ${className}RestRepository(this._connection, {IdentityCodecRegistry? identityCodecs}) : _identityCodecs = identityCodecs ?? IdentityCodecRegistry();');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The REST connection instance.');
    buffer.writeln('  final RestConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The resource path for $className aggregates.');
    buffer.writeln("  String get _resourcePath => '$resourcePath';");
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final IdentityCodecRegistry _identityCodecs;');
    buffer.writeln(
        '  late final _serializer = ${className}JsonSerializer.withIdentityCodecs(_identityCodecs);');
    buffer.writeln(_generateIdentityUri(identityType));
    buffer.writeln();

    // Generate CRUD methods
    buffer.writeln(_generateGetByIdMethod(className, identityType));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className, identityType));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className, identityType));
    buffer.writeln();

    // Generate exception mapping helper
    buffer.writeln(_generateMapHttpExceptionMethod());

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates an abstract base repository class.
  ///
  /// This is used when a custom interface contains methods beyond the base
  /// Repository<T, UuidValue> interface. The generated abstract class implements the
  /// base CRUD methods and declares custom methods as abstract.
  ///
  /// Developers must extend this class and implement the custom methods.
  String _generateAbstractBaseRepository(
    String className,
    String resourcePath,
    String identityType, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
  }) {
    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated abstract base REST repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This abstract class implements the base `Repository<$className, $identityType>` methods',
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
      'abstract class ${className}RestRepositoryBase implements ${implements.element.name} {',
    );

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A REST connection to the API server.');
    buffer.writeln(
        '  ${className}RestRepositoryBase(this._connection, {IdentityCodecRegistry? identityCodecs}) : _identityCodecs = identityCodecs ?? IdentityCodecRegistry();');
    buffer.writeln();

    // Generate fields and getters (same as concrete class)
    buffer.writeln('  /// The REST connection instance.');
    buffer.writeln('  final RestConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The resource path for $className aggregates.');
    buffer.writeln("  String get _resourcePath => '$resourcePath';");
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final IdentityCodecRegistry _identityCodecs;');
    buffer.writeln(
        '  late final _serializer = ${className}JsonSerializer.withIdentityCodecs(_identityCodecs);');
    buffer.writeln(_generateIdentityUri(identityType));
    buffer.writeln();

    // Generate concrete implementations of base Repository methods
    buffer.writeln(_generateGetByIdMethod(className, identityType));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className, identityType));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className, identityType));
    buffer.writeln();

    buffer.writeln(_generateMapHttpExceptionMethod());
    buffer.writeln();

    // Add abstract method declarations for custom methods
    if (abstractMethods.isNotEmpty) {
      buffer.writeln('  // Custom methods (must be implemented by subclass)');
      buffer.writeln();
      for (final method in abstractMethods) {
        buffer.writeln('  @override');
        buffer.writeln('  ${_generateMethodSignature(method)};');
        buffer.writeln();
      }
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _generateIdentityUri(String identityType) => '''
  Uri _identityUri($identityType id) {
    try {
      final key = _identityCodecs.toKey<$identityType>(id);
      return _connection.identityUri(_resourcePath, key);
    } catch (error) {
      if (error is RepositoryException) rethrow;
      throw RepositoryException(
        'Invalid REST identity key',
        type: RepositoryExceptionType.constraint,
        cause: error,
      );
    }
  }''';

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(String className, String identityType) {
    return '''
  @override
  Future<$className> getById($identityType id) async {
    try {
      final uri = _identityUri(id);
      final response = await _connection.executeRequest(
        () => _connection.client.get(
          uri,
          headers: {'Accept': 'application/json'},
        ),
        operation: 'retrieve $className',
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final aggregate = _serializer.fromJson(json);
        if (aggregate.id != id) {
          throw const RepositoryException(
            'Response identity does not match requested identity',
            type: RepositoryExceptionType.constraint,
          );
        }
        return aggregate;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve $className: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the save method implementation.
  String _generateSaveMethod(String className, String identityType) {
    return '''
  @override
  Future<void> save($className aggregate) async {
    try {
      final uri = _identityUri(aggregate.id);
      final json = _serializer.toJson(aggregate);
      final body = jsonEncode(json);
      
      final response = await _connection.executeRequest(
        () => _connection.client.put(
          uri,
          body: body,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
        operation: 'save $className',
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to save $className: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the deleteById method implementation.
  String _generateDeleteByIdMethod(String className, String identityType) {
    return '''
  @override
  Future<void> deleteById($identityType id) async {
    try {
      final uri = _identityUri(id);
      final response = await _connection.executeRequest(
        () => _connection.client.delete(
          uri,
          headers: {'Accept': 'application/json'},
        ),
        operation: 'delete $className',
      );
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to delete $className: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the HTTP exception mapping helper method.
  String _generateMapHttpExceptionMethod() {
    return r'''
  /// Maps HTTP status codes to RepositoryException types.
  ///
  /// Attempts to parse RFC 7807 Problem Details format from the response body
  /// to extract the 'detail' field for more specific error messages.
  RepositoryException _mapHttpException(int statusCode, String body) {
    // Try to parse RFC 7807 Problem Details format
    String? detail;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      detail = json['detail'] as String?;
    } catch (_) {
      // If parsing fails, use the raw body
    }

    switch (statusCode) {
      case 401:
        return RepositoryException(
          detail ?? 'Unauthorized: Authentication required or token expired',
          type: RepositoryExceptionType.unauthorized,
        );
      case 403:
        return RepositoryException(
          detail ?? 'Forbidden: You do not have permission to perform this action',
          type: RepositoryExceptionType.forbidden,
        );
      case 404:
        return RepositoryException(
          detail ?? 'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      case 409:
        return RepositoryException(
          detail ?? 'Duplicate resource',
          type: RepositoryExceptionType.duplicate,
        );
      case 400:
      case 422:
        return RepositoryException(
          detail ?? 'Repository constraint violated',
          type: RepositoryExceptionType.constraint,
        );
      case 408:
      case 504:
        return RepositoryException(
          detail ?? 'Request timeout',
          type: RepositoryExceptionType.timeout,
        );
      case >= 500:
        return RepositoryException(
          detail ?? 'Server error: $statusCode',
          type: RepositoryExceptionType.connection,
        );
      default:
        return RepositoryException(
          detail ?? 'HTTP error $statusCode: $body',
          type: RepositoryExceptionType.unknown,
        );
    }
  }''';
  }

  /// Generates a method signature from a MethodElement.
  ///
  /// Includes return type, method name, and parameters with types.
  String _generateMethodSignature(MethodElement method) {
    final returnType =
        method.returnType.getDisplayString(withNullability: true);
    final typeParameters = method.typeParameters.isEmpty
        ? ''
        : '<${method.typeParameters.map(_formatTypeParameter).join(', ')}>';

    final requiredPositional = method.parameters
        .where((parameter) => parameter.isRequiredPositional)
        .map(_formatParameter)
        .toList();
    final optionalPositional = method.parameters
        .where((parameter) => parameter.isOptionalPositional)
        .map(_formatParameter)
        .toList();
    final named = method.parameters
        .where((parameter) => parameter.isNamed)
        .map(_formatParameter)
        .toList();

    final parameterSections = <String>[
      ...requiredPositional,
      if (optionalPositional.isNotEmpty) '[${optionalPositional.join(', ')}]',
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ];

    return '$returnType ${method.name}$typeParameters'
        '(${parameterSections.join(', ')})';
  }

  String _formatParameter(ParameterElement parameter) {
    final buffer = StringBuffer();
    if (parameter.isRequiredNamed) {
      buffer.write('required ');
    }
    if (parameter.isCovariant) {
      buffer.write('covariant ');
    }
    parameter.appendToWithoutDelimiters(buffer, withNullability: true);
    return buffer.toString();
  }

  String _formatTypeParameter(TypeParameterElement parameter) {
    final bound = parameter.bound;
    if (bound == null) {
      return parameter.name;
    }
    return '${parameter.name} extends '
        '${bound.getDisplayString(withNullability: true)}';
  }
}

/// Builder function for build_runner integration.
///
/// This function is referenced in build.yaml and called by build_runner
/// to create the generator.
Builder restRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [RestRepositoryGenerator()],
    'rest_repository',
  );
}
