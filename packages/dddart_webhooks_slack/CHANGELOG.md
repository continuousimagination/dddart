# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2024-11-16

### Added

- Initial release of dddart_webhooks_slack
- SlackWebhookVerifier with HMAC-SHA256 signature verification
- SlackVerificationResult with strongly-typed Slack metadata
- SlackSlashCommand value object for slash command payloads
- Replay attack prevention with timestamp validation
- Constant-time signature comparison for security
- Comprehensive documentation and examples
