# Implementation Plan: Fix AWS Cognito OAuth Support

## Overview

This implementation refactors the `CognitoAuthProvider` in `dddart_rest_client` to use a pluggable callback strategy pattern, enabling different platforms (CLI, web, mobile) to handle OAuth callbacks appropriately. The core OAuth flow with PKCE remains the same, but the callback mechanism becomes extensible.

## Tasks

- [x] 1. Create OAuthCallbackStrategy interface and data models
  - Create `lib/src/oauth_callback_strategy.dart` with the `OAuthCallbackStrategy` interface
  - Define `CallbackResult` class for returning authorization codes and errors
  - Export the new interface from `lib/dddart_rest_client.dart`
  - _Requirements: 2.1, 2.3, 2.4, 2.5_

- [x] 1.1 Write property tests for CallbackResult
  - **Property 3: Callback Strategy Contract**
  - **Validates: Requirements 2.4, 2.5**

- [x] 2. Implement LocalhostCallbackStrategy
  - Create `lib/src/localhost_callback_strategy.dart`
  - Implement HTTP server lifecycle (start, wait for callback, shutdown)
  - Implement browser opening with platform-specific commands
  - Generate success/error HTML responses
  - Handle non-callback paths with 404
  - Export from `lib/dddart_rest_client.dart`
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 8.1, 8.2, 8.3, 8.5, 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 2.1 Write property tests for LocalhostCallbackStrategy
  - **Property 6: HTTP Query Parameter Extraction**
  - **Property 16: Redirect URI Construction**
  - **Property 18: HTTP 404 for Non-Callback Paths**
  - **Property 25: HTML Response Generation**
  - **Validates: Requirements 3.4, 8.3, 10.5, 3.5**

- [x] 2.2 Write unit tests for LocalhostCallbackStrategy
  - Test server starts on correct port and binds to localhost only
  - Test browser opening fallback when command fails
  - Test HTML response content for success and error cases
  - Test server shutdown after callback
  - _Requirements: 3.1, 3.2, 3.3, 3.6, 8.5, 10.1, 10.2, 10.3, 10.4_

- [x] 3. Implement ManualCallbackStrategy
  - Create `lib/src/manual_callback_strategy.dart`
  - Implement user prompts and instructions
  - Parse full callback URLs or just authorization codes
  - Handle stdin input
  - Export from `lib/dddart_rest_client.dart`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 8.4_

- [x] 3.1 Write property tests for ManualCallbackStrategy
  - **Property 7: Manual Input Parsing**
  - **Validates: Requirements 4.4**

- [x] 3.2 Write unit tests for ManualCallbackStrategy
  - Test URL printing and instructions
  - Test parsing of full callback URLs
  - Test parsing of just authorization codes
  - Mock stdin for testing
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 4. Extract PKCE generation into separate class
  - Create `lib/src/pkce_generator.dart` with static methods
  - Move `_generateCodeVerifier()`, `_generateCodeChallenge()`, `_generateState()` from CognitoAuthProvider
  - Make class private (`_PKCEGenerator`)
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 4.1 Write property tests for PKCE generation
  - **Property 1: PKCE Code Verifier Format**
  - **Property 2: PKCE Code Challenge Computation**
  - **Validates: Requirements 1.2, 1.3**

- [x] 5. Refactor CognitoAuthProvider to use callback strategies
  - Update constructor to accept optional `callbackStrategy` parameter
  - Default to `LocalhostCallbackStrategy()` when not provided
  - Update constructor to accept optional `scopes` parameter with default `['openid', 'email', 'profile']`
  - Refactor `login()` method to use the callback strategy
  - Use `_PKCEGenerator` for PKCE operations
  - Update `_buildAuthorizationUrl()` to use configurable scopes
  - Remove old HTTP server code from `login()` method
  - Remove `_openBrowser()` method (now in LocalhostCallbackStrategy)
  - Remove `_getCallbackHtml()` method (now in LocalhostCallbackStrategy)
  - _Requirements: 2.1, 2.2, 2.3, 11.3, 12.2, 12.3, 12.4_

- [x] 5.1 Write property tests for CognitoAuthProvider
  - **Property 4: Authorization URL Construction**
  - **Property 5: State Parameter Validation**
  - **Property 17: Custom Scope Usage**
  - **Validates: Requirements 1.4, 1.5, 3.7, 4.5, 12.3, 12.4**

- [x] 5.2 Write unit tests for CognitoAuthProvider refactoring
  - Test default callback strategy is LocalhostCallbackStrategy
  - Test custom callback strategy is used when provided
  - Test default scopes are used when not provided
  - Test custom scopes are used when provided
  - Test state validation throws correct exception
  - _Requirements: 2.1, 2.2, 2.3, 12.1, 12.2, 12.5_

- [x] 6. Checkpoint - Ensure all tests pass
  - Run `dart test` in `packages/dddart_rest_client`
  - Fix any issues that arise
  - Ensure all existing tests still pass

- [x] 7. Update token management for ID token preservation
  - Update `_refresh()` method to preserve existing ID token when Cognito doesn't return a new one
  - Ensure new ID token is used when Cognito returns one
  - Update error handling to include response body in exceptions
  - _Requirements: 7.4, 7.5, 9.4_

- [x] 7.1 Write property tests for token refresh
  - **Property 12: ID Token Preservation on Refresh**
  - **Validates: Requirements 7.4, 7.5**

- [x] 7.2 Write unit tests for token refresh
  - Test refresh with new ID token
  - Test refresh without new ID token (preserves existing)
  - Test refresh failure includes response body
  - _Requirements: 7.4, 7.5, 9.4_

- [x] 8. Enhance error handling and messages
  - Update all error messages to be descriptive and actionable
  - Ensure state mismatch error says "State mismatch - possible CSRF attack"
  - Ensure missing code error says "No authorization code received"
  - Ensure invalid ID token error says "Invalid ID token format"
  - Ensure token exchange failures include Cognito response body
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 8.1 Write property tests for error handling
  - **Property 11: Error Message Consistency**
  - **Property 22: OAuth Error Propagation**
  - **Property 23: Token Exchange Error Handling**
  - **Property 24: Token Refresh Error Handling**
  - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 5.4, 7.6**

- [x] 9. Update existing tests for new architecture
  - Update `test/cognito_auth_provider_test.dart` to work with callback strategies
  - Mock callback strategies for testing
  - Ensure all existing test scenarios still pass
  - Add tests for new error messages
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

- [x] 9.1 Write property tests for token storage and JWT decoding
  - **Property 8: Token Storage Round Trip**
  - **Property 13: JWT Structure Validation**
  - **Property 14: JWT Claims Extraction**
  - **Property 15: Missing Sub Claim Error**
  - **Validates: Requirements 5.5, 6.1, 6.2, 6.3, 6.4, 6.5**

- [x] 9.2 Write property tests for token exchange and AuthProvider interface
  - **Property 9: Token Exchange Request Format**
  - **Property 10: Token Refresh Request Format**
  - **Property 19: Automatic Token Refresh**
  - **Property 20: Logout Cleanup**
  - **Property 21: Authentication State Check**
  - **Validates: Requirements 5.2, 7.2, 11.2, 11.4, 11.5**

- [x] 10. Add crypto package dependency
  - Update `packages/dddart_rest_client/pubspec.yaml` to include `crypto: ^3.0.0`
  - Run `dart pub get` from workspace root
  - _Requirements: 1.3_

- [x] 11. Update documentation
  - Update `packages/dddart_rest_client/README.md` with callback strategy examples
  - Document LocalhostCallbackStrategy (default for CLI/desktop)
  - Document ManualCallbackStrategy (for web/cross-platform)
  - Document CustomSchemeCallbackStrategy pattern (for mobile, not implemented)
  - Add migration guide for existing users
  - Update API documentation in code comments
  - _Requirements: All_

- [x] 12. Create example code
  - Update `example/cli_tool_example.dart` to show default LocalhostCallbackStrategy usage
  - Create `example/web_app_example.dart` showing ManualCallbackStrategy usage
  - Create `example/README.md` explaining when to use each strategy
  - Add documentation comment in examples about mobile CustomSchemeCallbackStrategy
  - _Requirements: All_

- [x] 13. Final checkpoint - Run all tests and quality checks
  - Run `./scripts/test-all.sh` from workspace root
  - Ensure all tests pass
  - Ensure no linting errors
  - Ensure code is properly formatted
  - Fix any issues that arise

## Notes

- The core OAuth flow with PKCE is already implemented correctly in the current code
- This refactoring focuses on making the callback mechanism pluggable and extensible
- Backward compatibility is maintained - existing code will continue to work
- The `crypto` package is already used in the current implementation but may not be in pubspec.yaml
- Property tests should run minimum 100 iterations each
- All property tests must be tagged with feature name and property number
