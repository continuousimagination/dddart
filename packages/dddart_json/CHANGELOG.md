> Historical record; it may describe retired APIs. For current usage, start at
> [the documentation index](../../docs/README.md).

# Changelog

All notable changes to `dddart_json` will be documented in this file.

## [0.9.0] - Unreleased

### Added

- Concrete `DomainEvent<I>` serializers preserve occurrence UUIDs, event time,
  aggregate identity codecs and context through named metadata parameters.
  Erased identity declarations fail generation. Inaccessible private ancestor
  state from another Dart library is not serialized.
- Concrete identity-aware generation, injected/shared `IdentityCodecRegistry`,
  native/scoped identity collections and canonical identity map keys. Resolve
  inherited generic state and reject erased/open identity declarations.
- Breaking migration: UUID consumers use `AggregateRoot<UuidValue>`/`Entity<UuidValue>`;
  regenerate serializers after adopting the typed core API.
- Initial prerelease of JSON serializer generation for dddart aggregate roots,
  entities, and values.

## Unreleased

- Breaking: generate serializers for both concrete identity types in DomainEvent<A, E>; preserve custom event IDs through inherited generic fields and reject erased identity types.
