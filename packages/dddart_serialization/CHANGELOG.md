# Changelog

All notable changes to `dddart_serialization` will be documented in this file.

## [0.9.0] - Unreleased

### Added

- `IdentityCodec<I>`, stock `UuidIdentityCodec`, and instance-local
  `IdentityCodecRegistry`, with explicit stable tagged kinds and canonical,
  lossless key validation for native and scoped identities.
- Initial prerelease of the shared serialization contracts, annotations,
  configuration, and utilities used by dddart serializers.
