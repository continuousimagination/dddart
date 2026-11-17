# Testing dddart_repository_sqlite

Resolve workspace tooling with `dart pub get` from the repository root.
The [package pubspec](pubspec.yaml) declares SDK and dependency constraints. Run the integrated package and sample lanes:

```sh
dart tool/validation/validate.dart package dddart_repository_sqlite --mode=ci
dart tool/validation/validate.dart example dddart_repository_sqlite_example --mode=ci
```

The package lane regenerates required fixtures, analyzes, tests and checks package
contents. The example lane independently regenerates model parts, analyzes and
compiles every program, then runs its finite/service entrypoints. The
[shared policy](../../tool/validation/inventory.json) is authoritative for
builders, tags, dependencies and required services. Local mode can exclude
service-dependent work; it is not equivalent to a passing required CI lane.

[The sqlite quickstart](../../docs/quickstarts/sqlite/README.md) documents
runtime/service prerequisites and disposable local setup. SQLite needs its native
shared library even without a server. Database lanes use fresh test storage; do
not run destructive sample cleanup against application data.

See [test sources](test), [example programs](example/README.md),
[capability limits](../../docs/CAPABILITIES.md) and
[validation commands](../../scripts/README.md). Current tests determine evidence;
historical test counts, unchecked design checklists and skipped cases do not
establish a supported feature. A local database does not certify every deployed
version/topology or cloud-compatible service.
