# Extensible identity: API and implementation proposal

Status: proposal for owner review before library implementation.
Tracking: [#37](https://github.com/continuousimagination/dddart/issues/37).
Source baseline: `c538680619a11af79e7094c3087646189c313978`.

## Owner decisions

On 28 October 2026, the owner approved breaking pre-release APIs and directed
the framework to carry an application's concrete identity type through entities
and repositories. Dddart must supply a UUID identity based on the current UUID
functionality. Existing applications will migrate; a compatibility facade is
not required.

Worky has no implemented consumer to migrate. Its motivating case is an Issue
whose identity is assigned by GitHub. A synthetic UUID translation table is not
acceptable. A repository-scoped issue number is a separate composite-identity
example; GitHub-specific identity policy belongs in the consumer.

## Proposed domain API

The proposed declarations are:

```dart
abstract class Identity extends Value { /* immutable equality properties */ }
class UuidValue extends Identity { /* existing UUID API */ }

abstract class Entity<I extends Identity> { /* required I id */ }
abstract class AggregateRoot<I extends Identity> extends Entity<I> { /* events */ }

abstract interface class Repository<T extends AggregateRoot<I>, I extends Identity> {
  Future<T> getById(I id);
  Future<void> save(T aggregate);
  Future<void> deleteById(I id);
}

class InMemoryRepository<T extends AggregateRoot<I>, I extends Identity>
    implements Repository<T, I> { /* instance-local fake */ }

abstract class DomainEvent<I extends Identity> {
  // I aggregateId; UuidValue eventId; existing time/context metadata.
}
```

Dart needs the repository's aggregate and identity types linked explicitly:
`Repository<Issue, IssueId>` constrains Issue to
`AggregateRoot<IssueId>` and makes lookup/deletion accept IssueId.
Repositories still manage aggregate roots. Nested entities do not acquire
independent repositories as part of this change.

Identity inherits Value's equality/hash contract, including runtime identity
kind and structural properties. Consumer identity definitions must be immutable
and include every scope component in their properties. Domain APIs must not
erase the concrete identity type to Identity or Object.

UuidValue remains the supplied UUID implementation; do not add a second UUID
wrapper. Keep fromString, generate and existing validation available. The
general Entity/AggregateRoot constructor requires an identity.
Proposed UuidEntity and UuidAggregateRoot specializations supply optional UUID
generation without an unchecked cast from UuidValue to a custom identity.

AggregateRoot's event methods carry DomainEvent<I>. Event occurrence IDs remain
UUIDs. EventBus can still dispatch heterogeneous event types. Timestamps,
touch(), CRUD/upsert semantics and event delivery policies are unchanged in
scope; their existing behavior must continue under the migrated signatures.

## Serialization and key boundaries

Core identity has no persistence or HTTP responsibility. Propose an explicit
`IdentityCodec<I>` in the serialization boundary with operations equivalent to:

```dart
Object toJson(I identity);
I fromJson(Object? value);
String toKey(I identity);
I fromKey(String value);
```

The JSON representation is a supported scalar or structured JSON value. The
key representation is canonical and reversible for the supported identity
domain. Codec implementations own validation and collision avoidance. Neither
arbitrary toString() nor hashing into a UUID is a storage contract.

Supply a UUID codec. Generated serializers/repositories receive the relevant
typed codecs through constructor injection or explicit generator configuration.
The JSON/code-generation issue must finalize the exact public declaration and
registration/constructor surface against a clean generated consumer before
implementation proceeds beyond that boundary.

For scoped/composite IDs, a structural JSON object and an unambiguous canonical
tuple key are valid examples; punctuation concatenation without escaping is
not sufficient. Repository-local number 12 in two repositories must produce
different identities and keys.

SQL backends must propagate custom key types through primary keys, nested
entity relationships and collection foreign keys. Native UUID storage can
remain BLOB/BINARY while custom keys use a suitable declared SQL type. Document
key length/type constraints, schema migration implications and explicit
unsupported cases. Custom identities are in scope for all existing adapters;
a UUID-only implementation is not completion of this issue.

REST applies URI encoding to the explicit key representation and decodes it
before the typed repository boundary. Client and server must agree on the
codec, malformed-key errors and resource routing. A string containing slash,
percent, comma or Unicode must not be accidentally split or reinterpreted.

Distributed events distinguish their own UUID record identity from the
aggregate reference. Mixed streams need an explicit stable codec registration
or discriminator to reconstruct the aggregate's identity kind. Dynamic
runtimeType/toString fallbacks are not sufficient identity reconstruction.

## Work breakdown and dependency order

| Issue | Responsibility | Prerequisites | Branch |
| --- | --- | --- | --- |
| #39 | Domain types, UUID convenience, in-memory repository and typed events | API review | issue/identity-core |
| #40 | Serialization contracts, codecs, JSON generator and clean fixtures | #39 | issue/identity-serialization |
| #41 | MongoDB and DynamoDB generators/adapters | #39, #40 | issue/identity-document-backends |
| #42 | SQL, SQLite and MySQL dialect/schema/generator paths | #39, #40 | issue/identity-sql-backends |
| #43 | REST server, generated repositories and affected auth/client paths | #39, #40 | issue/identity-rest |
| #44 | Stored events, registry, transport and aggregate-reference reconstruction | #39, #40, #43 | issue/identity-distributed-events |

Each child PR targets `issue/37-extensible-identity`. This parent PR targets
`feat/worky-changes`. Git branches do not themselves encode a parent:
PR bases and the issue dependency graph define integration. Update child
branches from the identity branch after prerequisites land.

The parent issue owns final integration, examples, migration documentation,
changelogs and external-consumer evidence. Child completion needs focused
behavior that passes against already-proven prerequisites; an eventual
end-to-end test is not the first proof.

## Local validation and generation ownership

GitHub Actions is disabled. Use the current repository validator in
`tool/validation`, derived from the root workspace and shared policy inventory;
do not copy the obsolete package lists from abandoned local guidance.

For each child:

1. Resolve workspace packages with `dart pub get` at the root.
2. Inspect builder IDs, annotated inputs, expected outputs and owning part
   directives. Give each combined generated part/build cache one owner.
3. Run required generation sequentially from its owning consumer directory.
   Verify outputs exist and compile with the owning library. Never hand-edit
   generated parts.
4. Format-check owned handwritten Dart files and run focused behavioral tests.
5. Analyze/test affected packages, downstream consumers and affected examples.
6. Run applicable validator package/example/minimal-consumer lanes.

Final parent validation runs `./scripts/test-all.sh` plus service-backed
MongoDB, DynamoDB Local and MySQL lanes against locally provisioned services.
The convenience local mode intentionally excludes those services. Record
external-service and optional real-AWS checks separately; unrun is not passed.

A standalone outside-workspace Dart consumer must resolve an immutable pushed
candidate revision, generate where applicable, and exercise UUID, native
GitHub-like and scoped/composite identities. Include negative analyzer cases
for unrelated ID kinds, malformed codec values and scope collisions.
There is no Worky application lockfile to update yet.

## Migration and approval boundary

Migration examples cover both:

- Existing UUID aggregates moving to UuidAggregateRoot (or explicitly passing
  UuidValue), with repositories/events using their documented generic types.
- An externally identified aggregate receiving its actual native identity,
  with an explicit codec and typed repository; no generated UUID is inserted.

Adapt all repository-owned examples and consumers. Preserve current UUID
round-trip functionality and document any wire/schema changes deliberately.
Do not absorb browser persistence (#29), publication (#30), timestamp redesign
or unrelated event-feature work.

This planning PR does not claim implementation, test passes or completed
AI-DLC stages. A dedicated dddart work record and API/codec decisions must be
settled before implementation. Validated child PRs may merge upward as far as
feat/worky-changes. Final branch review, merge to main and release remain owner
actions.
