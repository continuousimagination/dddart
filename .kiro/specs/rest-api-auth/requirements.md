# Requirements Document

## Introduction

This specification defines authentication and authorization capabilities for dddart_rest, enabling secure access control for REST APIs. The system supports both self-hosted authentication (where the application manages user credentials and tokens) and delegated authentication (where external OAuth2/OIDC providers like AWS Cognito handle authentication). The design prioritizes developer experience by providing a unified authentication model that works seamlessly across web applications, mobile apps, and CLI tools, while remaining database-agnostic through dddart's repository pattern.

## Glossary

- **Access Token**: A short-lived JWT (JSON Web Token) that grants access to protected API resources. Contains user identity and claims. Typically expires in 15-60 minutes.
- **Refresh Token**: A long-lived opaque token used to obtain new access tokens without re-authentication. Stored in database for revocation capability. Typically expires in 7-30 days.
- **JWT (JSON Web Token)**: A cryptographically signed token containing claims about a user. Self-contained and stateless - can be validated without database lookup.
- **Device Flow**: OAuth2 flow designed for devices with limited input capabilities (CLI tools, smart TVs). User enters a code in a browser to authorize the device.
- **JWKS (JSON Web Key Set)**: A set of public keys published by OAuth providers (like Cognito) used to verify JWT signatures.
- **OAuth2/OIDC Provider**: External authentication service (AWS Cognito, Auth0, Okta, Google) that handles user authentication and issues tokens.
- **Self-Hosted Auth**: Authentication mode where the dddart application manages user credentials, issues tokens, and handles refresh token storage.
- **Delegated Auth**: Authentication mode where an external OAuth2/OIDC provider handles authentication, and the application only validates tokens.
- **Auth Handler**: Component responsible for validating authentication credentials and extracting user identity from requests.
- **Auth Provider**: Client-side component that manages authentication flow and token lifecycle for CLI tools and applications.
- **HMAC**: Hash-based Message Authentication Code - cryptographic algorithm used to sign JWTs and verify their integrity.

## Requirements

### Requirement 1

**User Story:** As a REST API developer, I want to protect my API endpoints with authentication, so that only authorized users can access protected resources.

#### Acceptance Criteria

1. WHEN a request is made to a protected endpoint without authentication THEN the system SHALL return HTTP 401 Unauthorized with RFC 7807 error format
2. WHEN a request is made with a valid access token THEN the system SHALL extract user identity and allow the request to proceed
3. WHEN a request is made with an expired access token THEN the system SHALL return HTTP 401 Unauthorized with error message indicating token expiration
4. WHEN a request is made with an invalid signature THEN the system SHALL return HTTP 401 Unauthorized with error message indicating invalid token
5. WHEN authentication succeeds THEN the system SHALL make user identity and claims available to request handlers

### Requirement 2

**User Story:** As a REST API developer, I want to support self-hosted authentication, so that I can manage user credentials and authentication within my application without external dependencies.

#### Acceptance Criteria

1. WHEN a user submits valid credentials to the login endpoint THEN the system SHALL return both an access token and a refresh token
2. WHEN the system issues an access token THEN the token SHALL be a signed JWT containing user identity, expiration time, and custom claims
3. WHEN the system issues a refresh token THEN the token SHALL be stored in the configured repository as a RefreshToken aggregate root
4. WHEN a client submits a valid refresh token to the refresh endpoint THEN the system SHALL issue a new access token
5. WHEN a client submits an expired or revoked refresh token THEN the system SHALL return HTTP 401 Unauthorized
6. WHEN a user logs out THEN the system SHALL revoke the refresh token in the repository

### Requirement 3

**User Story:** As a REST API developer, I want to support OAuth2/OIDC providers like AWS Cognito, so that I can delegate authentication to external services and avoid managing user credentials.

#### Acceptance Criteria

1. WHEN configured with an OAuth2/OIDC provider THEN the system SHALL fetch the provider's public keys from the JWKS endpoint
2. WHEN a request includes a JWT from an OAuth2 provider THEN the system SHALL verify the signature using the provider's public keys
3. WHEN validating an OAuth2 JWT THEN the system SHALL verify the issuer claim matches the configured provider
4. WHEN validating an OAuth2 JWT THEN the system SHALL verify the audience claim matches the configured client ID
5. WHEN an OAuth2 JWT is valid THEN the system SHALL extract user identity from standard claims (sub, email, custom claims)

### Requirement 4

**User Story:** As a CLI tool developer, I want to implement device flow authentication, so that users can authenticate my CLI tool through a browser without entering credentials in the terminal.

#### Acceptance Criteria

1. WHEN a CLI tool requests a device code THEN the system SHALL generate a device code, user code, and verification URI
2. WHEN the system generates a user code THEN the code SHALL be short, human-readable, and easy to type (e.g., "WDJB-MJHT")
3. WHEN a user visits the verification URI and enters the user code THEN the system SHALL prompt for authentication
4. WHEN a CLI tool polls the token endpoint with a device code THEN the system SHALL return "authorization_pending" until the user completes authentication
5. WHEN a user completes authentication for a device code THEN the system SHALL return access and refresh tokens to the polling CLI tool
6. WHEN a device code expires before user authentication THEN the system SHALL return an error indicating expiration

### Requirement 5

**User Story:** As a CLI tool developer, I want a client library that handles authentication automatically, so that I don't have to implement token management, refresh logic, and device flow polling myself.

#### Acceptance Criteria

1. WHEN a CLI tool uses the client library THEN the library SHALL automatically include valid access tokens in API requests
2. WHEN an access token expires THEN the client library SHALL automatically refresh it using the stored refresh token
3. WHEN a CLI tool initiates login THEN the client library SHALL execute device flow, display the user code and verification URI, and poll for tokens
4. WHEN the client library stores credentials THEN the credentials SHALL be saved to a local file in the user's home directory
5. WHEN a CLI tool logs out THEN the client library SHALL revoke the refresh token and delete stored credentials

### Requirement 6

**User Story:** As a REST API developer, I want authentication to work with any repository implementation, so that refresh tokens are stored in my chosen database (MongoDB, DynamoDB, in-memory) without changing authentication code.

#### Acceptance Criteria

1. WHEN the dddart_rest package is used THEN the system SHALL provide RefreshToken and DeviceCode aggregate root classes pre-annotated with @Serializable()
2. WHEN a developer needs to persist auth tokens with a database THEN the developer SHALL extend RefreshToken and DeviceCode and annotate the subclasses with their chosen repository annotation (e.g., @GenerateMongoRepository())
3. WHEN a developer runs code generation THEN the system SHALL generate repository implementations for the developer's RefreshToken and DeviceCode subclasses
4. WHEN a developer needs an in-memory repository THEN the developer SHALL use InMemoryRepository<RefreshToken> and InMemoryRepository<DeviceCode> directly without extending or code generation
5. WHEN configuring self-hosted authentication THEN the system SHALL accept Repository<T> where T extends RefreshToken and Repository<D> where D extends DeviceCode
6. WHEN the system needs to validate a refresh token THEN the system SHALL query the repository for the token
7. WHEN the system needs to revoke a refresh token THEN the system SHALL update the token's revoked flag in the repository
8. WHEN the system needs to create a refresh token THEN the system SHALL save a new RefreshToken (or subclass) aggregate to the repository

### Requirement 7

**User Story:** As a REST API developer, I want to configure authentication per resource, so that I can have public endpoints, authenticated endpoints, and endpoints with different authentication requirements.

#### Acceptance Criteria

1. WHEN registering a CrudResource without an auth handler THEN the resource SHALL be publicly accessible without authentication
2. WHEN registering a CrudResource with an auth handler THEN all operations SHALL require valid authentication
3. WHEN a resource has an auth handler THEN the handler SHALL be invoked before any CRUD operation
4. WHEN authentication fails for a resource THEN the system SHALL return HTTP 401 before invoking repository operations
5. WHEN authentication succeeds THEN the user identity SHALL be available to custom query handlers and exception handlers

### Requirement 8

**User Story:** As a REST API developer, I want clear separation between self-hosted and OAuth authentication modes, so that I can easily switch between managing authentication myself and delegating to external providers.

#### Acceptance Criteria

1. WHEN using self-hosted authentication THEN the system SHALL provide login, refresh, logout, and device flow endpoints
2. WHEN using OAuth authentication THEN the system SHALL NOT provide authentication endpoints (provider handles them)
3. WHEN using self-hosted authentication THEN the system SHALL require a refresh token repository
4. WHEN using OAuth authentication THEN the system SHALL NOT require a refresh token repository
5. WHEN using either authentication mode THEN the auth handler interface SHALL be consistent for resource configuration

### Requirement 9

**User Story:** As a CLI tool developer, I want the client library to support both self-hosted and OAuth providers, so that my CLI tool works regardless of which authentication mode the API uses.

#### Acceptance Criteria

1. WHEN configuring the client library for self-hosted auth THEN the library SHALL perform device flow against the API's auth endpoints
2. WHEN configuring the client library for OAuth auth THEN the library SHALL perform device flow against the OAuth provider's endpoints
3. WHEN the client library refreshes tokens in self-hosted mode THEN the library SHALL call the API's refresh endpoint
4. WHEN the client library refreshes tokens in OAuth mode THEN the library SHALL call the OAuth provider's token endpoint
5. WHEN switching between auth modes THEN the client library SHALL use the same AuthProvider interface

### Requirement 10

**User Story:** As a REST API developer, I want comprehensive error handling for authentication failures, so that clients receive clear, actionable error messages following RFC 7807 format.

#### Acceptance Criteria

1. WHEN authentication fails due to missing token THEN the system SHALL return HTTP 401 with error detail "Missing authorization header"
2. WHEN authentication fails due to invalid token format THEN the system SHALL return HTTP 401 with error detail "Invalid token format"
3. WHEN authentication fails due to expired token THEN the system SHALL return HTTP 401 with error detail "Token has expired"
4. WHEN authentication fails due to invalid signature THEN the system SHALL return HTTP 401 with error detail "Invalid token signature"
5. WHEN authentication fails THEN the system SHALL NOT expose sensitive information like signing secrets or expected signatures in error messages

### Requirement 11

**User Story:** As a REST API developer, I want to configure JWT token parameters, so that I can control token expiration, issuer, audience, and signing algorithm based on my security requirements.

#### Acceptance Criteria

1. WHEN configuring self-hosted JWT authentication THEN the system SHALL accept a signing secret parameter
2. WHEN configuring self-hosted JWT authentication THEN the system SHALL accept optional issuer and audience parameters
3. WHEN configuring access token expiration THEN the system SHALL accept a duration parameter with a default of 15 minutes
4. WHEN configuring refresh token expiration THEN the system SHALL accept a duration parameter with a default of 7 days
5. WHEN issuing a JWT THEN the system SHALL use HMAC-SHA256 as the signing algorithm

### Requirement 12

**User Story:** As a REST API developer, I want to include custom claims in JWTs, so that I can embed user roles, permissions, or other application-specific data in access tokens.

#### Acceptance Criteria

1. WHEN issuing an access token THEN the system SHALL accept a map of custom claims
2. WHEN a custom claim is provided THEN the claim SHALL be included in the JWT payload
3. WHEN validating an access token THEN the system SHALL extract custom claims and make them available to the application
4. WHEN custom claims are extracted THEN the claims SHALL be accessible through the AuthResult object
5. WHEN no custom claims are provided THEN the system SHALL issue a valid JWT with only standard claims (sub, exp, iat, iss, aud)
