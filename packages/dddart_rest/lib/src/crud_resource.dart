import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/authorization_handler.dart';
import 'package:dddart_rest/src/error_mapper.dart';
import 'package:dddart_rest/src/etag_generator.dart';
import 'package:dddart_rest/src/query_handler.dart';
import 'package:dddart_rest/src/repository_query_support.dart';
import 'package:dddart_rest/src/response_builder.dart';
import 'package:shelf/shelf.dart';

/// Main class that handles HTTP CRUD operations for an aggregate root.
///
/// CrudResource combines configuration (repository, JSON serializer, query handlers)
/// with request handling logic for standard CRUD operations. Each instance is
/// configured for a specific aggregate type and can be registered with an HTTP server.
///
/// Generic over [T] (aggregate type) and optional [TClaims] (authentication claims type).
/// When [authenticationHandler] is provided, all CRUD operations require authentication.
///
/// Example without authentication:
/// ```dart
/// final userResource = CrudResource<User>(
///   path: '/users',
///   repository: userRepository,
///   serializer: jsonSerializer,
/// );
/// ```
///
/// Example with authentication:
/// ```dart
/// final userResource = CrudResource<User, UserClaims>(
///   path: '/users',
///   repository: userRepository,
///   serializer: jsonSerializer,
///   authenticationHandler: jwtAuthHandler,
/// );
/// ```
class CrudResource<T extends AggregateRoot, TClaims> {
  /// Creates a CrudResource with the specified configuration
  ///
  /// Parameters:
  /// - [path]: The base path for this resource (e.g., '/users')
  /// - [repository]: Repository instance for persistence operations
  /// - [serializer]: JSON serializer for request and response bodies
  /// - [authenticationHandler]: Optional authentication handler. When provided, all CRUD operations require authentication
  /// - [authorizationHandler]: Optional authorization handler. When provided, operations are authorized after authentication
  /// - [queryHandlers]: Map of query parameter names to handler functions
  /// - [customExceptionHandlers]: Map of exception types to error response handlers
  /// - [defaultSkip]: Default skip value for pagination (defaults to 0)
  /// - [defaultTake]: Default take value for pagination (defaults to 50)
  /// - [maxTake]: Maximum allowed take value to prevent excessive queries (defaults to 100)
  /// - [etagStrategy]: Strategy for generating ETags (defaults to timestamp)
  /// - [preCreate]: Optional callback to modify aggregate before creation (e.g., set fields from auth context)
  ///
  /// Throws [ArgumentError] if:
  /// - [path] is null or empty
  CrudResource({
    required this.path,
    required this.repository,
    required this.serializer,
    this.authenticationHandler,
    this.authorizationHandler,
    this.queryHandlers = const {},
    this.customExceptionHandlers = const {},
    this.defaultSkip = 0,
    this.defaultTake = 50,
    this.maxTake = 100,
    ETagStrategy etagStrategy = ETagStrategy.timestamp,
    this.preCreate,
  }) {
    // Validate path is not null or empty
    if (path.isEmpty) {
      throw ArgumentError('path cannot be empty');
    }

    // Initialize ETag generator
    _etagGenerator = ETagGenerator<T>(
      strategy: etagStrategy,
      serializer: etagStrategy == ETagStrategy.contentHash ? serializer : null,
    );
  }

  /// The base path for this resource (e.g., '/users')
  final String path;

  /// Repository instance for persistence operations
  ///
  /// All repositories implement Repository<T> interface with getById, save, deleteById methods
  final Repository<T> repository;

  /// JSON serializer used for all request and success response bodies.
  final JsonSerializer<T> serializer;

  /// Optional authentication handler
  ///
  /// When provided, all CRUD operations will require authentication.
  /// The handler is invoked before any repository operations.
  /// If authentication fails, a 401 Unauthorized response is returned.
  final AuthenticationHandler<TClaims>? authenticationHandler;

  /// Optional authorization handler
  ///
  /// When provided, operations are authorized after authentication succeeds.
  /// The handler is invoked after authentication but before executing the operation.
  /// If authorization fails, a 403 Forbidden response is returned.
  final AuthorizationHandler<T, TClaims>? authorizationHandler;

  /// Map of query parameter names to handler functions
  ///
  /// Key: the query parameter name (e.g., 'firstName')
  /// Value: the handler function to invoke when that parameter is present
  /// Note: The same handler can be registered multiple times for backward compatibility
  final Map<String, QueryHandler<T>> queryHandlers;

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
  /// It receives the deserialized aggregate and authentication result, and returns
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
  ///   return Player(
  ///     ...player,
  ///     cognitoSub: authResult?.claims?.sub,
  ///   );
  /// }
  /// ```
  final T Function(T aggregate, AuthenticationResult<TClaims>? authResult)?
      preCreate;

  /// ResponseBuilder instance for creating HTTP responses
  late final ResponseBuilder<T> _responseBuilder = ResponseBuilder<T>();

  /// ETag generator for optimistic concurrency control
  late final ETagGenerator<T> _etagGenerator;

  /// Logger instance for REST API request/response logging
  final Logger _logger = Logger('dddart.rest');

  /// Authenticates a request if auth handler is configured
  ///
  /// Returns null if authentication succeeds or auth handler is not configured.
  /// Returns a 401 Response if authentication fails.
  ///
  /// Parameters:
  /// - [request]: The HTTP request to authenticate
  ///
  /// Returns: null if authenticated or no auth required, 401 Response if auth fails
  Future<({Response? response, AuthenticationResult<TClaims>? authResult})>
      _authenticate(
    Request request,
  ) async {
    if (authenticationHandler == null) {
      return (response: null, authResult: null);
    }

    final authResult = await authenticationHandler!.authenticate(request);
    if (!authResult.isAuthenticated) {
      final response = _responseBuilder.unauthorized(
        authResult.errorMessage ?? 'Authentication required',
      );
      return (response: response, authResult: null);
    }

    return (response: null, authResult: authResult);
  }

  /// Handles GET /resource/:id
  ///
  /// Parses the ID, calls repository.getById(), and returns a JSON aggregate.
  /// The Accept header must allow JSON when it is present.
  ///
  /// Includes ETag header in response for optimistic concurrency control.
  ///
  /// If auth handler is configured, authenticates the request first.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The ID string from the URL path
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
      final authCheck = await _authenticate(request);
      if (authCheck.response != null) {
        _logger.fine('GET /$path/$id - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final uuid = UuidValue.fromString(id);
      final aggregate = await repository.getById(uuid);

      // Generate ETag for the aggregate
      final etag = _etagGenerator.generate(aggregate);

      final response = _responseBuilder.ok(
        aggregate,
        serializer,
        etag: etag,
      );
      _logger.fine('GET /$path/$id - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Handles GET /resource with optional query parameters and pagination
  ///
  /// - No query params: returns all items (paginated)
  /// - One query param: looks up and invokes corresponding query handler
  /// - Multiple query params: returns 400 error
  ///
  /// If auth handler is configured, authenticates the request first and passes
  /// auth result to query handlers.
  /// If authorization handler is configured, authorizes filtered queries after authentication.
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
      final authCheck = await _authenticate(request);
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

      // Authorize filtered queries if handler is configured
      if (filterParams.isNotEmpty &&
          authorizationHandler != null &&
          authCheck.authResult != null) {
        final authzResult = await authorizationHandler!.authorizeQuery(
          filterParams,
          authCheck.authResult!,
        );
        if (!authzResult.isAuthorized) {
          final response = Response(
            403,
            headers: {'Content-Type': 'application/problem+json'},
            body: jsonEncode({
              'type': 'about:blank',
              'title': 'Forbidden',
              'status': 403,
              'detail': authzResult.errorMessage ?? 'Access denied',
            }),
          );
          _logger.fine('GET /$path$queryString - ${response.statusCode}');
          return response;
        }
      }

      QueryResult<T> result;

      if (filterParams.isEmpty) {
        // No filters - return all items
        result = await _getAllItems(pagination.skip, pagination.take);
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
          authCheck.authResult,
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
  /// Deserializes a JSON request body, calls repository.save(), and returns the
  /// created aggregate as JSON. Content-Type must be application/json and the
  /// Accept header must allow JSON.
  ///
  /// Includes ETag header in response for optimistic concurrency control.
  ///
  /// If auth handler is configured, authenticates the request first.
  /// If authorization handler is configured, authorizes the request after authentication.
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
      final authCheck = await _authenticate(request);
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
        aggregate = preCreate!(aggregate, authCheck.authResult);
      }

      // Authorize if handler is configured
      if (authorizationHandler != null && authCheck.authResult != null) {
        final authzResult = await authorizationHandler!.authorizeCreate(
          aggregate,
          authCheck.authResult!,
        );
        if (!authzResult.isAuthorized) {
          final response = Response(
            403,
            headers: {'Content-Type': 'application/problem+json'},
            body: jsonEncode({
              'type': 'about:blank',
              'title': 'Forbidden',
              'status': 403,
              'detail': authzResult.errorMessage ?? 'Access denied',
            }),
          );
          _logger.fine('POST /$path - ${response.statusCode}');
          return response;
        }
      }

      await repository.save(aggregate);

      // Generate ETag for the created aggregate
      final etag = _etagGenerator.generate(aggregate);

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
  /// Supports optimistic concurrency control via If-Match header:
  /// - If If-Match header is present, validates ETag before updating
  /// - If ETag doesn't match, returns 412 Precondition Failed
  /// - If If-Match is not present, update proceeds without validation
  ///
  /// Includes ETag header in response.
  ///
  /// If auth handler is configured, authenticates the request first.
  /// If authorization handler is configured, authorizes the request after authentication.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The ID string from the URL path
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
      final authCheck = await _authenticate(request);
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

      final uuid = UuidValue.fromString(id);
      if (aggregate.id != uuid) {
        final response = _responseBuilder.badRequest(
          'Route ID $uuid does not match request body ID ${aggregate.id}.',
        );
        _logger.fine('PUT /$path/$id - ${response.statusCode} (ID mismatch)');
        return response;
      }

      // Check If-Match header for optimistic concurrency control
      final ifMatch = request.headers['if-match'];
      if (ifMatch != null) {
        // Fetch current aggregate to validate ETag
        final currentAggregate = await repository.getById(uuid);
        final currentETag = _etagGenerator.generate(currentAggregate);

        if (ifMatch != currentETag) {
          // ETag mismatch - return 412 Precondition Failed
          final response = Response(
            412,
            headers: {
              'Content-Type': 'application/problem+json',
              'ETag': currentETag,
            },
            body: jsonEncode({
              'type': 'about:blank',
              'title': 'Precondition Failed',
              'status': 412,
              'detail': 'Resource was modified by another client. '
                  'The provided ETag does not match the current resource state.',
            }),
          );
          _logger
              .fine('PUT /$path/$id - ${response.statusCode} (ETag mismatch)');
          return response;
        }
      }

      // Authorize if handler is configured
      if (authorizationHandler != null && authCheck.authResult != null) {
        final authzResult = await authorizationHandler!.authorizeUpdate(
          aggregate,
          authCheck.authResult!,
        );
        if (!authzResult.isAuthorized) {
          final response = Response(
            403,
            headers: {'Content-Type': 'application/problem+json'},
            body: jsonEncode({
              'type': 'about:blank',
              'title': 'Forbidden',
              'status': 403,
              'detail': authzResult.errorMessage ?? 'Access denied',
            }),
          );
          _logger.fine('PUT /$path/$id - ${response.statusCode}');
          return response;
        }
      }

      await repository.save(aggregate);

      // Generate ETag for the updated aggregate
      final etag = _etagGenerator.generate(aggregate);

      final response = _responseBuilder.ok(
        aggregate,
        serializer,
        etag: etag,
      );
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
  /// If authorization handler is configured, authorizes the request after authentication.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The ID string from the URL path
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
      final authCheck = await _authenticate(request);
      if (authCheck.response != null) {
        _logger.fine('DELETE /$path/$id - ${authCheck.response!.statusCode}');
        return authCheck.response!;
      }

      final uuid = UuidValue.fromString(id);

      // Authorize if handler is configured
      if (authorizationHandler != null && authCheck.authResult != null) {
        final authzResult = await authorizationHandler!.authorizeDelete(
          uuid,
          authCheck.authResult!,
        );
        if (!authzResult.isAuthorized) {
          final response = Response(
            403,
            headers: {'Content-Type': 'application/problem+json'},
            body: jsonEncode({
              'type': 'about:blank',
              'title': 'Forbidden',
              'status': 403,
              'detail': authzResult.errorMessage ?? 'Access denied',
            }),
          );
          _logger.fine('DELETE /$path/$id - ${response.statusCode}');
          return response;
        }
      }

      await repository.deleteById(uuid);
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

    // Check custom handlers first
    final customHandler = customExceptionHandlers[error.runtimeType];
    if (customHandler != null) {
      return customHandler(error);
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
  /// - Zero take returns empty array
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

  /// Gets all items from the repository with pagination
  ///
  /// Note: This method requires repository item-enumeration capability
  /// (a `getAll()` implementation). For large datasets, prefer registering
  /// dedicated query handlers.
  ///
  /// Parameters:
  /// - [skip]: Number of items to skip
  /// - [take]: Number of items to return (if zero, returns empty array)
  ///
  /// Returns: A QueryResult with paginated items and total count
  Future<QueryResult<T>> _getAllItems(int skip, int take) async {
    final allItems = await getAllItems(
      repository,
      operationName: 'collection query',
    );

    // Handle zero take - return empty array
    if (take == 0) {
      return QueryResult([], totalCount: allItems.length);
    }

    final paginatedItems = allItems.skip(skip).take(take).toList();
    return QueryResult(paginatedItems, totalCount: allItems.length);
  }
}

/// Internal class to hold pagination parameters
class _PaginationParams {
  _PaginationParams(this.skip, this.take);
  final int skip;
  final int take;
}
