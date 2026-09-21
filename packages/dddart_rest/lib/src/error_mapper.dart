import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/exceptions.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Maps domain exceptions to HTTP responses using RFC 7807 Problem Details format.
///
/// This class provides a centralized mechanism for converting exceptions thrown
/// during request processing into appropriate HTTP responses with standardized
/// error formatting.
///
/// All error responses follow RFC 7807 Problem Details format with:
/// - type: URI reference identifying the problem type
/// - title: Short, human-readable summary
/// - status: HTTP status code
/// - detail: Human-readable explanation specific to this occurrence
class ErrorMapper {
  /// Maps an exception to an appropriate HTTP Response.
  ///
  /// This method handles built-in framework exceptions and provides
  /// sensible defaults for unknown exceptions.
  ///
  /// Supported exception types:
  /// - [RepositoryException]: Maps based on exception type (404, 409, 422, 500)
  /// - [DeserializationException]: Maps to 400 Bad Request
  /// - [SerializationException]: Maps to 500 Internal Server Error
  /// - [UnsupportedMediaTypeException]: Maps to 406 Not Acceptable
  /// - Unknown exceptions: Maps to 500 Internal Server Error
  ///
  /// Parameters:
  /// - [error]: The exception that was thrown
  /// - [stackTrace]: The stack trace associated with the exception
  ///
  /// Returns: A [Response] object with appropriate status code and RFC 7807 body
  static Response mapException(Object error, StackTrace stackTrace) {
    if (error is PreconditionFailedException) {
      return _problemResponse(
        412,
        'Precondition Failed',
        'Write precondition failed',
      );
    } else if (error is PreconditionRequiredException) {
      return _problemResponse(
        428,
        'Precondition Required',
        'Write precondition required',
      );
    } else if (error is RepositoryCapabilityException) {
      return _problemResponse(
        501,
        'Not Implemented',
        'Repository capability unavailable',
      );
    } else if (error is RevisionCapacityException) {
      return _problemResponse(
        413,
        'Content Too Large',
        'Revision capacity exceeded',
        code: 'capacityExceeded',
      );
    } else if (error is RepositoryException) {
      return _mapRepositoryException(error);
    } else if (error is DeserializationException) {
      return _problemResponse(400, 'Bad Request', 'Invalid request data');
    } else if (error is SerializationException) {
      return _problemResponse(
        500,
        'Internal Server Error',
        'Response serialization failed',
      );
    } else if (error is UnsupportedMediaTypeException) {
      return _problemResponse(406, 'Not Acceptable', 'Invalid request data');
    } else if (error is FormatException) {
      return _problemResponse(400, 'Bad Request', 'Invalid request format');
    } else if (error is ArgumentError) {
      return _problemResponse(400, 'Bad Request', 'Invalid request argument');
    } else {
      // Unknown exception - return generic 500 error
      return _problemResponse(
        500,
        'Internal Server Error',
        'An unexpected error occurred',
      );
    }
  }

  /// Maps a [RepositoryException] to an appropriate HTTP response.
  ///
  /// Maps exception types to HTTP status codes:
  /// - notFound → 404 Not Found
  /// - duplicate → 409 Conflict
  /// - constraint → 422 Unprocessable Entity
  /// - other types → 500 Internal Server Error
  static Response _mapRepositoryException(RepositoryException e) {
    switch (e.type) {
      case RepositoryExceptionType.notFound:
        return _problemResponse(404, 'Not Found', 'Resource not found');
      case RepositoryExceptionType.duplicate:
        return _problemResponse(409, 'Conflict', 'Resource conflict');
      case RepositoryExceptionType.constraint:
        return _problemResponse(
          422,
          'Unprocessable Entity',
          'Constraint violation',
        );
      default:
        return _problemResponse(
          500,
          'Internal Server Error',
          'Repository operation failed',
        );
    }
  }

  /// Creates an RFC 7807 Problem Details response.
  ///
  /// Parameters:
  /// - [status]: HTTP status code
  /// - [title]: Short, human-readable summary of the problem type
  /// - [detail]: Human-readable explanation specific to this occurrence
  ///
  /// Returns: A [Response] with RFC 7807 formatted JSON body
  static Response _problemResponse(
    int status,
    String title,
    String detail, {
    String? code,
  }) {
    return Response(
      status,
      headers: {'Content-Type': 'application/problem+json'},
      body: jsonEncode({
        'type': 'about:blank',
        'title': title,
        'status': status,
        'detail': detail,
        if (code != null) 'code': code,
      }),
    );
  }
}
