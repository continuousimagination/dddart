import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/error_mapper.dart';
import 'package:dddart_rest/src/exceptions.dart';
import 'package:dddart_rest/src/query_handler.dart';
import 'package:dddart_rest/src/response_builder.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Main class that handles HTTP CRUD operations for an aggregate root.
///
/// CrudResource combines configuration (repository, serializers, query handlers)
/// with request handling logic for standard CRUD operations. Each instance is
/// configured for a specific aggregate type and can be registered with an HTTP server.
///
/// Example:
/// ```dart
/// final userResource = CrudResource<User>(
///   path: '/users',
///   repository: userRepository,
///   serializers: {
///     'application/json': jsonSerializer,
///     'application/yaml': yamlSerializer,
///   },
///   queryHandlers: {
///     'firstName': firstNameHandler,
///     'email': emailHandler,
///   },
///   defaultSkip: 0,
///   defaultTake: 20,
///   maxTake: 100,
/// );
/// ```
class CrudResource<T extends AggregateRoot> {
  /// Creates a CrudResource with the specified configuration
  ///
  /// Parameters:
  /// - [path]: The base path for this resource (e.g., '/users')
  /// - [repository]: Repository instance for persistence operations
  /// - [serializers]: Map of content types to serializers for content negotiation
  /// - [queryHandlers]: Map of query parameter names to handler functions
  /// - [customExceptionHandlers]: Map of exception types to error response handlers
  /// - [defaultSkip]: Default skip value for pagination (defaults to 0)
  /// - [defaultTake]: Default take value for pagination (defaults to 50)
  /// - [maxTake]: Maximum allowed take value to prevent excessive queries (defaults to 100)
  ///
  /// Throws [ArgumentError] if:
  /// - [path] is null or empty
  /// - [serializers] map is empty
  CrudResource({
    required this.path,
    required this.repository,
    required this.serializers,
    this.queryHandlers = const {},
    this.customExceptionHandlers = const {},
    this.defaultSkip = 0,
    this.defaultTake = 50,
    this.maxTake = 100,
  }) {
    // Validate path is not null or empty
    if (path.isEmpty) {
      throw ArgumentError('path cannot be empty');
    }

    // Validate serializers map is not empty
    if (serializers.isEmpty) {
      throw ArgumentError(
          'serializers map cannot be empty. At least one serializer must be provided.',);
    }
  }

  /// The base path for this resource (e.g., '/users')
  final String path;

  /// Repository instance for persistence operations
  ///
  /// All repositories implement Repository<T> interface with getById, save, deleteById methods
  final Repository<T> repository;

  /// Map of content types to serializers for content negotiation
  ///
  /// Key: MIME type (e.g., 'application/json', 'application/yaml')
  /// Value: Serializer instance for that content type
  /// The first entry is used as the default for responses when Accept header is */* or missing
  /// At least one serializer must be provided
  final Map<String, Serializer<T>> serializers;

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

  /// ResponseBuilder instance for creating HTTP responses
  late final ResponseBuilder<T> _responseBuilder = ResponseBuilder<T>();

  /// Logger instance for REST API request/response logging
  final Logger _logger = Logger('dddart.rest');

  /// Handles GET /resource/:id
  ///
  /// Parses the ID, calls repository.getById(), and returns serialized aggregate
  /// Uses Accept header for content negotiation
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The ID string from the URL path
  ///
  /// Returns: A Response with status 200 and serialized aggregate, or error response
  Future<Response> handleGetById(Request request, String id) async {
    _logger.info('GET /$path/$id - Retrieving $T');
    try {
      final uuid = UuidValue.fromString(id);
      final aggregate = await repository.getById(uuid);
      final serializerEntry = _selectSerializer(request.headers['accept']);
      final response = _responseBuilder.ok(
        aggregate,
        serializerEntry.serializer,
        serializerEntry.contentType,
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
  /// Parameters:
  /// - [request]: The HTTP request
  ///
  /// Returns: A Response with status 200 and serialized array, or error response
  Future<Response> handleQuery(Request request) async {
    final queryString =
        request.url.query.isEmpty ? '' : '?${request.url.query}';
    _logger.info('GET /$path$queryString - Querying $T');
    try {
      final queryParams = request.url.queryParameters;
      final pagination = _parsePagination(queryParams);

      // Remove pagination params for handler matching
      final filterParams = Map<String, String>.from(queryParams)
        ..remove('skip')
        ..remove('take');

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
        );
      }

      final serializerEntry = _selectSerializer(request.headers['accept']);
      final response = _responseBuilder.okList(
        result.items,
        serializerEntry.serializer,
        serializerEntry.contentType,
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
  /// Deserializes request body using Content-Type header, calls repository.save(),
  /// returns created aggregate. Uses Accept header for response content negotiation.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  ///
  /// Returns: A Response with status 201 and serialized aggregate, or error response
  Future<Response> handleCreate(Request request) async {
    _logger.info('POST /$path - Creating $T');
    try {
      final contentTypeHeader =
          request.headers['content-type'] ?? serializers.keys.first;
      // Extract media type, removing charset and other parameters
      final contentType = _extractMediaType(contentTypeHeader);

      // Case-insensitive lookup
      Serializer<T>? requestSerializer;
      for (final entry in serializers.entries) {
        if (entry.key.toLowerCase() == contentType.toLowerCase()) {
          requestSerializer = entry.value;
          break;
        }
      }

      if (requestSerializer == null) {
        final response = Response(
          415,
          headers: {'Content-Type': 'application/problem+json'},
          body: jsonEncode({
            'type': 'about:blank',
            'title': 'Unsupported Media Type',
            'status': 415,
            'detail': 'Content-Type $contentType is not supported. '
                'Supported types: ${serializers.keys.join(", ")}',
          }),
        );
        _logger.fine('POST /$path - ${response.statusCode}');
        return response;
      }

      final body = await request.readAsString();
      T aggregate;
      try {
        aggregate = requestSerializer.deserialize(body);
      } catch (e) {
        _logger.warning('POST /$path - Deserialization failed: $e');
        rethrow;
      }
      await repository.save(aggregate);

      final responseSerializerEntry =
          _selectSerializer(request.headers['accept']);
      final response = _responseBuilder.created(
        aggregate,
        responseSerializerEntry.serializer,
        responseSerializerEntry.contentType,
      );
      _logger.fine('POST /$path - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Handles PUT /resource/:id
  ///
  /// Deserializes request body using Content-Type header, calls repository.save(),
  /// returns updated aggregate. Uses Accept header for response content negotiation.
  ///
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The ID string from the URL path
  ///
  /// Returns: A Response with status 200 and serialized aggregate, or error response
  Future<Response> handleUpdate(Request request, String id) async {
    _logger.info('PUT /$path/$id - Updating $T');
    try {
      final contentTypeHeader =
          request.headers['content-type'] ?? serializers.keys.first;
      // Extract media type, removing charset and other parameters
      final contentType = _extractMediaType(contentTypeHeader);

      // Case-insensitive lookup
      Serializer<T>? requestSerializer;
      for (final entry in serializers.entries) {
        if (entry.key.toLowerCase() == contentType.toLowerCase()) {
          requestSerializer = entry.value;
          break;
        }
      }

      if (requestSerializer == null) {
        final response = Response(
          415,
          headers: {'Content-Type': 'application/problem+json'},
          body: jsonEncode({
            'type': 'about:blank',
            'title': 'Unsupported Media Type',
            'status': 415,
            'detail': 'Content-Type $contentType is not supported. '
                'Supported types: ${serializers.keys.join(", ")}',
          }),
        );
        _logger.fine('PUT /$path/$id - ${response.statusCode}');
        return response;
      }

      final body = await request.readAsString();
      T aggregate;
      try {
        aggregate = requestSerializer.deserialize(body);
      } catch (e) {
        _logger.warning('PUT /$path/$id - Deserialization failed: $e');
        rethrow;
      }
      await repository.save(aggregate);

      final responseSerializerEntry =
          _selectSerializer(request.headers['accept']);
      final response = _responseBuilder.ok(
        aggregate,
        responseSerializerEntry.serializer,
        responseSerializerEntry.contentType,
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
  /// Parameters:
  /// - [request]: The HTTP request
  /// - [id]: The ID string from the URL path
  ///
  /// Returns: A Response with status 204, or error response
  Future<Response> handleDelete(Request request, String id) async {
    _logger.info('DELETE /$path/$id - Deleting $T');
    try {
      final uuid = UuidValue.fromString(id);
      await repository.deleteById(uuid);
      final response = _responseBuilder.noContent();
      _logger.fine('DELETE /$path/$id - ${response.statusCode}');
      return response;
    } catch (e, stackTrace) {
      return _handleException(e, stackTrace);
    }
  }

  /// Selects appropriate serializer based on Accept header
  ///
  /// Returns first serializer (default) if Accept is */*, missing, or empty.
  /// Throws UnsupportedMediaTypeException if Accept header specifies unsupported type.
  ///
  /// Edge cases handled:
  /// - Parses quality values (q=) and selects highest priority supported type
  /// - Case-insensitive media type matching
  ///
  /// Parameters:
  /// - [acceptHeader]: The Accept header value from the request
  ///
  /// Returns: A _SerializerEntry containing the serializer and content type
  _SerializerEntry<T> _selectSerializer(String? acceptHeader) {
    if (acceptHeader == null || acceptHeader == '*/*' || acceptHeader.isEmpty) {
      final firstEntry = serializers.entries.first;
      return _SerializerEntry(firstEntry.value, firstEntry.key);
    }

    // Parse Accept header with quality values
    final acceptedTypes = <_AcceptType>[];
    for (final part in acceptHeader.split(',')) {
      final segments = part.trim().split(';');
      final mediaType = segments.first.trim();

      // Parse quality value (default to 1.0)
      var quality = 1.0;
      for (var i = 1; i < segments.length; i++) {
        final param = segments[i].trim();
        if (param.startsWith('q=')) {
          quality = double.tryParse(param.substring(2)) ?? 1.0;
          break;
        }
      }

      acceptedTypes.add(_AcceptType(mediaType, quality));
    }

    // Sort by quality (highest first)
    acceptedTypes.sort((a, b) => b.quality.compareTo(a.quality));

    // Try to match in order of quality
    for (final acceptedType in acceptedTypes) {
      if (acceptedType.mediaType == '*/*') {
        final firstEntry = serializers.entries.first;
        return _SerializerEntry(firstEntry.value, firstEntry.key);
      }

      // Case-insensitive matching
      for (final entry in serializers.entries) {
        if (entry.key.toLowerCase() == acceptedType.mediaType.toLowerCase()) {
          return _SerializerEntry(entry.value, entry.key);
        }
      }
    }

    // No match found - throw exception that will be caught and converted to 406
    throw UnsupportedMediaTypeException(
      'Accept header specifies unsupported media type(s): $acceptHeader. '
      'Supported types: ${serializers.keys.join(", ")}',
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
  /// Note: This method requires the repository to be an InMemoryRepository
  /// or implement a getAll() method. For production use, consider implementing
  /// a custom query handler instead.
  ///
  /// Parameters:
  /// - [skip]: Number of items to skip
  /// - [take]: Number of items to return (if zero, returns empty array)
  ///
  /// Returns: A QueryResult with paginated items and total count
  Future<QueryResult<T>> _getAllItems(int skip, int take) async {
    // InMemoryRepository has a synchronous getAll() method
    // For other repository types, you should register a query handler
    if (repository is InMemoryRepository<T>) {
      final allItems = (repository as InMemoryRepository<T>).getAll();

      // Handle zero take - return empty array
      if (take == 0) {
        return QueryResult([], totalCount: allItems.length);
      }

      final paginatedItems = allItems.skip(skip).take(take).toList();
      return QueryResult(paginatedItems, totalCount: allItems.length);
    }

    throw UnsupportedError(
      'Repository does not support getAll(). '
      'Please register a query handler for collection queries.',
    );
  }
}

/// Internal class to hold pagination parameters
class _PaginationParams {
  _PaginationParams(this.skip, this.take);
  final int skip;
  final int take;
}

/// Internal class to hold serializer and content type together
class _SerializerEntry<T extends AggregateRoot> {
  _SerializerEntry(this.serializer, this.contentType);
  final Serializer<T> serializer;
  final String contentType;
}

/// Internal class to hold Accept header media type with quality value
class _AcceptType {
  _AcceptType(this.mediaType, this.quality);
  final String mediaType;
  final double quality;
}
