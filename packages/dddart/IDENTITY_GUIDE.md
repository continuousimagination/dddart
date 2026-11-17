# Typed identity

`Identity` extends `Value`: equality includes runtime kind and structural `props`.
Keep every identity field immutable. Include every scope component; equal issue
numbers in different repositories must not collapse to the same identity.
`UuidValue` supplies UUID creation/validation, not an implicit fallback for an
externally identified entity.

`Entity<I>`, `AggregateRoot<I>`, `Repository<T, I>` and `DomainEvent<I>` retain the
concrete identity. Both entity and aggregate constructors require `id:`.
A domain constructor may explicitly choose `UuidValue.generate()`.
Event occurrence IDs remain UUIDs independently of their aggregate's identity.

The [complete native-identity program](../../docs/quickstarts/core/bin/identity.dart)
is published in the [modeling guide](https://continuousimagination.github.io/dddart/docs/modeling/)
and runs through the core documentation workflow. The
[JSON identity workflow](../../docs/quickstarts/json/README.md) adds an explicit
codec and generated serialization, with all imports, parts and commands.

## Boundary contracts

Identity determines domain equality, not a universal storage representation.
Application codecs define structural JSON and canonical, reversible keys.
Do not encode `toString()`, concatenate scope components ambiguously or hash an
external identity into a UUID. Registry type keys are explicit wire contracts.

Pass the same codec registry through serializers, repositories and event
registries. Each adapter owns its key-size, comparison and URI-escaping rules.
See [serialization](../../docs/SERIALIZATION.md),
[capabilities](../../docs/CAPABILITIES.md) and the relevant
[adapter workflow](../../docs/QUICKSTARTS.md). Annotated open/erased identities
fail generation; there are no UUID-specific entity/aggregate base classes.

1.0 is the first compatibility baseline. Regenerate repository-owned models and
use fresh pre-release fixtures; no pre-1.0 schema or generated-code upgrade is
promised.
