# Implementation Plan

- [x] 1. Set up dddart_webhooks package structure
  - Create packages/dddart_webhooks directory with standard Dart package layout
  - Create pubspec.yaml with dependencies (dddart_http, shelf, dart:convert)
  - Create lib/dddart_webhooks.dart main export file
  - Create lib/src/ directory for implementation files
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Implement WebhookVerificationResult base class
  - Create lib/src/webhook_verification_result.dart
  - Implement WebhookVerificationResult abstract class with isValid and errorMessage properties
  - Add documentation explaining the purpose and usage
  - Export from main library file
  - _Requirements: 4.1, 4.2_

- [x] 3. Implement WebhookVerifier base class
  - Create lib/src/webhook_verifier.dart
  - Implement WebhookVerifier<T extends WebhookVerificationResult> abstract class
  - Define verify(Request request, String body) method signature
  - Add documentation with examples for custom implementations
  - Export from main library file
  - _Requirements: 2.1, 9.1, 9.2, 9.3_

- [x] 4. Implement WebhookDeserializers helper class
  - Create lib/src/webhook_deserializers.dart
  - Implement static json<T>() method for JSON deserialization
  - Implement static form<T>() method for form-encoded deserialization
  - Add documentation with usage examples
  - Export from main library file
  - _Requirements: 6.15, 6.16_

- [x] 5. Implement WebhookResource class
  - Create lib/src/webhook_resource.dart
  - Implement WebhookResource<TPayload, TVerification> class with generic type parameters
  - Add constructor with path, verifier, deserializer, handler, and onDeserializationError parameters
  - Implement handleRequest(Request request) method
  - Export from main library file
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 5.1, 5.2_

- [x] 6. Implement signature verification in WebhookResource
  - In handleRequest, read request body as String
  - Invoke verifier.verify(request, body)
  - If verification fails, return 401 Unauthorized with error details
  - If verification succeeds, proceed to deserialization
  - _Requirements: 2.2, 2.3, 2.4, 7.1_

- [x] 7. Implement payload deserialization in WebhookResource
  - If deserializer is provided, invoke it with raw body String
  - If deserializer is null and TPayload is String, pass raw body to handler
  - Handle deserialization exceptions
  - If onDeserializationError is provided, invoke it with body and exception
  - If no error handler, return 400 Bad Request
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10, 6.11, 6.12, 7.3_

- [x] 8. Implement handler invocation in WebhookResource
  - Pass deserialized payload and verification result to handler
  - Catch handler exceptions and return 500 Internal Server Error
  - Return handler's Response to webhook provider
  - _Requirements: 5.3, 5.4, 5.5, 7.4_

- [x] 9. Add HttpServer integration for webhooks
  - Update dddart_http HttpServer class to support webhook registration
  - Add registerWebhook<TPayload, TVerification>() method
  - Register POST route for webhook path
  - Route requests to webhook.handleRequest()
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 10. Create dddart_webhooks examples
  - Create example/custom_verifier_example.dart demonstrating custom verifier implementation
  - Create example/raw_json_example.dart demonstrating raw JSON handling
  - Create example/form_encoded_example.dart demonstrating form-encoded handling
  - Add README.md explaining how to run examples
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.9, 10.10_

- [x] 11. Write unit tests for dddart_webhooks
  - Create test/webhook_verification_result_test.dart
  - Create test/webhook_resource_test.dart testing request handling and error responses
  - Create test/webhook_deserializers_test.dart testing JSON and form helpers
  - Test signature verification failure scenarios
  - Test deserialization failure scenarios
  - Test handler exception scenarios
  - _Requirements: 11.1, 11.2, 11.10, 11.11, 11.12, 11.15_

- [x] 12. Set up dddart_webhooks_slack package structure
  - Create packages/dddart_webhooks_slack directory with standard Dart package layout
  - Create pubspec.yaml with dependencies (dddart_webhooks, crypto)
  - Create lib/dddart_webhooks_slack.dart main export file
  - Create lib/src/ directory for implementation files
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 13. Implement SlackVerificationResult class
  - Create lib/src/slack_verification_result.dart
  - Extend WebhookVerificationResult
  - Add teamId, timestamp, and requestType properties
  - Add documentation
  - Export from main library file
  - _Requirements: 3.5, 3.6, 4.3, 4.4, 4.5_

- [x] 14. Implement SlackWebhookVerifier class
  - Create lib/src/slack_webhook_verifier.dart
  - Extend WebhookVerifier<SlackVerificationResult>
  - Add constructor accepting signingSecret and optional maxTimestampAge
  - Implement verify() method signature validation
  - Export from main library file
  - _Requirements: 3.1, 3.7, 9.4, 9.5_

- [x] 15. Implement Slack signature verification algorithm
  - Extract X-Slack-Signature and X-Slack-Request-Timestamp headers
  - Validate headers are present
  - Parse and validate timestamp format
  - Check timestamp age against maxTimestampAge (replay attack prevention)
  - Compute HMAC-SHA256 signature using signing secret
  - Perform constant-time signature comparison
  - _Requirements: 3.2, 3.3, 3.4, 11.5, 11.6, 11.7, 11.8_

- [x] 16. Extract Slack metadata in verification result
  - Parse request body to extract team_id and type fields
  - Handle JSON parsing errors gracefully (verification can succeed even if metadata extraction fails)
  - Return SlackVerificationResult with extracted metadata
  - _Requirements: 3.6_

- [x] 17. Implement SlackSlashCommand data model
  - Create lib/src/slack_slash_command.dart
  - Extend Value from dddart
  - Add properties: command, text, userId, userName, teamId, channelId, responseUrl, triggerId
  - Implement fromForm(Map<String, String>) factory constructor
  - Implement props getter
  - Export from main library file
  - _Requirements: 6.2, 6.3_

- [x] 18. Create dddart_webhooks_slack examples
  - Create example/slash_command_example.dart demonstrating Slack slash command handling
  - Create example/interactive_message_example.dart demonstrating interactive message handling
  - Add example/README.md explaining Slack webhook setup and how to run examples
  - _Requirements: 10.5, 10.6, 10.7, 10.8, 10.9, 10.10, 10.11_

- [x] 19. Write unit tests for dddart_webhooks_slack
  - Create test/slack_verification_result_test.dart
  - Create test/slack_webhook_verifier_test.dart
  - Test valid signature verification with real Slack test data
  - Test invalid signature rejection
  - Test expired timestamp rejection (replay attack)
  - Test missing headers handling
  - Test metadata extraction
  - Create test/slack_slash_command_test.dart testing form deserialization
  - _Requirements: 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.15_

- [x] 20. Write integration tests
  - Create test/webhook_integration_test.dart in dddart_webhooks
  - Test end-to-end webhook processing with HttpServer
  - Test multiple webhook resources with different paths
  - Test middleware application to webhook requests
  - Create test/slack_webhook_integration_test.dart in dddart_webhooks_slack
  - Test Slack webhook with real-world payload examples
  - _Requirements: 11.13, 11.14, 11.15_

- [x] 21. Add comprehensive documentation
  - Update dddart_webhooks README.md with overview, features, and quick start
  - Update dddart_webhooks_slack README.md with Slack-specific setup instructions
  - Ensure all public APIs have doc comments
  - Add code examples to doc comments
  - Document security considerations (HTTPS, secret management)
  - _Requirements: 10.9, 10.10, 10.11_

- [x] 22. Final validation and cleanup
  - Run dart analyze on both packages (zero issues)
  - Run dart format on both packages
  - Run all tests and ensure 100% pass rate
  - Verify examples run successfully
  - Review documentation for completeness
  - _Requirements: All_
