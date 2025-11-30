import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Constructs HTTP responses with proper status codes and serialization.
///
/// This class provides methods for building standard HTTP responses for
/// CRUD operations, including success responses with serialized bodies
/// and error responses in RFC 7807 Problem Details format.
///
/// All methods handle serialization and set appropriate Content-Type headers.
class ResponseBuilder<T extends AggregateRoot> {
  /// Builds a 200 OK response with serialized body
  ///
  /// Uses the provided serializer to convert the aggregate to its string
  /// representation and sets the Content-Type header to match the format.
  ///
  /// Parameters:
  /// - [aggregate]: The aggregate root to serialize and return
  /// - [serializer]: The serializer to use for converting the aggregate
  /// - [contentType]: The MIME type to set in the Content-Type header
  ///
  /// Returns: A [Response] with status 200 and serialized body
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.ok(
  ///   user,
  ///   jsonSerializer,
  ///   'application/json',
  /// );
  /// ```
  Response ok(T aggregate, Serializer<T> serializer, String contentType) {
    return Response.ok(
      serializer.serialize(aggregate),
      headers: {'Content-Type': contentType},
    );
  }

  /// Builds a 201 Created response with serialized body
  ///
  /// Uses the provided serializer to convert the newly created aggregate
  /// to its string representation and sets the Content-Type header.
  ///
  /// Parameters:
  /// - [aggregate]: The newly created aggregate root to serialize and return
  /// - [serializer]: The serializer to use for converting the aggregate
  /// - [contentType]: The MIME type to set in the Content-Type header
  ///
  /// Returns: A [Response] with status 201 and serialized body
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.created(
  ///   newUser,
  ///   jsonSerializer,
  ///   'application/json',
  /// );
  /// ```
  Response created(T aggregate, Serializer<T> serializer, String contentType) {
    return Response(
      201,
      body: serializer.serialize(aggregate),
      headers: {'Content-Type': contentType},
    );
  }

  /// Builds a 200 OK response with list of serialized aggregates
  ///
  /// Serializes each aggregate in the list and wraps them in a JSON array.
  /// Includes an X-Total-Count header if totalCount is provided, which is
  /// useful for pagination.
  ///
  /// Parameters:
  /// - [aggregates]: The list of aggregate roots to serialize and return
  /// - [serializer]: The serializer to use for converting each aggregate
  /// - [contentType]: The MIME type to set in the Content-Type header
  /// - [totalCount]: Optional total count of all matching items (for pagination)
  ///
  /// Returns: A [Response] with status 200, JSON array body, and optional X-Total-Count header
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.okList(
  ///   users,
  ///   jsonSerializer,
  ///   'application/json',
  ///   totalCount: 150,
  /// );
  /// ```
  Response okList(
    List<T> aggregates,
    Serializer<T> serializer,
    String contentType, {
    int? totalCount,
  }) {
    final headers = {'Content-Type': contentType};
    if (totalCount != null) {
      headers['X-Total-Count'] = totalCount.toString();
    }

    // Serialize each aggregate and collect as a list
    final serializedList =
        aggregates.map((a) => serializer.serialize(a)).toList();

    // Parse each serialized string as JSON and encode the array
    final jsonList = serializedList.map(jsonDecode).toList();

    return Response.ok(
      jsonEncode(jsonList),
      headers: headers,
    );
  }

  /// Builds a 204 No Content response
  ///
  /// Returns an empty response with no body, typically used for successful
  /// DELETE operations.
  ///
  /// Returns: A [Response] with status 204 and no body
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.noContent();
  /// ```
  Response noContent() {
    return Response(204);
  }

  /// Builds a 400 Bad Request response using RFC 7807 format
  ///
  /// Creates a standardized error response following RFC 7807 Problem Details
  /// format with type, title, status, and detail fields.
  ///
  /// Parameters:
  /// - [message]: Human-readable explanation of the bad request
  ///
  /// Returns: A [Response] with status 400 and RFC 7807 formatted JSON body
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.badRequest(
  ///   'Cannot combine multiple query parameters',
  /// );
  /// ```
  Response badRequest(String message) {
    return Response(
      400,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Bad Request',
        'status': 400,
        'detail': message,
      }),
    );
  }

  /// Builds a 404 Not Found response using RFC 7807 format
  ///
  /// Creates a standardized error response following RFC 7807 Problem Details
  /// format with type, title, status, and detail fields.
  ///
  /// Parameters:
  /// - [message]: Human-readable explanation of what was not found
  ///
  /// Returns: A [Response] with status 404 and RFC 7807 formatted JSON body
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.notFound(
  ///   'User with ID 123e4567-... not found',
  /// );
  /// ```
  Response notFound(String message) {
    return Response(
      404,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Not Found',
        'status': 404,
        'detail': message,
      }),
    );
  }

  /// Builds a 401 Unauthorized response using RFC 7807 format
  ///
  /// Creates a standardized error response following RFC 7807 Problem Details
  /// format with type, title, status, and detail fields.
  ///
  /// This method ensures that error messages do not expose sensitive
  /// information such as signing secrets, expected signatures, or internal
  /// system details.
  ///
  /// Parameters:
  /// - [message]: Human-readable explanation of the authentication failure
  ///
  /// Returns: A [Response] with status 401 and RFC 7807 formatted JSON body
  ///
  /// Example:
  /// ```dart
  /// final response = responseBuilder.unauthorized(
  ///   'Token has expired',
  /// );
  /// ```
  Response unauthorized(String message) {
    return Response(
      401,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Unauthorized',
        'status': 401,
        'detail': message,
      }),
    );
  }
}
