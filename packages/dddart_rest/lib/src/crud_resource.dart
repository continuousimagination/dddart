import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/authorization_handler.dart';
import 'package:dddart_rest/src/etag_generator.dart';
import 'package:dddart_rest/src/http_resource.dart';
import 'package:dddart_rest/src/query_handler.dart';
import 'package:dddart_rest/src/resource_pipeline.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Ordinary repository HTTP CRUD over the shared authenticated request pipeline.
///
/// GET validators describe representations, not atomic write support. Conditional
/// mutation headers and versioned roots require ConditionalCrudResource instead.
class CrudResource<T extends AggregateRoot, TClaims> implements HttpResource {
  /// Freezes trusted resource configuration; both auth handlers may be absent,
  /// but authorization alone and versioned root registrations are refused.
  CrudResource({
    required this.path,
    required this.repository,
    JsonSerializer<T>? serializer,
    Map<String, Serializer<T>>? serializers,
    this.collectionHandler,
    this.authenticationHandler,
    this.authorizationHandler,
    Map<String, QueryHandler<T>> queryHandlers = const {},
    Map<Type, Response Function(Object)> customExceptionHandlers = const {},
    this.defaultSkip = 0,
    this.defaultTake = 50,
    this.maxTake = 100,
    ETagStrategy etagStrategy = ETagStrategy.timestamp,
    this.preCreate,
  }) : serializers = _configureSerializers(serializer, serializers),
       queryHandlers = Map.unmodifiable(queryHandlers),
       customExceptionHandlers = Map.unmodifiable(customExceptionHandlers) {
    // Reified generic type check prevents a legacy view of versioned state.
    // ignore: literal_only_boolean_expressions
    if (<T>[] is List<VersionedAggregateRoot>) {
      throw const RepositoryCapabilityException();
    }
    _pipeline = ResourcePipeline(
      path: path,
      serializers: this.serializers,
      authenticationHandler: authenticationHandler,
      authorizationHandler: authorizationHandler,
      customExceptionHandlers: this.customExceptionHandlers,
      jsonContract: serializer != null,
    );
    _etagGenerator = ETagGenerator<T>(
      strategy: etagStrategy,
      serializer: etagStrategy == ETagStrategy.contentHash
          ? this.serializers.values.first
          : null,
    );
  }
  @override
  final String path;

  /// Ordinary persistence contract, deliberately separate from conditional CRUD.
  final Repository<T> repository;

  /// Immutable configured media types/codecs.
  final Map<String, Serializer<T>> serializers;

  /// Explicit unfiltered query; pagination belongs to the datastore adapter.
  final QueryHandler<T>? collectionHandler;

  /// Canonical JSON codec for resources configured through the JSON constructor.
  JsonSerializer<T> get serializer {
    final value = serializers['application/json'];
    if (value is! JsonSerializer<T>) {
      throw StateError('This legacy resource has no JSON serializer');
    }
    return value;
  }

  static Map<String, Serializer<A>> _configureSerializers<
    A extends AggregateRoot
  >(JsonSerializer<A>? serializer, Map<String, Serializer<A>>? serializers) {
    if ((serializer == null) == (serializers == null)) {
      throw ArgumentError('Provide exactly one serializer or serializers map');
    }
    return Map.unmodifiable(
      serializer == null ? serializers! : {'application/json': serializer},
    );
  }

  /// Trusted optional authenticator.
  final AuthenticationHandler<TClaims>? authenticationHandler;

  /// Trusted optional operation policy.
  final AuthorizationHandler<T, TClaims>? authorizationHandler;

  /// Legacy collection query extensions.
  final Map<String, QueryHandler<T>> queryHandlers;

  /// Trusted custom exception responses.
  final Map<Type, Response Function(Object)> customExceptionHandlers;

  /// Default pagination offset.
  final int defaultSkip;

  /// Default pagination size.
  final int defaultTake;

  /// Maximum pagination size.
  final int maxTake;

  /// Optional transformation before legacy create authorization/persistence.
  final T Function(T, AuthenticationResult<TClaims>?)? preCreate;
  late final ResourcePipeline<T, TClaims> _pipeline;
  late final ETagGenerator<T> _etagGenerator;

  void _ordinary(T value) {
    if (value is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
  }

  void _unconditional(Request request) {
    if (request.headers.keys.any(
      (name) =>
          name.toLowerCase().startsWith('if-') || name.toLowerCase() == 'range',
    )) {
      throw const RepositoryCapabilityException();
    }
  }

  @override
  Future<Response> handleGetById(Request request, String id) =>
      _pipeline.run(request, 'Retrieving', (principal) async {
        final uuid = UuidValue.fromString(id);
        final denied = await _pipeline.authorize(
          principal,
          (policy, auth) => policy.authorizeRead(uuid, auth),
          includeMessage: false,
        );
        if (denied != null) return denied;
        final representation = _pipeline.select(request.headers['accept']);
        final value = await repository.getById(uuid);
        _ordinary(value);
        return _pipeline.respond(
          value,
          representation,
          expectedId: uuid,
          etag: () => _etagGenerator.generate(value),
        );
      });
  @override
  Future<Response> handleQuery(
    Request request,
  ) => _pipeline.run(request, 'Querying', (principal) async {
    final parameters = request.url.queryParameters;
    var skip = int.tryParse(parameters['skip'] ?? '') ?? defaultSkip;
    var take = int.tryParse(parameters['take'] ?? '') ?? defaultTake;
    if (skip < 0) skip = 0;
    if (take < 0) take = defaultTake;
    if (take > maxTake) take = maxTake;
    final filters = Map<String, String>.from(parameters)
      ..remove('skip')
      ..remove('take');
    final denied = await _pipeline.authorize(
      principal,
      (policy, auth) => policy.authorizeQuery(filters, auth),
    );
    if (denied != null) return denied;
    final representation = _pipeline.select(request.headers['accept']);
    QueryResult<T> result;
    if (filters.isEmpty) {
      final handler = collectionHandler;
      if (handler == null) {
        return ResourcePipeline.problem(
          400,
          'Bad Request',
          'Unfiltered collection retrieval is unsupported for this resource. '
              'Configure a collectionHandler.',
        );
      }
      result = await handler(repository, const {}, skip, take, principal);
    } else if (filters.length > 1) {
      return ResourcePipeline.problem(
        400,
        'Bad Request',
        'Cannot combine multiple query parameters. Use only one filter at a time.',
      );
    } else {
      final name = filters.keys.first;
      final handler = queryHandlers[name];
      if (handler == null) {
        return ResourcePipeline.problem(
          400,
          'Bad Request',
          'Unsupported query parameter: $name',
        );
      }
      result = await handler(repository, filters, skip, take, principal);
    }
    for (final value in result.items) {
      _ordinary(value);
    }
    return _pipeline.respondList(
      result.items,
      representation,
      totalCount: result.totalCount,
    );
  });
  @override
  Future<Response> handleCreate(Request request) =>
      _pipeline.run(request, 'Creating', (principal) async {
        var value = await _pipeline.deserialize(request);
        _ordinary(value);
        if (preCreate != null) {
          value = preCreate!(value, principal);
          _ordinary(value);
        }
        final denied = await _pipeline.authorize(
          principal,
          (policy, auth) => policy.authorizeCreate(value, auth),
        );
        if (denied != null) return denied;
        final representation = _pipeline.select(request.headers['accept']);
        _unconditional(request);
        await _pipeline.persist(() => repository.save(value));
        return _pipeline.respond(
          value,
          representation,
          status: 201,
          etag: () => _etagGenerator.generate(value),
        );
      });
  @override
  Future<Response> handleUpdate(Request request, String id) =>
      _pipeline.run(request, 'Updating', (principal) async {
        final uuid = UuidValue.fromString(id);
        final value = await _pipeline.deserialize(request);
        _ordinary(value);
        if (value.id != uuid) {
          throw ArgumentError('Path and body aggregate identities must agree');
        }
        final denied = await _pipeline.authorize(
          principal,
          (policy, auth) => policy.authorizeUpdate(value, auth),
        );
        if (denied != null) return denied;
        final representation = _pipeline.select(request.headers['accept']);
        _unconditional(request);
        await _pipeline.persist(() => repository.save(value));
        return _pipeline.respond(value, representation, expectedId: uuid);
      });
  @override
  Future<Response> handleDelete(Request request, String id) =>
      _pipeline.run(request, 'Deleting', (principal) async {
        final uuid = UuidValue.fromString(id);
        final denied = await _pipeline.authorize(
          principal,
          (policy, auth) => policy.authorizeDelete(uuid, auth),
        );
        if (denied != null) return denied;
        _unconditional(request);
        _pipeline.select(request.headers['accept']);
        await _pipeline.persist(() => repository.deleteById(uuid));
        return Response(204);
      });
}
