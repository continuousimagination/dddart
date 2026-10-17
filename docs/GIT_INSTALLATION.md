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
