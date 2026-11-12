# Install dddart from Git

The dddart packages are Git-only for now. A hosted dependency such as
`dddart: ^0.9.0` does not work in an external application because core is not
on pub.dev. The Git-only manifests for `dddart_serialization` and
`dddart_json` use sibling path dependencies, which Pub resolves from the same
Git checkout.

Choose one full commit SHA from this repository for all direct dddart
dependencies in your application. Commit the application's `pubspec.lock` so
its dependency graph stays reproducible. Replace `<same-full-commit-sha>` in
the examples below with an actual 40-character commit SHA.

## Core only

```yaml
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart
```

## Core and serialization

```yaml
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart_serialization
```

For `dddart_json`, add another direct Git dependency at the same SHA with
`path: packages/dddart_json`. The three packages resolve without root
`dependency_overrides`. Other sibling packages still using hosted internal
dependencies may need overrides until their manifests are converted or they
are published.

Run `dart pub get` (or `flutter pub get` in a Flutter app) after editing the
pubspec. The serialization and JSON packages are marked `publish_to: none`
while they contain sibling path dependencies. If the project later publishes
them, it must first publish their internal dependencies, then restore hosted
constraints and remove `publish_to: none`. [Issue #30](https://github.com/continuousimagination/dddart/issues/30)
tracks that release path.

## Core and IndexedDB

The IndexedDB adapter is Git-only and uses sibling path dependencies on core and
serialization. A clean browser consumer can pin both direct packages to one full
SHA without `dependency_overrides`:

```yaml
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart
  dddart_repository_indexeddb:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart_repository_indexeddb
```

Add direct serialization and `idb_shim: 2.10.1+1` dependencies when importing their
registry and native factory APIs. See the [adapter guide](../packages/dddart_repository_indexeddb/README.md)
for typed identity composition, schema compatibility and browser limits. Use the
final accepted integration SHA after review/merge, not the old UUID-only browser
branch SHA. Record the resolved Git SHAs from the clean consumer's lockfile.

After the candidate is published, verify it from outside the workspace with:

```sh
dart tool/validation/verify_indexeddb_git_consumer.dart <same-full-commit-sha>
```

The helper creates a fresh temporary consumer with no dependency overrides,
checks that all three dddart lockfile entries have that exact Git revision,
analyzes the consumer, and runs typed persistence contracts on VM and native
Chrome. It fails if Chrome is unavailable. An optional second argument is an
unauthenticated HTTPS or local file Git URL for an isolated test fixture; fixture
SHAs are not accepted upstream revisions. Run again on the final accepted main
SHA and retain its output as acceptance evidence.
