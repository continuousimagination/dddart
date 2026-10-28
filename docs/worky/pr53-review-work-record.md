# PR #53 review fixes

Reviewed baseline: d2092423261afdaaea72bf73b5c192595549d1d6.
PR target remains main; the owner requests fixes without merging the PR.

## Bounded resolutions

- R1: In unprefixed environment loading, ignore names whose mapped paths have
  empty segments (including ordinary `_` shell metadata). An explicit application
  prefix remains strict for malformed selected names. Normalized duplicates and
  ancestor/descendant conflicts remain errors in both modes. Reload retains its
  snapshot on failures. Prove construction/read/reload with deterministic shell
  metadata fixtures, plus prefixed malformed paths and collisions.
- R2: Validate the final aggregate's canonical REST key after preCreate and
  before authorization/persistence. Unsupported/noncanonical request identities
  return 400 Problem Details with zero writes. Reuse the existing key boundary;
  prove dot keys, malformed Unicode, an unsupported preCreate result and a
  valid punctuation/Unicode create-to-get round trip.
- R3: Resolve collection field types in parent-FK discovery using the same
  IdentityTypeAnalysis.fieldType seam as discovery/schema generation. Exercise
  List<C> on an unannotated generic base, concretely bound to scoped-ID children.
  Prove generated MySQL schema and service-backed save/load/update/order/delete
  isolation. Inspect and test SQLite independently against its junction layout.

One owner runs generation sequentially in each SQL package/example cache, using
its repository builder and dddart_json:json_serializable. No generated parts are
hand-edited. Focused red/green regressions precede affected package, downstream,
example and archive-consumer gates. Existing prior-head integration evidence
remains historical; this record will identify the new candidate and actual checks.

## Focused reproduction and repair

- R1 fails on the reviewed implementation with the exact `_` + DATABASE_HOST
  fixture. The fixed seven-case environment suite passes construction/read/reload,
  unprefixed collision diagnostics and existing strict prefixed cases.
- R2 fails because dot-key POST and preCreate-invalid-key POST return 201. The
  fixed six-case native resource suite passes with zero writes for unsupported
  final keys and a routed Unicode/punctuation create/get round trip.
- R3 fails in a freshly generated consumer with missing parent/order schema.
  A provisioned MySQL test also reproduces successful root saves followed by
  missing collection reconstruction. After concrete substitution, eight focused
  MySQL/clean-consumer cases pass, including CRUD/order/FK/deletion isolation.
  SQLite's independently generated junction-layout suite passes all five cases;
  its analogous raw discovery loop now uses the same concrete substitution.

Cached analyzer annotation errors in old build state were cleared with
build_runner clean before the successful owning generations; they are not counted
as behavioral reproductions. Temporary MySQL service: task-owned
`dddart-review53-mysql-20261028`, loopback 3307, disposable `test_db`.
Logs: /private/tmp/dddart-pr53-review-20261028. Broad/package/downstream/consumer
completion gates are still pending at this checkpoint.

## Validation repair discovered by the broad gate

The first broad run exposed a pre-existing socket-suite race: integration_test
and http_server_test both bind port 8082 (and other overlapping fixed ports),
while HttpServer uses shared binds. The second paginated query reached another
suite's resource and returned 400. The isolated query test passes unchanged.
The REST test configuration now serializes these socket suites; production
routing/query behavior is unchanged. This test-only repair is required to make
the completion gate deterministic and is validated with the full REST suite.

The new external consumer resolves ten packages at immutable revision
993252697d56417562e5f85503d64633647d1ae3. Generation, fatal analysis and execution
pass for unprefixed shell metadata/reload, strict prefixed diagnostics, final
POST/preCreate key rejection with zero writes, routable Unicode creation, and
real MySQL/SQLite inherited generic entity CRUD/order/FK/delete isolation.
It uses a separate disposable MySQL probe database. This is new candidate
coverage, not a reuse of the older thirteen-package baseline assertion.
