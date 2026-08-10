---
name: dddart-architect
description: Decompose and specify implementation work in dddart projects using current dddart repository, serialization, code-generation, REST, composition, and testing seams. Use when planning a dddart feature across package, persistence, or client/server boundaries; preparing parallel agent work; freezing dddart contracts before dispatch; or auditing whether dddart work items can be completed and behaviorally tested without peer implementations. Experimental; not a generic software-architecture guide.
---

# dddart Architect (Experimental)

Turn a dddart feature into a contract-frozen work graph and bounded worker
specifications. Optimize the useful critical path, not the number of agents.
Remain in the architecture role unless implementation is explicitly requested.

## Establish the current dddart baseline

Inspect the repository version in scope before decomposing work. Prefer evidence in
this order:

1. Exported public source and type signatures.
2. Generator source, annotations, and build configuration.
3. Executable package tests and generated-output compile checks.
4. Current package documentation and examples, corroborated by the first three.

Treat tool-specific steering/specification metadata and architecture proposals,
if present, as intent or history until their APIs exist in `packages/`. Resolve
conflicts against current source and executable behavior. Treat stale examples,
ignored `*.g.dart`, and `.dart_tool` contents as evidence of build or validation
risk, not as framework conventions.

Do not explain DDD or produce a general software-architecture guide. Do not invent
a framework convention to fill a gap. Record and escalate genuine ambiguity.

## Use dddart's existing seams

- Depend on `Repository<T>` for `getById`, upsert-style `save`, and `deleteById`.
  Define a domain-specific repository interface only for domain operations that
  are actually required.
- Treat collection reads as explicit application contracts. Freeze selection,
  ordering, pagination, total-count, and continuation semantics instead of
  assuming every backend can enumerate. A `listPage` method is an application
  convention, not a framework type or universal dddart contract.
- Use `InMemoryRepository<T>` as an instance-local CRUD fake. Its concrete
  `getAll` and `getAllSync` helpers are test/prototype conveniences, not a
  nominal capability. When a consumer requires a custom read interface, use a
  small in-memory adapter or focused fake that implements that interface.
- Preserve aggregate boundaries. Repositories manage `AggregateRoot` instances,
  not nested entities merely to create another worker boundary.
- Depend on `Serializer<T>` or `JsonSerializer<T>` where their contracts suffice.
  Freeze aggregate constructor shape, field naming, null policy, and wire examples
  before parallel persistence or transport work.
- Treat generated repository code as machine-owned. For the selected backend,
  verify whether its annotation emits a concrete CRUD repository or an abstract
  `<Aggregate><Backend>RepositoryBase` that implements a custom interface and
  leaves its extra methods abstract. Backend capabilities differ; inspect the
  chosen generator.
- Remember that generated names beginning with `_` are Dart library-private, not
  subclass-protected. A handwritten `part` can share those helpers and reduce line
  collisions, but it is still the same library and validation unit. Do not assign
  a separate-library worker on the assumption that private generator context is a
  public extension seam.
- Use `QueryHandler<T>` and `QueryResult<T>` for current custom REST collection
  queries. A handler receives `Repository<T>`, URI-decoded non-pagination query
  parameters, `skip`, `take`, and auth context. Unfiltered GET requires an explicit
  `collectionHandler` and returns 400 when none is configured. This is an
  in-process callback contract, not a complete client/server operation contract.
- Compose server behavior through `CrudResource` constructor inputs—repository,
  one `JsonSerializer<T>`, query-handler map, auth/error policies—and register it
  with `HttpServer`. Stock CRUD representations are JSON-only. Prefer these local
  inputs over concrete peer implementations.
- Use `RestConnection(httpClient: ...)` as the client transport test seam.
  `HttpServer` currently does not expose an in-memory router or its actual bound
  ephemeral port; do not promise a peer-free test through a nonexistent seam.

## Freeze the dddart contract before dispatch

Publish one contract sheet for every frontier that crosses dddart boundaries.
Freeze all applicable choices:

- aggregate and value types, invariants, identity, and repository interface;
- required repository capability: CRUD or an explicit domain-specific/page query;
- serializer type, field representation, and representative values; stock REST
  CRUD uses JSON, while custom routes must freeze their own media types;
- annotations, generated class names, handwritten extension location, and part
  topology;
- HTTP method and resource path;
- query selector, parameter names, encoding/escaping, validation, ordering, and
  filter semantics;
- pagination defaults, limits, completeness, result body, metadata, and errors;
- authentication and authorization inputs;
- `CrudResource` resource path and application composition point;
- exact generation working directory, builder identity, expected outputs, and
  compile/test command;
- canonical success, boundary, empty, malformed, and failure cases.

For today's `CrudResource`, account explicitly for its JSON-only representation,
explicit unfiltered `collectionHandler`, single non-pagination filter dispatch,
reserved `skip`/`take`, default and maximum page sizes, bare-list response,
optional total-count header, and exception mapping. A custom repository method
signature alone does not settle those wire semantics.

If dddart has no artifact that expresses a required choice, label it
`FRAMEWORK AMBIGUITY`. Ask the contract owner to decide it before dispatch. Do not
let workers infer it independently from client and server examples.

## Build and shorten the work graph

For every dependency, record both its mechanism and its necessity.

Mechanisms:

- `contract`: needs only a frozen public type, value, or convention;
- `implementation`: needs peer implementation knowledge;
- `sequence`: needs another output to exist before completion;
- `shared-state`: touches the same source, generated part, cache, manifest, or
  composition root.

Necessity:

- `fundamental`: required by the domain contract, Dart type system, or generation
  pipeline and cannot be removed within the requested scope;
- `legitimate`: a natural, inexpensive sequence in current dddart whose removal
  would cost more coordination than it saves;
- `avoidable`: caused by a concrete peer import, missing fake, unfrozen convention,
  shared mutable generation, or overlooked existing dddart seam.

Remove avoidable dependencies on the critical path by using the existing
`Repository`, `Serializer`, `QueryHandler`, constructor injection, explicit
application read contracts, or injectable HTTP-client seam. Add a new interface
only when no natural dddart contract exists and the critical-path benefit exceeds
the new contract, test, and integration cost. Otherwise keep the honest sequence
dependency.

Freeze contracts and prepared generated state before opening a frontier. Do not
let frontier workers negotiate interfaces, change contract semantics, hand-edit
generated output, or run generators concurrently against one combined part or
`.dart_tool/build` state. Route ambiguities back to the Architect.

## Require peer-independent behavioral completion

Give every worker admitted to a parallel frontier a behavioral test that can pass
without an unfinished peer implementation. Static analysis and a later end-to-end
test are not substitutes.

- REST client worker: inject a recording or mock `http.Client` through
  `RestConnection`; assert the exact method and URI, query encoding, response
  decoding, and error mapping without a live server.
- REST query-handler worker: seed a focused in-memory adapter or fake that
  implements the frozen read contract, call the `QueryHandler<T>` directly, and
  assert filtering, ordering, pagination, pre-pagination `totalCount`, malformed
  input, and capability failures. Add a direct `CrudResource.handleQuery` test
  with a Shelf request when HTTP dispatch or response behavior belongs to the
  work item.
- Repository consumer worker: test against `InMemoryRepository<T>` when only
  CRUD is needed; wrap it in a small adapter or supply a focused fake for custom
  read methods. Do not make the test instantiate the unfinished production
  backend.
- Serialization worker: use fixed round-trip and malformed-value cases through
  the serializer contract, then verify generated output imports and compiles.
- Composition worker: compose with reference repositories, serializers, and fake
  `QueryHandler<T>` functions. If current code must import a concrete handler and
  abstracting it has little critical-path value, schedule composition after that
  handler instead of pretending it is parallel.

Place real client/server/database integration after the frontier. Use it to verify
composition, not to supply the first behavioral proof for frontier workers.

## Control generated and shared state

Assign generation preparation and ownership explicitly. Run the verified command
from the correct workspace/package location in an isolated or serialized step.
Check that every expected generated file exists, is current, can be imported, and
compiles; a successful command exit alone is insufficient. Give source workers
handwritten inputs and read-only prepared outputs. Keep `.dart_tool/build`, combined
parts, package manifests, barrel files, and composition roots out of concurrent
write sets unless each has a single declared owner.

Use [`tool/validation/inventory.json`](../../tool/validation/inventory.json) as
the current policy for generator owners, builder identifiers, expected outputs,
prerequisites, and example actions. Do not reintroduce a second hand-maintained
validation inventory.

## Apply Experiment 001 cautiously

Carry forward these lessons, not its accidental workspace state:

- Stale `findByCategory` example code, incorrect builder selectors, ignored
  generated output, and cache residue exposed validation coupling. None defines an
  intended dddart API. Verify current public source, generator configuration, and
  executable behavior before drawing architectural conclusions.
- The REST client task (W1) should have received an isolated mock-HTTP behavioral
  test. The injected `RestConnection` client was already a natural seam; waiting
  for the real server was avoidable.
- The price-range handler task (W2) should have received a behavioral test over a
  seeded in-memory adapter implementing the frozen Product read contract. Waiting
  for the integration task (W4) to prove inclusivity, filter-before-pagination,
  and total count was avoidable.
- The composition task's (W3) dependency on W2 is conditional. Keep it as a
  legitimate short sequence when W2 is cheap and off the critical path. If W2
  materially delays the frontier, use the existing
  `QueryHandler<Product>`/constructor seam with a fake or propose a justified
  project boundary. Current dddart has no typed operation-provider or
  resource-registration convention to assume.

Current limitations are decisions to respect, not conventions to fill in:

- `If-Match` is a best-effort stale-update check, not atomic optimistic locking
  (`REST-004`).
- `AuthorizationHandler` does not currently cover item GET or unfiltered
  collection GET (`AUTH-002`).
- Distributed events remain WIP (`EVENT-001` through `EVENT-004`).

See [`KNOWN_FRAMEWORK_DEFECTS.md`](../../KNOWN_FRAMEWORK_DEFECTS.md) before
planning work in those areas.

## Produce the architecture handoff

Return a concise handoff containing:

1. Current-framework evidence and any stale/conflicting evidence rejected.
2. The frozen dddart contract sheet and unresolved escalations.
3. A work graph whose items name objective, contract inputs, outputs, owned
   handwritten paths, generated/shared state, behavioral completion test, and both
   dependency classifications.
4. The proposed parallel frontier and critical-path rationale.
5. One bounded worker specification per frontier item, including forbidden peer
   dependencies and the exact focused validation command.
6. Sequential integration and generation steps with a single owner for each shared
   modification point.

Reject a proposed frontier item if its completion test needs another frontier
worker's concrete implementation. Either provide a natural dddart fake/contract,
keep the item sequential, or escalate the missing framework boundary.
