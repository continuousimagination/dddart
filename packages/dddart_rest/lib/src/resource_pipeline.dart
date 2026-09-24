import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/authorization_handler.dart';
import 'package:dddart_rest/src/authorization_result.dart';
import 'package:dddart_rest/src/error_mapper.dart';
import 'package:dddart_rest/src/exceptions.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

/// Internal, immutable request machinery shared by both resource contracts.
/// Authentication results are passed to local closures, never stored per resource.
@internal
class ResourcePipeline<T extends AggregateRoot, TClaims> {
  /// Freezes trusted configuration and rejects authorization without authentication.
  ResourcePipeline({
    required this.path,
    required Map<String, Serializer<T>> serializers,
    this.authenticationHandler,
    this.authorizationHandler,
    this.jsonContract = false,
    Map<Type, Response Function(Object)> customExceptionHandlers = const {},
  }) : serializers = Map.unmodifiable(serializers),
       customExceptionHandlers = Map.unmodifiable(customExceptionHandlers) {
    if (path.isEmpty) throw ArgumentError('path cannot be empty');
    if (serializers.isEmpty) {
      throw ArgumentError(
        'serializers map cannot be empty. At least one serializer must be provided.',
      );
    }
    if (authorizationHandler != null && authenticationHandler == null) {
      throw ArgumentError('Authorization requires an authentication handler');
    }
  }

  /// Fixed route prefix.
  final String path;

  /// Immutable supported representations.
  final Map<String, Serializer<T>> serializers;

  /// Trusted admission policy.
  final AuthenticationHandler<TClaims>? authenticationHandler;

  /// Trusted operation policy.
  final AuthorizationHandler<T, TClaims>? authorizationHandler;

  /// Existing trusted application exception customization.
  final Map<Type, Response Function(Object)> customExceptionHandlers;

  /// The canonical JSON constructor validates media before authentication.
  final bool jsonContract;
  final _logger = Logger('dddart.rest');

  /// Authenticates once, invokes request-local work, and safely maps failures.
  Future<Response> run(
    Request request,
    String operation,
    Future<Response> Function(AuthenticationResult<TClaims>?) action,
  ) async {
    final query = request.url.query.isEmpty ? '' : '?[query]';
    _logger.info('${request.method} /$path$query - $operation $T');
    try {
      if (jsonContract) {
        select(request.headers['accept']);
        if (request.method == 'POST' || request.method == 'PUT') {
          final media = (request.headers['content-type'] ?? '')
              .split(';')
              .first
              .trim()
              .toLowerCase();
          if (media != 'application/json') throw _RequestMediaFailure(media);
        }
      }
      AuthenticationResult<TClaims>? principal;
      if (authenticationHandler != null) {
        principal = await authenticationHandler!.authenticate(request);
        if (!principal.isAuthenticated) {
          final response = problem(
            401,
            'Unauthorized',
            principal.errorMessage ?? 'Authentication required',
          );
          _logger.fine('${request.method} /$path - ${response.statusCode}');
          return response;
        }
      }
      final response = await action(principal);
      _logger.fine('${request.method} /$path - ${response.statusCode}');
      return response;
    } catch (error, stack) {
      if (error is _RequestMediaFailure) {
        final response = problem(
          415,
          'Unsupported Media Type',
          'Content-Type ${error.mediaType} is not supported. Supported types: ${serializers.keys.join(", ")}',
        );
        _logger.fine('${request.method} /$path - ${response.statusCode}');
        return response;
      }
      _logger.severe('Exception during request handling');
      final custom = customExceptionHandlers[error.runtimeType];
      if (custom != null) return custom(error);
      return ErrorMapper.mapException(error, stack);
    }
  }

  /// Authorizes an operation without inventing authority from request metadata.
  Future<Response?> authorize(
    AuthenticationResult<TClaims>? principal,
    Future<AuthorizationResult> Function(
      AuthorizationHandler<T, TClaims>,
      AuthenticationResult<TClaims>,
    )
    check, {
    bool includeMessage = true,
  }) async {
    final policy = authorizationHandler;
    if (policy == null) return null;
    if (principal == null || !principal.isAuthenticated) {
      throw StateError('Missing authenticated principal');
    }
    final result = await check(policy, principal);
    return result.isAuthorized
        ? null
        : problem(
            403,
            'Forbidden',
            includeMessage
                ? (result.errorMessage ?? 'Access denied')
                : 'Access denied',
          );
  }

  /// Decodes through the configured request codec; parse failures stay input errors.
  Future<T> deserialize(
    Request request, {
    void Function(String)? validateInput,
  }) async {
    final media = (request.headers['content-type'] ?? serializers.keys.first)
        .split(';')
        .first
        .trim()
        .toLowerCase();
    final matches = serializers.entries.where(
      (entry) => entry.key.toLowerCase() == media,
    );
    if (matches.isEmpty) throw _RequestMediaFailure(media);
    try {
      final body = await request.readAsString();
      validateInput?.call(body);
      return matches.first.value.deserialize(body);
    } catch (_) {
      _logger.warning('${request.method} /$path - Deserialization failed');
      rethrow;
    }
  }

  /// Once mutation is invoked, an unclassified implementation failure cannot
  /// safely be reported as rejected request input. Known typed repository and
  /// explicitly configured application failures retain their contracts.
  Future<R> persist<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on RepositoryException {
      rethrow;
    } catch (error) {
      if (customExceptionHandlers.containsKey(error.runtimeType)) rethrow;
      throw const RepositoryException('Write outcome unavailable');
    }
  }

  /// Selects a response representation before any mutation.
  ResourceSerialization<T> select(String? accept) {
    if (accept == null || accept.trim().isEmpty) {
      final first = serializers.entries.first;
      return ResourceSerialization(first.value, first.key);
    }
    ResourceSerialization<T>? selected;
    var selectedQuality = 0.0;
    for (final entry in serializers.entries) {
      var specificity = -1;
      var quality = 0.0;
      for (final part in accept.split(',')) {
        final segments = part.trim().split(';');
        final media = segments.first.trim().toLowerCase();
        final candidateSpecificity = media == entry.key.toLowerCase()
            ? 2
            : media == '${entry.key.split('/').first.toLowerCase()}/*'
            ? 1
            : media == '*/*'
            ? 0
            : -1;
        if (candidateSpecificity < 0) continue;
        var candidateQuality = 1.0;
        for (final parameter in segments.skip(1)) {
          final pair = parameter.trim().split('=');
          if (pair.first.trim().toLowerCase() != 'q') continue;
          candidateQuality = pair.length == 2
              ? double.tryParse(pair.last.trim()) ?? 0
              : 0;
          if (!candidateQuality.isFinite ||
              candidateQuality < 0 ||
              candidateQuality > 1) {
            candidateQuality = 0;
          }
          break;
        }
        if (candidateSpecificity > specificity ||
            (candidateSpecificity == specificity &&
                candidateQuality > quality)) {
          specificity = candidateSpecificity;
          quality = candidateQuality;
        }
      }
      if (quality > selectedQuality) {
        selectedQuality = quality;
        selected = ResourceSerialization(entry.value, entry.key);
      }
    }
    if (selected != null) return selected;
    throw UnsupportedMediaTypeException('Unsupported response representation');
  }

  /// Encodes response-side validation/serialization failures only as server errors.
  /// A post-save failure must never falsely signal rejected input.
  Response respond(
    T value,
    ResourceSerialization<T> representation, {
    int status = 200,
    UuidValue? expectedId,
    void Function()? validate,
    String? Function()? etag,
  }) {
    try {
      if (expectedId != null && value.id != expectedId) {
        throw StateError('Mismatched response identity');
      }
      validate?.call();
      final validator = etag?.call();
      final body = representation.serializer.serialize(value);
      return Response(
        status,
        body: body,
        headers: {
          'Content-Type': representation.contentType,
          if (validator != null) 'ETag': validator,
        },
      );
    } catch (_) {
      throw const SerializationException('Response serialization failed');
    }
  }

  /// Serializes a legacy collection using the same safe response boundary.
  Response respondList(
    List<T> values,
    ResourceSerialization<T> representation, {
    int? totalCount,
  }) {
    try {
      final body = jsonEncode(
        values
            .map(
              (value) => jsonDecode(representation.serializer.serialize(value)),
            )
            .toList(),
      );
      return Response.ok(
        body,
        headers: {
          'Content-Type': representation.contentType,
          if (totalCount != null) 'X-Total-Count': '$totalCount',
        },
      );
    } catch (_) {
      throw const SerializationException('Response serialization failed');
    }
  }

  /// Shared problem-details construction without captured request data.
  static Response problem(int status, String title, String detail) => Response(
    status,
    headers: {'Content-Type': 'application/problem+json'},
    body: jsonEncode({
      'type': 'about:blank',
      'title': title,
      'status': status,
      'detail': detail,
    }),
  );
}

/// Internal selected representation, local to one operation.
@internal
class ResourceSerialization<T> {
  /// Associates a codec and its fixed media type.
  const ResourceSerialization(this.serializer, this.contentType);

  /// Selected codec.
  final Serializer<T> serializer;

  /// Selected media type.
  final String contentType;
}

class _RequestMediaFailure implements Exception {
  const _RequestMediaFailure(this.mediaType);
  final String mediaType;
}
