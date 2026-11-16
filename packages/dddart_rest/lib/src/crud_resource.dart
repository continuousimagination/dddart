import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/src/access_policy.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authorization_context.dart';
import 'package:dddart_rest/src/authorization_result.dart';
import 'package:dddart_rest/src/error_mapper.dart';
import 'package:dddart_rest/src/query_handler.dart';
import 'package:dddart_rest/src/response_builder.dart';
import 'package:dddart_rest/src/revision_etag.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Main class that handles HTTP CRUD operations for an aggregate root.
///
/// CrudResource combines configuration (repository, JSON serializer, query handlers)
/// with request handling logic for standard CRUD operations. Each instance is
/// configured for a specific aggregate type and can be registered with an HTTP server.
///
/// Generic over [T] (aggregate type) and optional [TClaims] (authentication claims type).
/// Authentication and access policy are separate. Explicit public operation overrides
/// remain anonymous even when a verifier protects other operations.
///
/// Example without authentication:
/// ```dart
/// final userResource = CrudResource<User, UuidValue, void>(
///   path: '/users',
///   repository: userRepository,
///   serializer: jsonSerializer,
/// );
/// ```
///
/// Example with authentication:
/// ```dart
/// final userResource = CrudResource<User, UuidValue, UserClaims>(
///   path: '/users',
///   repository: userRepository,
///   serializer: jsonSerializer,
///   authenticationHandler: jwtAuthHandler,
/// );
/// ```
class CrudResource<T extends AggregateRoot<I>, I extends Identity, TClaims> {
  /// Creates a CrudResource with the specified configuration
  ///
  /// Parameters:
  /// - [path]: The base path for this resource (e.g., '/users')
  /// - [repository]: Repository instance for persistence operations
  /// - [serializer]: JSON serializer for request and response bodies
  /// - [authenticationHandler]: Optional authentication handler. When provided, all CRUD operations require authentication
  /// - [defaultPolicy]: Resource access policy; operation overrides replace it
  /// - [operationPolicies]: Explicit access policy for each selected operation
  /// - [collectionHandler]: Optional handler for unfiltered collection retrieval
  /// - [queryHandlers]: Map of query parameter names to handler functions
  /// - [customExceptionHandlers]: Map of exception types to error response handlers
  /// - [defaultSkip]: Default skip value for pagination (defaults to 0)
  /// - [defaultTake]: Default take value for pagination (defaults to 50)
  /// - [maxTake]: Maximum allowed take value to prevent excessive queries (defaults to 100)
  /// - [requirePrecondition]: Require a write condition on PUT and DELETE
  /// - [preCreate]: Optional callback to modify aggregate before creation (e.g., set fields from auth context)
  ///
  /// Throws [ArgumentError] if:
  /// - [path] is null or empty
  CrudResource({
    required this.path,
    required this.repository,
    required this.serializer,
    this.authenticationHandler,
    AccessPolicy<T, I, TClaims>? defaultPolicy,
    Map<CrudOperation, AccessPolicy<T, I, TClaims>> operationPolicies =
        const {},
    bool Function(Request)? credentialsPresent,
    this.collectionHandler,
    this.queryHandlers = const {},
    this.customExceptionHandlers = const {},
    this.defaultSkip = 0,
    this.defaultTake = 50,
    this.maxTake = 100,
    this.requirePrecondition = false,
    this.preCreate,
    IdentityCodecRegistry? identityCodecs,
  })  : identityCodecs = identityCodecs ?? IdentityCodecRegistry(),
        defaultPolicy = defaultPolicy ??
            (authenticationHandler == null
                ? AccessPolicy<T, I, TClaims>.public()
                : AccessPolicy<T, I, TClaims>.authenticated()),
        operationPolicies = Map.unmodifiable(operationPolicies),
        credentialsPresent = credentialsPresent ?? _hasAuthorizationHeader {
    for (final operation in CrudOperation.values) {
      if (_policy(operation).authentication ==
              AuthenticationRequirement.required &&
          authenticationHandler == null) {
        throw ArgumentError(
          'Required authentication for $operation needs a verifier',
        );
      }
    }
    if (!this.identityCodecs.contains<I>()) {
      throw ArgumentError('Register a codec for the resource identity $I');
    }
    // Validate path is not null or empty
    if (path.isEmpty) {
      throw ArgumentError('path cannot be empty');
    }

    if (requirePrecondition &&
        repository is! ConditionalAggregateRepository<T, I>) {
      throw ArgumentError(
        'Required preconditions need an atomic conditional repository.',
      );
    }
  }

  /// The base path for this resource (e.g., '/users')
  final String path;

  /// Repository instance for persistence operations
  ///
  /// All repositories implement Repository<T, I> interface with getById, save, deleteById methods
  final Repository<T, I> repository;

  /// Instance-local key codecs; configure the body serializer with the same codecs.
  final IdentityCodecRegistry identityCodecs;

  /// JSON serializer used for all request and success response bodies.
  final JsonSerializer<T> serializer;

  /// Optional authentication handler
  ///
  /// Installing a verifier defaults the resource to authenticated access.
  /// A public/optional operation override does not require missing credentials;
  /// invalid supplied credentials still return 401.
  /// The handler is invoked before any repository operations.
  /// If authentication fails, a 401 Unauthorized response is returned.
  final AuthenticationHandler<TClaims>? authenticationHandler;

  /// Default access policy. Without a verifier the default is public; installing
  /// a verifier selects authenticated access unless an explicit default is given.
  final AccessPolicy<T, I, TClaims> defaultPolicy;

  /// Complete policy replacements for individual operations.
  final Map<CrudOperation, AccessPolicy<T, I, TClaims>> operationPolicies;

  /// Detects supplied credentials on optional/public operations. Defaults to the
  /// presence of Authorization, including an empty header. Cookie-based verifiers
  /// can supply their own detector. Required operations always invoke the verifier.
  final bool Function(Request) credentialsPresent;

  static bool _hasAuthorizationHeader(Request request) =>
      request.headers.containsKey('authorization');

  AccessPolicy<T, I, TClaims> _policy(CrudOperation operation) =>
      operationPolicies[operation] ?? defaultPolicy;

  /// Optional handler for unfiltered collection retrieval.
  ///
  /// The handler owns datastore-side selection, ordering, pagination, and the
  /// accurate total count. It receives an empty query-parameter map, normalized
  /// pagination values, and the current authentication result.
  final QueryHandler<T, I, TClaims>? collectionHandler;

  /// Map of query parameter names to handler functions
  ///
  /// Key: the query parameter name (e.g., 'firstName')
  /// Value: the handler function to invoke when that parameter is present
  /// The same handler may be registered for multiple filter names.
  final Map<String, QueryHandler<T, I, TClaims>> queryHandlers;

  /// Map of custom exception types to error response handlers
  ///
  /// These handlers supplement the built-in error handling for framework exceptions
  /// Key: the exception type (e.g., MyCustomException)
  /// Value: function that converts the exception to an HTTP Response
  /// Note: Built-in handlers for RepositoryException, DeserializationException, etc. are always active
  final Map<Type, Response Function(Object)> customExceptionHandlers;

  /// Default skip value for pagination (defaults to 0)
  final int defaultSkip;

  /// Default take value for pagination (defaults to 50)
  final int defaultTake;

  /// Maximum allowed take value to prevent excessive queries (defaults to 100)
  final int maxTake;

  /// Optional callback to modify aggregate before creation
  ///
  /// This callback is invoked after deserialization but before authorization and saving.
  /// It receives the deserialized aggregate and typed caller, and returns
  /// a potentially modified aggregate.
  ///
  /// Common use cases:
  /// - Setting fields from authentication context (e.g., userId, cognitoSub)
  /// - Adding audit fields (e.g., createdBy)
  /// - Applying default values based on user context
  ///
  /// Example:
  /// ```dart
  /// preCreate: (player, authResult) {
  ///   return player.withOwner(authResult.claims?.sub);
  /// }
  /// ```
  final T Function(T aggregate, Caller<TClaims> caller)? preCreate;

  /// ResponseBuilder instance for creating HTTP responses
  late final ResponseBuilder<T> _responseBuilder = ResponseBuilder<T>();

  /// Whether PUT/DELETE must supply an atomic write condition.
  ///
  /// Public/unconditional CRUD remains the default. A plain repository cannot
  /// satisfy this configuration; construction rejects it before serving traffic.
  final bool requirePrecondition;

  /// Logger instance for REST API request/response logging
  final Logger _logger = Logger('dddart.rest');

  Future<({Response? response, Caller<TClaims> caller})> _authenticate(
    Request request,
    CrudOperation operation,
  ) async {
    final policy = _policy(operation);
    final verifier = authenticationHandler;
    try {
      if (verifier == null ||
          (policy.authentication == AuthenticationRequirement.optional &&
              !credentialsPresent(request))) {
        return (response: null, caller: AnonymousCaller<TClaims>());
      }
      final result = await verifier.authenticate(request);
      if (!result.isAuthenticated) {
        return (
          response: _responseBuilder
              .unauthorized(result.errorMessage ?? 'Authentication required'),
          caller: AnonymousCaller<TClaims>()
        );
      }
      return (response: null, caller: VerifiedCaller(result));
    } catch (error, stack) {
      _logger.warning('Credential verification failed', error, stack);
      throw const AccessEvaluationException();
    }
  }

  T _policySnapshot(T value) {
    try {
      // Build detached domain snapshots through the JSON value codec. The
      // response encoder is invoked only after the access decision succeeds.
      final copy =
          serializer.fromJson(jsonDecode(jsonEncode(serializer.toJson(value))));
      if (identical(copy, value) || copy.id != value.id) {
        throw StateError(
          'Serializer must produce a detached identity-preserving snapshot',
        );
      }
      return copy;
    } catch (error, stack) {
      _logger.warning('Cannot construct authorization snapshot', error, stack);
      throw const AccessEvaluationException();
    }
  }

  Future<AuthorizationResult> _authorize(
    AuthorizationContext<T, I, TClaims> context,
  ) async {
    final policy = _policy(context.operation);
    final handler = policy.handler;
    if (handler == null) {
      return const AuthorizationResult.allow(scope: UnrestrictedQueryScope());
    }
    final AuthorizationResult result;
    try {
      result = await handler.authorize(context);
      if (result.isAuthorized &&
          context is QueryContext<T, I, TClaims> &&
          result.scope == null) {
        throw StateError(
          'An allowed collection policy must supply a query scope',
        );
      }
    } catch (error, stack) {
      _logger.warning('Authorization policy failed', error, stack);
      throw const AccessEvaluationException();
    }
    if (!result.isAuthorized) {
      throw AccessDeniedException(conceal: result.conceal);
    }
    return result;
  }

  Future<({T aggregate, String? revision})?> _current(I id) async {
    try {
      if (repository is VersionedRepository<T, I>) {
        final snapshot =
            await (repository as VersionedRepository<T, I>).getVersioned(id);
        return (aggregate: snapshot.aggregate, revision: snapshot.revision);
      }
      return (aggregate: await repository.getById(id), revision: null);
    } on RepositoryException catch (error) {
      if (error.type == RepositoryExceptionType.notFound) return null;
      rethrow;
    }
  }

  ExpectedRevision _expectedAtSnapshot(
    WritePrecondition? condition,
    String? revision,
  ) {
    if (condition != null) {
      if (condition.absent
          ? revision != null
          : revision == null || !condition.revisions.contains(revision)) {
        throw const PreconditionException.failed();
      }
    }
    return revision == null
        ? const ExpectedRevision.absent()
        : ExpectedRevision.match(revision);
  }

  Never _implicitConflict() => throw const RepositoryException(
        'The resource changed while access was evaluated. Reload and authorize a new request.',
        type: RepositoryExceptionType.conflict,
      );

  Future<String?> _createOnly(
    T aggregate,
    WritePrecondition? condition, {
    bool checkedAbsent = false,
  }) async {
    if (condition != null && !condition.absent) {
      throw const PreconditionException.unsupported(
        'POST/create requires absence, not an existing revision. Use PUT to update.',
      );
    }
    if (repository is ConditionalAggregateRepository<T, I>) {
      try {
        return await (repository as ConditionalAggregateRepository<T, I>)
            .saveConditional(
          aggregate,
          expected: const ExpectedRevision.absent(),
        );
      } on RevisionConflictException<I> {
        if (condition != null) rethrow;
        throw const RepositoryException(
          'A resource with this identity already exists',
          type: RepositoryExceptionType.conflict,
        );
      }
    }
    if (condition != null || _policy(CrudOperation.create).handler != null) {
      throw const ConditionalCapabilityUnsupportedException();
    }
    // Plain public/authentication-only CRUD has no atomic capability. Reject
    // sequential POST overwrite; concurrent create isolation requires the capability.
    if (!checkedAbsent && await _current(aggregate.id) != null) {
      throw const RepositoryException(
        'A resource with this identity already exists',
        type: RepositoryExceptionType.conflict,
      );
    }
    await repository.save(aggregate);
    return null;
  }

  I _identityFromKey(String key) {
    if (key.isEmpty ||
        key == '.' ||
        key == '..' ||
        utf8.decode(utf8.encode(key)) != key) {
      throw const DeserializationException('Invalid REST identity key');
    }
    return identityCodecs.fromKey<I>(key);
  }

  void _validateCreatedIdentity(I identity) {
    try {
      _identityFromKey(identityCodecs.toKey<I>(identity));
    } on SerializationException {
      throw const DeserializationException('Invalid REST identity key');
    }
  }

  /// Handles GET /resource/:id
  ///
  /// Parses the ID, calls repository.getById(), and returns a JSON aggregate.
  /// The Accept header must allow JSON when it is present.
  ///
  /// Versioned repositories include a strong storage-revision ETag. Plain
  /// repositories return no validator and cannot accept conditional mutations.
  ///
  /// If auth handler is configured, authenticates the request first.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The canonical key after one URI-decoding step (direct callers pass it decoded)
  ///
  /// Returns: A Response with status 200 and serialized aggregate, or error response
  Future<Response> handleGetById(Request request, String id) async {
    _logger.info('GET /$path/$id - Retrieving $T');
    try {
      final negotiationError = _validateAcceptHeader(request.headers['accept']);
      if (negotiationError != null) {
        _logger.fine('GET /$path/$id - ${negotiationError.statusCode}');
        return negotiationError;
      }

      // Authenticate if handler is configured
      final authCheck = await _authenticate(request, CrudOperation.read);
      if (authCheck.response != null) {
        _logger.fine('GET /$path/$id - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final identity = _identityFromKey(id);
      final T aggregate;
      String? revision;
      if (repository is VersionedRepository<T, I>) {
        final snapshot = await (repository as VersionedRepository<T, I>)
            .getVersioned(identity);
        aggregate = snapshot.aggregate;
        revision = snapshot.revision;
      } else {
        aggregate = await repository.getById(identity);
      }

      if (_policy(CrudOperation.read).handler != null) {
        await _authorize(
          ReadContext(
            caller: authCheck.caller,
            current: _policySnapshot(aggregate),
          ),
        );
      }

      final response = _responseBuilder.ok(
        aggregate,
        serializer,
        etag: revision == null ? null : RevisionETag.encode(revision),
      );
      _logger.fine('GET /$path/$id - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Handles GET /resource with optional query parameters and pagination
  ///
  /// - No query params: invokes [collectionHandler], or returns 400 if absent
  /// - One query param: looks up and invokes corresponding query handler
  /// - Multiple query params: returns 400 error
  ///
  /// If auth handler is configured, authenticates the request first and passes
  /// auth result to query handlers.
  /// The selected collection policy runs for every request, including unfiltered reads.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  ///
  /// Returns: A Response with status 200 and serialized array, or error response
  Future<Response> handleQuery(Request request) async {
    final queryString =
        request.url.query.isEmpty ? '' : '?${request.url.query}';
    _logger.info('GET /$path$queryString - Querying $T');
    try {
      final negotiationError = _validateAcceptHeader(request.headers['accept']);
      if (negotiationError != null) {
        _logger.fine(
          'GET /$path$queryString - ${negotiationError.statusCode}',
        );
        return negotiationError;
      }

      // Authenticate if handler is configured
      final authCheck = await _authenticate(request, CrudOperation.query);
      if (authCheck.response != null) {
        _logger
            .fine('GET /$path$queryString - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final queryParams = request.url.queryParameters;
      final pagination = _parsePagination(queryParams);

      // Remove pagination params for handler matching
      final filterParams = Map<String, String>.from(queryParams)
        ..remove('skip')
        ..remove('take');

      final decision = await _authorize(
        QueryContext<T, I, TClaims>(
          caller: authCheck.caller,
          filters: filterParams,
        ),
      );
      final queryAuthorization =
          AuthorizedQuery(caller: authCheck.caller, scope: decision.scope!);

      QueryResult<T> result;

      if (filterParams.isEmpty) {
        final handler = collectionHandler;
        if (handler == null) {
          final response = _responseBuilder.badRequest(
            'Unfiltered collection retrieval is unsupported for this resource. '
            'Configure a collectionHandler.',
          );
          _logger.fine('GET /$path$queryString - ${response.statusCode}');
          return response;
        }

        result = await handler(
          repository,
          const <String, String>{},
          pagination.skip,
          pagination.take,
          queryAuthorization,
        );
      } else if (filterParams.length > 1) {
        // Multiple filters not allowed
        final response = _responseBuilder.badRequest(
          'Cannot combine multiple query parameters. Use only one filter at a time.',
        );
        _logger.fine('GET /$path$queryString - ${response.statusCode}');
        return response;
      } else {
        // Single filter - look up handler
        final paramName = filterParams.keys.first;
        final handler = queryHandlers[paramName];

        if (handler == null) {
          final response = _responseBuilder.badRequest(
            'Unsupported query parameter: $paramName',
          );
          _logger.fine('GET /$path$queryString - ${response.statusCode}');
          return response;
        }

        result = await handler(
          repository,
          filterParams,
          pagination.skip,
          pagination.take,
          queryAuthorization,
        );
      }

      final response = _responseBuilder.okList(
        result.items,
        serializer,
        totalCount: result.totalCount,
      );
      _logger.fine('GET /$path$queryString - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Handles POST /resource
  ///
  /// Creates a previously absent aggregate and returns it as JSON. POST cannot
  /// overwrite an existing identity, even when If-Match is supplied. Content-Type must be application/json and the
  /// Accept header must allow JSON.
  ///
  /// Versioned repositories include a strong storage-revision ETag. Plain
  /// repositories return no validator and cannot accept conditional mutations.
  ///
  /// If auth handler is configured, authenticates the request first.
  /// The selected custom policy always runs, including for anonymous callers.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  ///
  /// Returns: A Response with status 201 and serialized aggregate, or error response
  Future<Response> handleCreate(Request request) async {
    _logger.info('POST /$path - Creating $T');
    try {
      final negotiationError = _validateAcceptHeader(request.headers['accept']);
      if (negotiationError != null) {
        _logger.fine('POST /$path - ${negotiationError.statusCode}');
        return negotiationError;
      }

      final contentTypeError =
          _validateJsonContentType(request.headers['content-type']);
      if (contentTypeError != null) {
        _logger.fine('POST /$path - ${contentTypeError.statusCode}');
        return contentTypeError;
      }

      // Authenticate if handler is configured
      final authCheck = await _authenticate(request, CrudOperation.create);
      if (authCheck.response != null) {
        _logger.fine('POST /$path - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final body = await request.readAsString();
      T aggregate;
      try {
        aggregate = serializer.deserialize(body);
      } catch (e) {
        _logger.warning('POST /$path - Deserialization failed: $e');
        rethrow;
      }

      // Apply preCreate callback if configured
      if (preCreate != null) {
        aggregate = preCreate!(aggregate, authCheck.caller);
      }

      // The final aggregate must be addressable by this REST adapter.
      _validateCreatedIdentity(aggregate.id);

      if (_policy(CrudOperation.create).handler != null) {
        await _authorize(
          CreateContext(
            caller: authCheck.caller,
            proposed: _policySnapshot(aggregate),
          ),
        );
      }

      final condition = WritePrecondition.parse(request.headers);
      final revision = await _createOnly(aggregate, condition);
      final etag = revision == null ? null : RevisionETag.encode(revision);

      final response = _responseBuilder.created(
        aggregate,
        serializer,
        etag: etag,
      );
      _logger.fine('POST /$path - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Handles PUT /resource/:id
  ///
  /// Deserializes a JSON request body, calls repository.save(), and returns the
  /// updated aggregate as JSON. Content-Type must be application/json and the
  /// Accept header must allow JSON.
  ///
  /// The route ID is authoritative and must match the deserialized aggregate
  /// ID. A mismatch returns 400 before authorization, ETag lookup, or saving.
  ///
  /// Supports atomic conditional writes via the If-Match header:
  /// A supplied precondition uses atomic repository writes. Strong ETags come
  /// from storage revisions, not timestamps or payload hashes. A successful
  /// conditional PUT returns its new ETag. Custom mutation policies also bind
  /// their decision to the loaded revision. Public ordinary updates return no
  /// ETag; GET a coherent snapshot before the next conditional edit.
  ///
  /// If auth handler is configured, authenticates the request first.
  /// The selected custom policy always runs, including for anonymous callers.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The canonical key after one URI-decoding step (direct callers pass it decoded)
  ///
  /// Returns: A Response with status 200 and serialized aggregate, or error response
  Future<Response> handleUpdate(Request request, String id) async {
    _logger.info('PUT /$path/$id - Updating $T');
    try {
      final negotiationError = _validateAcceptHeader(request.headers['accept']);
      if (negotiationError != null) {
        _logger.fine('PUT /$path/$id - ${negotiationError.statusCode}');
        return negotiationError;
      }

      final contentTypeError =
          _validateJsonContentType(request.headers['content-type']);
      if (contentTypeError != null) {
        _logger.fine('PUT /$path/$id - ${contentTypeError.statusCode}');
        return contentTypeError;
      }

      // Authenticate if handler is configured
      final authCheck = await _authenticate(request, CrudOperation.update);
      if (authCheck.response != null) {
        _logger.fine('PUT /$path/$id - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final body = await request.readAsString();
      T aggregate;
      try {
        aggregate = serializer.deserialize(body);
      } catch (e) {
        _logger.warning('PUT /$path/$id - Deserialization failed: $e');
        rethrow;
      }

      final identity = _identityFromKey(id);
      if (aggregate.id != identity) {
        final response = _responseBuilder.badRequest(
          'Route ID $identity does not match request body ID ${aggregate.id}.',
        );
        _logger.fine('PUT /$path/$id - ${response.statusCode} (ID mismatch)');
        return response;
      }

      final condition = WritePrecondition.parse(
        request.headers,
        required: requirePrecondition,
      );
      if (condition != null) requireConditionalAggregateRepository(repository);
      final current = await _current(identity);
      if (current == null) {
        // PUT is an upsert route: a missing record also needs create permission.
        // The update gate above cannot be used to bypass a stricter create policy.
        final createAuth = authCheck.caller.isAuthenticated
            ? authCheck
            : await _authenticate(request, CrudOperation.create);
        if (createAuth.response != null) return createAuth.response!;
        if (preCreate != null) {
          aggregate = preCreate!(aggregate, createAuth.caller);
        }
        _validateCreatedIdentity(aggregate.id);
        if (aggregate.id != identity) {
          return _responseBuilder
              .badRequest('preCreate must preserve the PUT route identity.');
        }
        if (_policy(CrudOperation.create).handler != null) {
          await _authorize(
            CreateContext(
              caller: createAuth.caller,
              proposed: _policySnapshot(aggregate),
            ),
          );
        }
        if (condition != null && !condition.absent) {
          throw const PreconditionException.failed();
        }
        final revision =
            await _createOnly(aggregate, condition, checkedAbsent: true);
        return _responseBuilder.created(
          aggregate,
          serializer,
          etag: revision == null ? null : RevisionETag.encode(revision),
        );
      }
      final custom = _policy(CrudOperation.update).handler != null;
      if (custom) {
        requireConditionalAggregateRepository(repository);
        await _authorize(
          UpdateContext(
            caller: authCheck.caller,
            current: _policySnapshot(current.aggregate),
            proposed: _policySnapshot(aggregate),
          ),
        );
      }
      String? etag;
      if (condition != null || custom) {
        final conditional = requireConditionalAggregateRepository(repository);
        final expected = _expectedAtSnapshot(condition, current.revision);
        try {
          final revision =
              await conditional.saveConditional(aggregate, expected: expected);
          etag = RevisionETag.encode(revision);
        } on RevisionConflictException<I> {
          if (condition != null) rethrow;
          _implicitConflict();
        }
      } else {
        await repository.save(aggregate);
      }
      final response = _responseBuilder.ok(aggregate, serializer, etag: etag);
      _logger.fine('PUT /$path/$id - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Handles DELETE /resource/:id
  ///
  /// Parses ID, calls repository.deleteById(), returns 204 No Content
  ///
  /// If auth handler is configured, authenticates the request first.
  /// The selected custom policy always runs, including for anonymous callers.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The canonical key after one URI-decoding step (direct callers pass it decoded)
  ///
  /// Returns: A Response with status 204, or error response
  Future<Response> handleDelete(Request request, String id) async {
    _logger.info('DELETE /$path/$id - Deleting $T');
    try {
      final negotiationError = _validateAcceptHeader(request.headers['accept']);
      if (negotiationError != null) {
        _logger.fine('DELETE /$path/$id - ${negotiationError.statusCode}');
        return negotiationError;
      }

      // Authenticate if handler is configured
      final authCheck = await _authenticate(request, CrudOperation.delete);
      if (authCheck.response != null) {
        _logger.fine('DELETE /$path/$id - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final identity = _identityFromKey(id);

      final condition = WritePrecondition.parse(
        request.headers,
        required: requirePrecondition,
      );
      final custom = _policy(CrudOperation.delete).handler != null;
      if (condition != null || custom) {
        requireConditionalAggregateRepository(repository);
      }
      final current = await _current(identity);
      if (current == null) {
        if (condition?.absent ?? false) {
          await requireConditionalAggregateRepository(repository)
              .deleteConditional(
            identity,
            expected: const ExpectedRevision.absent(),
          );
          return _responseBuilder.noContent();
        }
        if (condition != null) throw const PreconditionException.failed();
        throw const RepositoryException(
          'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      if (custom) {
        await _authorize(
          DeleteContext(
            caller: authCheck.caller,
            current: _policySnapshot(current.aggregate),
          ),
        );
      }
      if (condition != null || custom) {
        final expected = _expectedAtSnapshot(condition, current.revision);
        try {
          await requireConditionalAggregateRepository(repository)
              .deleteConditional(identity, expected: expected);
        } on RevisionConflictException<I> {
          if (condition != null) rethrow;
          _implicitConflict();
        }
      } else {
        await repository.deleteById(identity);
      }
      final response = _responseBuilder.noContent();
      _logger.fine('DELETE /$path/$id - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Validates that the client accepts the stock JSON response representation.
  Response? _validateAcceptHeader(String? acceptHeader) {
    if (acceptHeader == null || acceptHeader.trim().isEmpty) {
      return null;
    }

    var selectedSpecificity = -1;
    var selectedQuality = 0.0;

    for (final part in acceptHeader.split(',')) {
      final segments = part.trim().split(';');
      final mediaType = segments.first.trim().toLowerCase();
      final specificity = switch (mediaType) {
        'application/json' => 2,
        'application/*' => 1,
        '*/*' => 0,
        _ => null,
      };
      if (specificity == null) continue;

      var quality = 1.0;

      for (var i = 1; i < segments.length; i++) {
        final parameter = segments[i].trim();
        final separator = parameter.indexOf('=');
        if (separator == -1) continue;
        final name = parameter.substring(0, separator).trim().toLowerCase();
        if (name == 'q') {
          quality =
              double.tryParse(parameter.substring(separator + 1).trim()) ?? 0;
          if (quality < 0 || quality > 1) quality = 0;
          break;
        }
      }

      if (specificity > selectedSpecificity) {
        selectedSpecificity = specificity;
        selectedQuality = quality;
      } else if (specificity == selectedSpecificity &&
          quality > selectedQuality) {
        selectedQuality = quality;
      }
    }

    if (selectedQuality > 0) return null;

    return _responseBuilder.notAcceptable(
      'Accept header does not allow application/json: $acceptHeader',
    );
  }

  /// Validates the JSON media type required for POST and PUT request bodies.
  Response? _validateJsonContentType(String? contentTypeHeader) {
    if (contentTypeHeader == null || contentTypeHeader.trim().isEmpty) {
      return _responseBuilder.unsupportedMediaType(
        'Content-Type application/json is required.',
      );
    }

    final contentType = _extractMediaType(contentTypeHeader).toLowerCase();
    if (contentType == 'application/json') {
      return null;
    }

    return _responseBuilder.unsupportedMediaType(
      'Content-Type $contentType is not supported. '
      'Supported type: application/json',
    );
  }

  /// Handles exceptions by checking custom handlers first, then falling back to ErrorMapper
  ///
  /// Parameters:
  /// - [error]: The exception that was thrown
  /// - [stackTrace]: The stack trace associated with the exception
  ///
  /// Returns: A Response with appropriate status code and error body
  Response _handleException(Object error, StackTrace stackTrace) {
    _logger.severe('Exception during request handling', error, stackTrace);

    if (error is AccessDeniedException) {
      return Response(
        error.conceal ? 404 : 403,
        headers: {'content-type': 'application/problem+json'},
        body: jsonEncode({
          'type': 'about:blank',
          'title': error.conceal ? 'Not Found' : 'Forbidden',
          'status': error.conceal ? 404 : 403,
          'detail': error.conceal ? 'Resource not found' : 'Access denied',
        }),
      );
    }
    if (error is AccessEvaluationException) {
      return ErrorMapper.mapException(error, stackTrace);
    }
    // Check custom handlers first
    final customHandler = customExceptionHandlers[error.runtimeType];
    if (customHandler != null) {
      return customHandler(error);
    }

    if (error is RepositoryException &&
        error.type == RepositoryExceptionType.notFound) {
      return _responseBuilder.notFound('Resource not found');
    }

    // Fall back to built-in ErrorMapper
    return ErrorMapper.mapException(error, stackTrace);
  }

  /// Extracts media type from Content-Type header, removing charset and other parameters
  ///
  /// Example: "application/json; charset=utf-8" -> "application/json"
  ///
  /// Parameters:
  /// - [contentType]: The Content-Type header value
  ///
  /// Returns: The media type without parameters
  String _extractMediaType(String contentType) {
    return contentType.split(';').first.trim();
  }

  /// Parses pagination parameters from query string
  ///
  /// Extracts skip and take parameters, applies defaults, and enforces maxTake limit.
  /// Edge cases:
  /// - Negative skip is treated as zero
  /// - Negative take is treated as defaultTake
  /// - Zero take is preserved for the selected collection handler
  /// - Take values exceeding maxTake are capped at maxTake
  ///
  /// Parameters:
  /// - [queryParams]: The query parameters from the request
  ///
  /// Returns: A _PaginationParams object with skip and take values
  _PaginationParams _parsePagination(Map<String, String> queryParams) {
    var skip = int.tryParse(queryParams['skip'] ?? '') ?? defaultSkip;
    var take = int.tryParse(queryParams['take'] ?? '') ?? defaultTake;

    // Handle negative skip - treat as zero
    if (skip < 0) {
      skip = 0;
    }

    // Handle negative take - treat as defaultTake
    if (take < 0) {
      take = defaultTake;
    }

    // Enforce maxTake limit
    if (take > maxTake) {
      take = maxTake;
    }

    return _PaginationParams(skip, take);
  }
}

/// Internal class to hold pagination parameters
class _PaginationParams {
  _PaginationParams(this.skip, this.take);
  final int skip;
  final int take;
}
