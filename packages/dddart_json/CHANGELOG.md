# Changelog

All notable changes to `dddart_json` will be documented in this file.

## [0.9.0] - Unreleased

### Added

- Concrete identity-aware generation, injected/shared `IdentityCodecRegistry`,
  native/scoped identity collections and canonical identity map keys. Resolve
  inherited generic state and reject erased/open identity declarations.
- Breaking migration: UUID consumers use `UuidAggregateRoot`/`UuidEntity`;
  regenerate serializers after adopting the typed core API.
- Initial prerelease of JSON serializer generation for dddart aggregate roots,
  entities, and values.
