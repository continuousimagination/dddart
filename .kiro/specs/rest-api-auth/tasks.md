# Implementation Plan

- [x] 1. Set up dddart_rest authentication infrastructure
  - Create base authentication types and interfaces
  - Set up code generation for JWT claims serialization
  - _Requirements: All_

- [x] 1.1 Create core authentication types
  - Create `AuthHandler<TClaims>` abstract base class
  - Create `AuthResult<TClaims>` class
  - Create `Tokens` class for token responses
  - _Requirements: 1.2, 1.5_

- [x] 1.2 Create RefreshToken and DeviceCode aggregate roots
  - Create `RefreshToken` class extending `AggregateRoot` with @Serializable()
  - Create `DeviceCode` class extending `AggregateRoot` with @Serializable()
  - Create `DeviceCodeStatus` enum
  - Add domain methods (isValid, revoke, approve)
  - _Requirements: 2.3, 4.1, 6.1_

- [x] 1.3 Set up JWT claims code generation
  - Create `@JwtSerializable()` annotation
  - Create code generator for JWT claims extension methods
  - Generate `parseClaimsFromJson` and `claimsToJson` extensions on `JwtAuthHandler`
  - Create `StandardClaims` class with generated extensions
  - _Requirements: 12.1, 12.2, 12.3_

- [x] 2. Implement JwtAuthHandler for self-hosted authentication
  - Implement JWT signing, validation, and token management
  - _Requirements: 2.1, 2.2, 2.4, 2.5, 2.6_

- [x] 2.1 Implement JWT token operations
  - Implement JWT signing with HMAC-SHA256
  - Implement JWT validation (signature, expiration, issuer, audience)
  - Implement claims extraction using generated extension methods
  - _Requirements: 1.3, 1.4, 2.2, 11.5_

- [x] 2.2 Implement authenticate method
  - Extract Bearer token from Authorization header
  - Validate JWT and extract claims
  - Return `AuthResult<TClaims>` with user identity
  - Handle authentication errors with proper error messages
  - _Requirements: 1.2, 1.5, 10.1, 10.2, 10.3, 10.4_

- [x] 2.3 Implement issueTokens method
  - Generate JWT access token with claims
  - Generate random refresh token
  - Store refresh token in repository
  - Return `Tokens` with both tokens
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 2.4 Implement refresh method
  - Look up refresh token in repository
  - Validate token (not expired, not revoked)
  - Issue new access token
  - Return new `Tokens`
  - _Requirements: 2.4, 2.5, 6.5_

- [x] 2.5 Implement revoke method
  - Mark refresh token as revoked in repository
  - _Requirements: 2.6, 6.6_

- [x] 3. Implement OAuthJwtAuthHandler for delegated authentication
  - Implement JWT validation for external OAuth providers
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 3.1 Implement JWKS fetching and caching
  - Fetch JWKS from provider's jwksUri
  - Cache JWKS with configurable TTL
  - Handle cache expiration and refresh
  - _Requirements: 3.1_

- [x] 3.2 Implement OAuth JWT validation
  - Extract Bearer token from Authorization header
  - Decode JWT and extract kid (key ID)
  - Find matching public key in JWKS
  - Verify signature using public key
  - Verify issuer and audience claims
  - Check expiration
  - Parse claims using generated extension methods
  - Return `AuthResult<TClaims>`
  - _Requirements: 3.2, 3.3, 3.4, 3.5_

- [x] 4. Implement authentication endpoints for self-hosted mode
  - Create auth endpoints for login, refresh, logout, and device flow
  - _Requirements: 2.1, 2.4, 2.6, 4.1, 4.2, 4.4, 4.5, 4.6, 8.1_

- [x] 4.1 Create AuthEndpoints class
  - Create class with constructor accepting `JwtAuthHandler` and user validator callback
  - _Requirements: 2.1_

- [x] 4.2 Implement POST /auth/login endpoint
  - Parse username/password from request body
  - Validate credentials using user validator callback
  - Issue tokens using `JwtAuthHandler.issueTokens()`
  - Return tokens as JSON
  - Handle errors (invalid credentials, validation failures)
  - _Requirements: 2.1_

- [x] 4.3 Implement POST /auth/refresh endpoint
  - Parse refresh_token from request body
  - Call `JwtAuthHandler.refresh()`
  - Return new access token as JSON
  - Handle errors (invalid/expired/revoked token)
  - _Requirements: 2.4, 2.5_

- [x] 4.4 Implement POST /auth/logout endpoint
  - Parse refresh_token from request body
  - Call `JwtAuthHandler.revoke()`
  - Return 204 No Content
  - _Requirements: 2.6_

- [x] 4.5 Implement POST /auth/device endpoint
  - Parse client_id from request body
  - Generate device code (random UUID)
  - Generate user code (8-10 chars, uppercase, hyphen separator)
  - Create DeviceCode aggregate with pending status
  - Store in repository
  - Return device_code, user_code, verification_uri, expires_in, interval
  - _Requirements: 4.1, 4.2_

- [x] 4.6 Implement GET /auth/device/verify endpoint
  - Display HTML form for entering user code
  - On submit: authenticate user and approve device code
  - Update DeviceCode status to approved with userId
  - _Requirements: 4.3_

- [x] 4.7 Implement POST /auth/token endpoint
  - Parse grant_type and parameters from request body
  - If grant_type is device_code: handle device flow polling
  - If grant_type is refresh_token: delegate to refresh endpoint
  - For device flow: look up device code, check status
  - If pending: return authorization_pending error
  - If approved: issue tokens and return
  - If expired: return error
  - _Requirements: 4.4, 4.5, 4.6_

- [x] 5. Integrate authentication with CrudResource
  - Add optional auth handler to CrudResource
  - Invoke auth handler before CRUD operations
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 5.1 Update CrudResource to accept auth handler
  - Add optional `AuthHandler<TClaims>?` parameter to CrudResource constructor
  - Make CrudResource generic over TClaims: `CrudResource<T extends AggregateRoot, TClaims>`
  - _Requirements: 7.1, 7.2_

- [x] 5.2 Add authentication to CRUD operations
  - In handleGetById, handleQuery, handleCreate, handleUpdate, handleDelete:
  - Check if authHandler is present
  - If present: call authenticate() and check result
  - If not authenticated: return 401 with error message
  - If authenticated: store AuthResult in request context
  - Make AuthResult available to custom query handlers and exception handlers
  - _Requirements: 7.3, 7.4, 7.5_

- [x] 6. Implement dddart_rest_client package
  - Create client library for CLI tools and applications
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 9.1, 9.2, 9.3, 9.4_

- [x] 6.1 Create RestClient class
  - Create HTTP client that wraps http.Client
  - Accept AuthProvider in constructor
  - Implement get, post, put, delete, patch methods
  - Automatically include access token from AuthProvider in Authorization header
  - _Requirements: 5.1_

- [x] 6.2 Create AuthProvider interface
  - Define abstract class with getAccessToken(), login(), logout(), isAuthenticated() methods
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 6.3 Implement DeviceFlowAuthProvider
  - Implement getAccessToken() with automatic refresh
  - Implement login() with device flow (request code, display, poll)
  - Implement logout() with token revocation
  - Implement credential storage and loading from file
  - Handle token expiration and refresh automatically
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 9.1, 9.3_

- [x] 6.4 Implement CognitoAuthProvider
  - Implement same interface as DeviceFlowAuthProvider
  - Use Cognito endpoints for device flow and token refresh
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 9.2, 9.4_

- [x] 7. Add error handling and security
  - Implement comprehensive error handling
  - Add security validations
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 7.1 Implement RFC 7807 error responses
  - Create error response builder for authentication failures
  - Map authentication errors to appropriate HTTP status codes and messages
  - Ensure no sensitive information in error messages
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 7.2 Add security validations
  - Implement constant-time signature comparison
  - Validate timestamp age for device codes
  - Add rate limiting considerations to documentation
  - _Requirements: 10.5_

- [x] 8. Write documentation and examples
  - Create comprehensive documentation
  - Provide example applications
  - _Requirements: All_

- [x] 8.1 Write dddart_rest authentication README
  - Document self-hosted vs OAuth authentication modes
  - Document JWT claims code generation with @JwtSerializable()
  - Document RefreshToken and DeviceCode repository setup
  - Provide examples for both in-memory and MongoDB
  - Document auth endpoints
  - Document CrudResource integration
  - Document security considerations
  - _Requirements: All_

- [x] 8.2 Write dddart_rest_client README
  - Document RestClient usage
  - Document AuthProvider implementations
  - Document device flow for CLI tools
  - Provide CLI tool example
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 8.3 Create example applications
  - Create self-hosted auth example with MongoDB
  - Create OAuth/Cognito example
  - Create CLI tool example using dddart_rest_client
  - _Requirements: All_

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
