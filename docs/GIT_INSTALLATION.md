# Install DDDart from Git

Use the [quickstarts](QUICKSTARTS.md) for a new application. Their example
pubspecs contain the SDK constraint, dependency sources, and any overrides
needed by the sample.

## Add DDDart to an existing application

Choose a full commit SHA. Use it for every DDDart Git dependency in your app.
The [core example pubspec](quickstarts/core/pubspec.yaml.txt) shows a tested
revision. For each DDDart package you import, add a direct Git dependency under
`dependencies` in your application's `pubspec.yaml`:

```yaml
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <full-commit-sha>
      path: packages/dddart
```

Replace the placeholder with the chosen SHA. For another package, use its
package name as the dependency key and its directory under `packages/` as the
path. Use an adapter's example pubspec to see its complete dependency graph:
for instance, [JSON](quickstarts/json/pubspec.yaml.txt) pulls in the serializer
and generator, and [SQLite](quickstarts/sqlite/pubspec.yaml.txt) also shows the
overrides needed for that adapter.

## Resolve sibling dependencies

Some packages already resolve their sibling packages from the Git checkout.
Others still declare hosted DDDart dependencies. When Pub tries to resolve such
a sibling from the hosted registry, add its Git entry under
`dependency_overrides` in your application's root pubspec, with the same SHA.
Keep direct dependencies for packages your code imports. Use the adapter
quickstart to find its override entries. For packages without a standalone
quickstart, check their pubspecs for hosted DDDart siblings and follow their
dependencies until every DDDart package resolves from the chosen checkout.

Run `dart pub get` (or `flutter pub get` in a Flutter project) and commit the
application's `pubspec.lock` to record the resolved dependency graph.

## Core and IndexedDB

To use native browser persistence, add `dddart` and
`dddart_repository_indexeddb` from the same Git SHA. The adapter resolves core
and serialization from that checkout, so this combination needs no overrides.
If your code imports `dddart_serialization` or the native `idb_shim` factory,
declare those dependencies directly as well. The
[adapter pubspec](../packages/dddart_repository_indexeddb/pubspec.yaml)
declares the adapter's dependency constraints.

Follow the [IndexedDB guide](../packages/dddart_repository_indexeddb/README.md)
to supply an identity codec where needed, an aggregate encoder/decoder, and the
native browser factory.
