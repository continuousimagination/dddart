# Install DDDart from Git

DD Dart packages are not yet available on pub.dev. A hosted dependency such as
`dddart: ^0.9.0` therefore does not work in an external application. Pub
resolves sibling packages from this repository's workspace while working here,
but an application fetching one package from Git is outside that workspace.

Choose a full commit SHA from this repository and use it for every DDDart
package in the application. Commit the application's `pubspec.lock` so its
dependency graph stays reproducible.

## Core only

Replace `<same-full-commit-sha>` with an actual 40-character commit SHA:

```yaml
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart
```

Then run `dart pub get` (or `flutter pub get` in a Flutter app). Core needs no
override when used on its own.

## Core and serialization

`dddart_serialization` currently declares `dddart: ^0.9.0` from the default
hosted source. A root override must send that transitive dependency to the
same Git commit as the direct dependencies:

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

dependency_overrides:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: <same-full-commit-sha>
      path: packages/dddart
```

If the app also uses `dddart_json`, add it as a Git dependency at the same SHA
with `path: packages/dddart_json`, and override both `dddart` and
`dddart_serialization` to their respective paths at that SHA. Other unpublished
sibling packages can require the same treatment. Keep overrides in the
application's root pubspec; overrides in a dependency do not apply to its
consumers.

The long-term way to remove these overrides while keeping the packages
publishable is to publish core before packages that depend on it, then publish
those packages in dependency order. Relative path or Git dependencies in their
package manifests would make the current Git checkout easier to consume, but
Pub rejects those dependencies in packages published to pub.dev.
Publication is tracked in [issue #30](https://github.com/continuousimagination/dddart/issues/30).
