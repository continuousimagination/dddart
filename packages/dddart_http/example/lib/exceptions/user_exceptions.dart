/// Custom domain exception for invalid email format
/// 
/// CUSTOM DOMAIN EXCEPTION PATTERN:
/// Domain exceptions represent business rule violations or domain-specific errors.
/// They are different from technical exceptions (IOException, NetworkException, etc.)
/// and should be mapped to appropriate HTTP responses.
/// 
/// WHY CUSTOM EXCEPTIONS?
/// - Express domain concepts in code (InvalidEmail is clearer than ArgumentError)
/// - Allow specific HTTP status codes (400 for invalid input vs 500 for system error)
/// - Provide domain-specific error messages to clients
/// - Enable different handling for different business rules
/// 
/// USAGE:
/// In your domain logic or repository:
///   if (!isValidEmail(email)) {
///     throw InvalidEmailException(email);
///   }
/// 
/// The exception handler (in exception_handlers.dart) maps this to:
///   HTTP 400 Bad Request with RFC 7807 error response
/// 
/// WHEN TO USE:
/// - Input validation failures (invalid format, out of range, etc.)
/// - Business rule violations (age too young, insufficient funds, etc.)
/// - Precondition failures (account not active, user not verified, etc.)
class InvalidEmailException implements Exception {
  /// Creates an InvalidEmailException with the invalid email value
  InvalidEmailException(this.email);

  /// The email address that failed validation
  final String email;

  @override
  String toString() => 'Invalid email format: $email';
}

/// Custom domain exception for duplicate email
/// 
/// DUPLICATE EMAIL EXCEPTION:
/// This exception represents a uniqueness constraint violation - attempting to
/// create or update a user with an email that already exists in the system.
/// 
/// HTTP STATUS CODE MAPPING:
/// - 409 Conflict: The request conflicts with the current state of the server
/// - This is the standard status for uniqueness violations
/// - Different from 400 (bad input) or 422 (unprocessable entity)
/// 
/// USAGE SCENARIO:
/// 1. Client sends POST /users with email "john@example.com"
/// 2. Repository checks if email already exists
/// 3. If exists, throws DuplicateEmailException
/// 4. Exception handler catches it and returns 409 Conflict
/// 5. Client receives clear error message and can prompt user to use different email
/// 
/// ALTERNATIVE APPROACHES:
/// - Could use RepositoryException with type 'duplicate'
/// - Custom exception provides more type safety and clarity
/// - Allows domain-specific error messages
/// 
/// PRODUCTION CONSIDERATIONS:
/// - Consider security: don't reveal which emails exist (email enumeration attack)
/// - Might return generic "registration failed" message instead
/// - Log the actual email for debugging but sanitize client response
class DuplicateEmailException implements Exception {
  /// Creates a DuplicateEmailException with the duplicate email value
  DuplicateEmailException(this.email);

  /// The email address that already exists in the system
  final String email;

  @override
  String toString() => 'Email already exists: $email';
}
