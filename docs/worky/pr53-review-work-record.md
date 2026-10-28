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
Logs: /private/tmp/dddart-pr53-review-20261028. These focused results preceded
the final completion gates recorded below.

## Validation repair discovered by the broad gate

The first broad run exposed a pre-existing socket-suite race: integration_test
and http_server_test both bind port 8082 (and other overlapping fixed ports),
while HttpServer uses shared binds. The second paginated query reached another
suite's resource and returned 400. The isolated query test passes unchanged.
The REST test configuration now serializes these socket suites; production
routing/query behavior is unchanged. This test-only repair is required to make
the completion gate deterministic and is validated with the full REST suite.

The same run found source_gen trying to resolve unrelated test-library @Tags
metadata in the SQL packages. Their default generation targets now identify
the actual fixture, library and example/lib inputs for both builders, following
the existing distributed-event package convention. Generator tests still supply
their own build_test sources; consumer auto-application remains unchanged.
Required generation deletes and verifies the owning combined parts, so narrowing
inputs does not allow stale generated output to satisfy the gate.

The new external consumer resolves ten packages at immutable revision
993252697d56417562e5f85503d64633647d1ae3. Generation, fatal analysis and execution
pass for unprefixed shell metadata/reload, strict prefixed diagnostics, final
POST/preCreate key rejection with zero writes, routable Unicode creation, and
real MySQL/SQLite inherited generic entity CRUD/order/FK/delete isolation.
It uses a separate disposable MySQL probe database. This is new candidate
coverage, not a reuse of the older thirteen-package baseline assertion.

## Final completion evidence

Functional fixes: 993252697d56417562e5f85503d64633647d1ae3.
Full-gate candidate: c1d8f5de06c7579aa7b5a60e3b22739f0bf80507.
Production library files are identical between those revisions; the intervening
commits adjust test/build configuration and evidence. This final record update
changes documentation only.

The following commands completed successfully on the full-gate candidate:

```sh
./scripts/test-all.sh
dart run tool/validation/validate.dart package dddart_repository_mysql --mode=ci
dart run tool/validation/validate.dart example dddart_repository_mysql_example --mode=ci
```

- The workspace-derived local gate passed all 15 package gates, 15 isolated
  archive consumers and 13 example-policy lanes. This includes required owning
  generation, format checks, fatal analysis and applicable publication dry runs.
  The inventory check reconciles membership against the root pubspec workspace.
- Full affected suites passed: configuration 156, REST 311, SQLite 95 and
  service-backed MySQL 192 tests. Downstream REST repository tests also pass
  (110), along with shared SQL tests (85) and the other workspace package gates.
- MySQL's explicit service-backed example lane passed its runnable entrypoints,
  including custom repository behavior. The MySQL package dry run reports zero
  warnings. No packages were published.
- The immutable ten-package Git consumer described above passed fresh
  generation, fatal analysis and execution against both real MySQL and SQLite.
  Its fixture/logs are retained outside the workspace at
  /private/tmp/dddart-pr53-consumer-9932526 and
  /private/tmp/dddart-pr53-review-20261028/git-consumer.log.

Generation remains single-owner per package/example cache. The SQL fixture
builders are dddart_json:json_serializable plus
dddart_repository_mysql:mysql_repository or
dddart_repository_sqlite:sqlite_repository, invoked by
scripts/run-required-generation.sh and the example validator. Expected combined
parts are regenerated, checked for existence and compiled with their owning
libraries; no generated parts were hand-edited or committed.

The temporary MySQL container dddart-review53-mysql-20261028 and its anonymous
volume were removed after successful validation. MongoDB/DynamoDB external
service lanes were not rerun for these bounded fixes; their original baseline
service evidence remains historical. Real AWS/OIDC and inventory-excluded legacy
examples remain unrun, and compile-only examples retain that classification.
Configuration policy/API notes, affected package guides and changelogs are
updated. No unresolved source/specification conflicts remain for R1–R3.

PR #53 remains open against unchanged main
c538680619a11af79e7094c3087646189c313978. Reviewer re-evaluation and adoption
approval are still pending; this work does not dismiss the requested changes
review or merge the PR.
