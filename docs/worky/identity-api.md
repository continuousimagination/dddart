# Extensible identity: accepted API and migration

Status: owner-approved API implemented across #39–#44; final integration evidence
and independent-review status live in identity-integration-work-record.md.
Tracking: [#37](https://github.com/continuousimagination/dddart/issues/37).
Original baseline: c538680619a11af79e7094c3087646189c313978.

## Owner decisions

On 28 October 2026 the owner approved breaking pre-release APIs and directed the
framework to carry each application's concrete identity type. Worky has no code
to migrate. A GitHub Issue retains its GitHub-assigned ID; a synthetic UUID
translation table is not introduced. Repository-scoped issue numbers are a
separate composite-identity fixture. Consumer-specific GitHub policy stays in the
consumer. Existing UUID applications will migrate explicitly.

## Domain contracts

```dart
abstract class Identity extends Value {}
class UuidValue extends Identity { /* existing UUID API */ }
abstract class Entity<I extends Identity> { /* required I id */ }
abstract class AggregateRoot<I extends Identity> extends Entity<I> {}
abstract class UuidEntity extends Entity<UuidValue> { /* optional UUID */ }
abstract class UuidAggregateRoot extends AggregateRoot<UuidValue> { /* optional UUID */ }
abstract interface class Repository<T extends AggregateRoot<I>, I extends Identity> {
  Future<T> getById(I id);
  Future<void> save(T aggregate);
  Future<void> deleteById(I id);
}
class InMemoryRepository<T extends AggregateRoot<I>, I extends Identity>
    implements Repository<T, I> {}
abstract class DomainEvent<I extends Identity> {
  // I aggregateId; UuidValue eventId; occurrence time/context.
}
```

Repository<Issue, IssueId> links the aggregate and identity types, rejecting wrong
lookup/deletion IDs statically. Repositories manage aggregate roots, not nested
entities. Enumeration remains a separate explicit capability. The in-memory
implementation is an instance-local consumer fake, not evidence for database or
custom-interface semantics.

Identity retains Value's structural equality/hash and runtime-kind separation.
Immutable consumer identity properties include every scope component. UuidValue
remains the supplied UUID implementation, with generation, validation and original
text/case preserved. General entities require their concrete ID; UUID convenience
bases generate only UUIDs. Existing timestamp, touch, upsert and event policies
remain in scope only for regression preservation.

AggregateRoot<I> carries DomainEvent<I>. EventBus intentionally dispatches
heterogeneous DomainEvent<Identity> values; occurrence UUIDs remain distinct from
aggregate identities.

## Serialization and canonical keys

IdentityCodec<I> lives in dddart_serialization and explicitly defines toJson,
fromJson, toKey and fromKey. JSON may be scalar or structured; canonical keys are
reversible and collision-free over the supported identity domain, including scope.
Arbitrary toString or UUID hashing is not a serialization contract.

IdentityCodecRegistry is instance-local, pre-registers UuidIdentityCodec as
"uuid", and accepts register<I>(stableKey, codec). Duplicate type/key registration,
unknown codecs, wrong concrete kinds, malformed values and noncanonical keys fail.
Mixed-stream JSON tags are {"type": stableKey, "value": structuralValue}.

Generated JSON serializers accept .withIdentityCodecs(registry), share it with
nested serializers and preserve the stateless default UUID constructor. Concrete
inherited generic identity fields, nullable fields, collections and identity map
keys are supported. Erased/open identity declarations fail generation. Regenerate
owning combined parts; never hand-edit output. DomainEvent<I> serializers require
named aggregateId, eventId, occurredAt and context reconstruction parameters.

## Adapter constraints and migrations

| Boundary | Implemented key representation and explicit constraint |
| --- | --- |
| MongoDB | Exact canonical UTF-8 bytes in binary _id; structural JSON id retained. Old string _id records, including UUIDs, need migration/recreation. BSON/server document constraints remain enforced. |
| DynamoDB | Canonical string partition key, 1–2048 UTF-8 bytes; body reconstruction restores the structural identity. |
| SQLite | Exact canonical UTF-8 bytes in BLOB identity columns. Old 16-byte UUID schemas/data need migration/recreation. |
| MySQL | VARBINARY(1024) identity columns; reject oversized/malformed keys before I/O and reject old BINARY(16) schemas before writes, including non-strict mode. Full schema/index/row limits remain server-enforced. |
| REST | One canonical key segment, encoded once by the client and decoded once by HttpServer. Empty, malformed UTF-8 and dot-only keys are rejected. |

SQL primary keys, entity references, collection parents and identity map keys
retain their concrete types. UUID text bytes preserve UuidValue's case-sensitive
equality. SQLite and MySQL retain their distinct existing collection layouts;
MySQL Set/Map entity collections remain unsupported and fail generation clearly.
Existing nullable collection containers still reconstruct as empty collections.

Generated adapters accept optional named identityCodecs and share it with JSON.
Handwritten custom repository methods retain their explicit interfaces and use
the selected backend's supported decoding seam. No implicit scans are added.

## REST and distributed events

CrudResource<T, I, TClaims>, AuthorizationHandler<T, I, TClaims> and
QueryHandler<T, I> retain concrete IDs. Direct resource handlers accept decoded
canonical keys. Malformed/noncanonical server keys produce problem+json 400;
valid absent IDs retain 404. Generated clients map 400/422 to constraint errors
and reject mismatched response IDs. Authentication, pagination and the existing
non-atomic ETag policy are preserved. Stock auth records keep UUID identity.

StoredEvent<I> is a UUID-identified record with a separately typed aggregateId.
Mixed stores intentionally use StoredEvent<Identity>. Transport envelopes use
registered identity tags; old bare UUID aggregate references need migration.
EventRegistry registers stable event keys with typed callbacks or JsonSerializer<E>.
Generated registrations share the event JSON serializer's owning combined part.
@DistributedEvent freezes a key independently of Dart names; without it the
source class name is the declared wire key and renaming requires migration.
No dynamic runtime-name/toJson fallback remains.

Known payloads are validated against their envelopes before the inclusive polling
cursor advances. Decode failures stop the batch and leave the failed record
retryable; valid unknown event types keep the explicit skip policy. HTTP custom
record ingestion uses an injected typed factory. Retention/auth/filtering and
unrelated legacy/AWS transport work remain outside redesign.

## Delivery and validation

Configuration #38 and all six identity children have their own merged PRs and
work records. The identity parent PR #45 targets feat/worky-changes. Validated
merges are authorized upward only as far as that feature branch. Independent
feature review, merge to main and publication are separate owner actions.

Use root pubspec.yaml membership and tool/validation/inventory.json. Required
combined-part generation precedes formatting, focused behavior, affected package
and downstream/example checks. The parent gate runs scripts/test-all.sh plus
provisioned MongoDB, DynamoDB Local and MySQL lanes. A 13-package external consumer
at immutable revision 8131339 proves configuration, all adapters, REST and mixed
events; the integration record identifies the exact SHA and source equivalence.
Real AWS/OIDC and excluded legacy examples are not represented as passed.

Migration guidance and package changelogs cover UuidAggregateRoot/UuidEntity,
Repository<T, UuidValue>, typed events, native IDs, codec injection and explicit
storage/wire breaks. Current Git consumption uses documented dependency overrides;
publication remains #30. Worky has no consumer lockfile to update. Browser
persistence #29, timestamp redesign and unrelated event work remain separate.
