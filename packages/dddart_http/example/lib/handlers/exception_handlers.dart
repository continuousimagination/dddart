import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../exceptions/user_exceptions.dart';

/// Custom exception handler for InvalidEmailException
/// 
/// CUSTOM EXCEPTION HANDLER PATTERN:
/// Exception handlers map domain exceptions to HTTP responses. They are registered
/// with the CrudResource and checked before the built-in error handling.
/// 
/// HOW EXCEPTION HANDLERS WORK:
/// 
/// 1. REGISTRATION:
///    In main.dart, this handler is registered as:
///    customExceptionHandlers: {
///      InvalidEmailException: handleInvalidEmailException,
///    }
///    
/// 2. EXCEPTION FLOW:
///    a. Domain code throws InvalidEmailException
///    b. CrudResource catches the exception in try-catch block
///    c. CrudResource checks customExceptionHandlers map
///    d. Finds matching handler and invokes it
///    e. Handler returns Response with appropriate status code and body
///    f. Response is sent to client
///    
/// 3. FALLBACK:
///    If no custom handler is found, CrudResource falls back to ErrorMapper
///    which handles framework exceptions (RepositoryException, etc.)
///    
/// 4. RFC 7807 FORMAT:
///    All error responses should follow RFC 7807 Problem Details format:
///    - type: URI identifying the problem type (use "about:blank" for generic)
///    - title: Short, human-readable summary
///    - status: HTTP status code (must match response status)
///    - detail: Human-readable explanation specific to this occurrence
///    
/// HTTP STATUS CODE: 400 Bad Request
/// - Used for client errors where the request is malformed or invalid
/// - Indicates the client should not retry without modification
/// - Examples: invalid email format, missing required field, invalid date format
/// 
/// PRODUCTION CONSIDERATIONS:
/// - Sanitize error messages to avoid leaking sensitive information
/// - Log full exception details server-side for debugging
/// - Consider internationalization for error messages
/// - Add 'instance' field to RFC 7807 response for error tracking
Response handleInvalidEmailException(Object error) {
  // Cast the error to the specific exception type
  // This is safe because the handler is only invoked for InvalidEmailException
  final exception = error as InvalidEmailException;
  
  // Return HTTP 400 Bad Request with RFC 7807 Problem Details format
  return Response(
    400,
    headers: {'Content-Type': 'application/problem+json'},
    body: jsonEncode({
      'type': 'about:blank',
      'title': 'Invalid Email',
      'status': 400,
      'detail': 'The provided email address is not valid: ${exception.email}',
    }),
  );
}

/// Custom exception handler for DuplicateEmailException
/// 
/// DUPLICATE EMAIL HANDLER:
/// Maps DuplicateEmailException to HTTP 409 Conflict response.
/// 
/// HTTP STATUS CODE: 409 Conflict
/// - Used when the request conflicts with the current state of the server
/// - Indicates a uniqueness constraint violation
/// - Different from 400 (bad input) or 422 (unprocessable entity)
/// - Client can retry with different data (different email)
/// 
/// EXCEPTION HANDLER PRIORITY:
/// Custom exception handlers are checked BEFORE built-in handlers:
/// 1. Check customExceptionHandlers map (this handler)
/// 2. If not found, check ErrorMapper for framework exceptions
/// 3. If not found, return generic 500 Internal Server Error
/// 
/// This allows you to override default behavior for specific exceptions.
/// 
/// EXAMPLE FLOW:
/// 1. Client: POST /users with email "john@example.com"
/// 2. Repository: Checks if email exists, throws DuplicateEmailException
/// 3. CrudResource: Catches exception, finds this handler
/// 4. Handler: Returns 409 response with clear error message
/// 5. Client: Receives error, prompts user to use different email
/// 
/// SECURITY NOTE:
/// Revealing which emails exist can be a security issue (email enumeration).
/// In production, consider:
/// - Generic error message: "Registration failed"
/// - Rate limiting on registration endpoint
/// - CAPTCHA for repeated failures
/// - Log actual email server-side for debugging
Response handleDuplicateEmailException(Object error) {
  // Cast the error to the specific exception type
  final exception = error as DuplicateEmailException;
  
  // Return HTTP 409 Conflict with RFC 7807 Problem Details format
  return Response(
    409,
    headers: {'Content-Type': 'application/problem+json'},
    body: jsonEncode({
      'type': 'about:blank',
      'title': 'Duplicate Email',
      'status': 409,
      'detail': 'A user with email ${exception.email} already exists',
    }),
  );
}
