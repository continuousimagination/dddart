# Changelog

## [Unreleased]

### Added
- ID token storage in CognitoAuthProvider
- `getIdToken()` method to retrieve ID token
- `getCognitoSub()` method to extract Cognito user ID from ID token
- `getIdTokenClaims()` method to extract all claims from ID token

### Changed
- Token refresh now preserves ID token when Cognito doesn't return a new one
- `_CognitoTokens` class now includes `idToken` field
- `_StoredCredentials` class now includes `idToken` field

## 0.1.0

- Initial release
- RestClient with automatic authentication
- DeviceFlowAuthProvider for self-hosted authentication
- CognitoAuthProvider for AWS Cognito
- Automatic token refresh
- Credential storage and management
