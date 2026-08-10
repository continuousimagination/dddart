# Working in dddart

## Scope

These instructions apply to the entire repository. Add a nested `AGENTS.md` only
when a directory develops genuinely different operating constraints; do not copy
this file into every package.

dddart is one Dart workspace containing the core domain framework, serialization
and code-generation packages, REST server and client packages, repository
backends, integrations, and runnable examples. Framework packages live under
`packages/`; examples are consumers of those packages and must not be treated as
more authoritative than the public framework contracts they exercise.

Use `CONTRIBUTING.md` as the canonical change and validation workflow. Use
`docs/framework-map.md` to locate package roles, implemented dependency
relationships, generated-code topology, and framework testing seams.

Treat the root `pubspec.yaml` workspace list as authoritative membership. Treat
`tool/validation/inventory.json` as the shared local/CI validation policy for
packages and examples; repository validation checks that the two inventories do
not drift.

## Establish authority before changing code

Follow the explicit task and any accepted active specification. To establish the
current repository behavior, prefer evidence in this order:

1. Exported public source and type signatures.
2. Generator source, annotations, and `build.yaml` configuration.
3. Executable tests and generated-output compile checks.
4. Package documentation and examples corroborated by the first three.

Use tool-specific steering or specification metadata, dated experiments, and
files under `docs/agent-native/` for intent or history only. Corroborate
operational claims against the root workspace, `.gitignore`, current source, and
executable checks. Proposed APIs are not current conventions until implemented.

When an explicit requirement, public source, tests, generated behavior, and
documentation disagree, do not silently choose one. Record the conflict and ask
the contract owner or Architect to resolve it.

## Use the Architect skill for cross-boundary planning

For work that crosses packages, persistence and domain boundaries, generated and
handwritten code, or REST client/server/composition boundaries, read and follow
`skills/dddart-architect/SKILL.md` before dispatching implementation workers.

The Architect freezes dddart contracts, classifies dependencies, and supplies
bounded work items. An implementation worker must honor the frozen contract,
owned paths, forbidden peer dependencies, and assigned behavioral completion
test. Workers do not renegotiate shared contracts among themselves; return
ambiguity to the Architect.

Do not invoke an architecture exercise for a small, local change whose contract,
ownership, and focused test are already clear.

## Preserve dddart boundaries

- Repositories manage `AggregateRoot` instances. Do not create repositories for
  nested entities merely to split work.
- `Repository<T>` is deliberately CRUD-only. Define an application or
  domain-specific read interface when collection access is required, including
  explicit selection, ordering, pagination, count, and continuation semantics.
- Treat `InMemoryRepository<T>` as an instance-local consumer test fake. Its
  concrete `getAll` and `getAllSync` helpers are test/prototype conveniences,
  not a nominal repository capability. It does not prove serializer, database,
  transaction, concurrency, ordering, or custom repository-interface behavior.
- Use a focused fake or adapter when a consumer requires a domain-specific
  repository interface with methods beyond the base contracts.
- Depend on `Serializer<T>` or `JsonSerializer<T>` rather than a concrete
  serializer when the interface is sufficient. Stock `CrudResource` accepts one
  `JsonSerializer<T>` and its CRUD representation is intentionally JSON-only.
  Preserve aggregate constructor shape and serialization semantics across
  generated boundaries.
- Inspect the selected repository generator before assuming its capabilities,
  implemented interfaces, constructor, or generated class shape; repository
  backends are not interchangeable.
- Treat underscore-prefixed generated members as Dart library-private, not
  subclass-protected. A `part` may share them within one library but does not
  create an independently importable or independently validated boundary.
- Treat `QueryHandler<T>` as the current in-process REST callback contract, not a
  complete client/server operation contract. Unfiltered collection GET requires
  an explicit `collectionHandler` and returns 400 when none is configured.
  Freeze custom query paths, keys, encoding, pagination, result metadata, and
  errors before parallel client and server implementation.

Prefer existing dddart contracts and constructor injection over concrete peer
implementations. Add a new boundary only when no natural dddart seam exists and
its critical-path benefit justifies its contract, testing, and integration cost.

## Control generated and shared state

Never hand-edit `*.g.dart` or generator cache output. Existing ignored generated
files and `.dart_tool` state may be stale; they are not architectural evidence.
`packages/dddart_rest/lib/src/standard_claims.g.dart` is intentionally tracked
for package runtime use, but it is still generator-owned.

Before source workers begin, identify:

- the package and working directory that own generation;
- the exact builder identifiers and command;
- the handwritten inputs and expected combined outputs;
- whether generated files and `.dart_tool/build` are shared by multiple tasks.

Give generation a single owner or isolate its build state. Do not run concurrent
generators against the same combined part or cache. A successful command exit is
not enough: verify that expected outputs exist, are current, are referenced by the
owning library's `part` directives, and compile with that library.

## Work safely in the workspace

- Run `dart pub get` from the workspace root for workspace members. If validating
  a standalone example not listed in the root workspace, resolve and run it from
  that example directory.
- Preserve existing working-tree changes and unrelated untracked files. Do not
  broaden a task to repair them unless they block the requested completion gate;
  report such a blocker before expanding scope.
- Keep worker write sets disjoint. Assign a single owner to package manifests,
  public barrel files, generated parts, build state, and composition roots.
- For public API changes, update exports, affected documentation and tests, and
  release notes according to the affected package's existing convention.
- Inspect downstream workspace packages when changing a shared public contract.
- Do not commit, push, publish, or open a pull request unless the task explicitly
  requests it.

## Validate behavior, not only syntax

Every implementation work item must have a focused behavioral test that can pass
without an unfinished peer implementation. Use dddart's natural seams:

- `InMemoryRepository<T>` or a focused repository fake for domain/server logic;
- an injected `http.Client` through `RestConnection` for REST client behavior;
- direct `QueryHandler<T>` or `CrudResource.handleQuery` invocation for query
  behavior;
- fixed serializer round-trip and malformed-value cases for serialization work.

Run validation in increasing scope:

1. Run and verify required generation.
2. Format-check the owned handwritten Dart paths.
3. Run the focused behavioral test.
4. Analyze and test each affected package.
5. Test affected downstream workspace packages.
6. Run the broad repository gate appropriate to the task.

Run `scripts/test-all.sh` for the shared local gate. It validates
`tool/validation/inventory.json` against the root workspace and discovered
examples, then checks all declared packages and examples. Local mode
intentionally excludes MongoDB, DynamoDB, and MySQL service-backed tests; report
those exclusions when they were not run.

Do not use a later end-to-end test as the first behavioral proof for a supposedly
independent worker. Integration should verify already-proven components, not
discover their unstated contract.

## Finish with an evidence-backed handoff

Report affected contracts, commands and results, generated or shared state,
documentation/source conflicts, unrun external-service tests, and unresolved
framework ambiguities.

Do not declare completion when the owned behavior still depends on an unfinished
peer, an unverified generated artifact, or an implicit convention.
