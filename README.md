# DDDart

DDDart is a Dart workspace for building domain-driven applications with domain
primitives, serialization and code generation, repository backends, REST server
and client support, webhooks, configuration, and experimental distributed
events.

The repository currently contains 15 framework packages. See the
[framework map](docs/framework-map.md) for their exact roles, dependencies,
generated-code boundaries, and runtime requirements.

## Package groups

- **Domain foundation:** `dddart`, `dddart_serialization`, and `dddart_json`.
- **Persistence:** MongoDB, DynamoDB, SQLite, MySQL, shared SQL infrastructure,
  and generated REST client repositories.
- **HTTP:** `dddart_rest` for Shelf server resources and
  `dddart_rest_client` for authenticated clients.
- **Supporting packages:** configuration, generic and Slack webhooks, and
  experimental distributed events.

Repository implementations do not all expose the same capabilities. CRUD uses
`Repository<T>`; collection reads belong in explicit application or domain
interfaces with defined query and pagination semantics. Consult the
[capability matrix](docs/framework-map.md#repository-capability-matrix) before
selecting or abstracting a backend.

## JSON serialization quick start

Within this unreleased workspace, add the current foundation packages and a
builder to a consumer package:

```yaml
dependencies:
  dddart:
    resolution: workspace
  dddart_serialization:
    resolution: workspace
  dddart_json:
    resolution: workspace

dev_dependencies:
  build_runner: ^2.4.0
```

Define an annotated domain type. The owning library imports the JSON package and
has one combined generated part:

```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'user.g.dart';

@Serializable()
class User extends AggregateRoot {
  User({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final String email;
}
```

Generate from the consumer package that owns the annotated library:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then use the generated serializer:

```dart
final serializer = UserJsonSerializer();
final user = User(name: 'John', email: 'john@example.com');

final json = serializer.toJson(user);
final jsonString = serializer.serialize(user);

final userFromJson = serializer.fromJson(json);
final userFromString = serializer.deserialize(jsonString);
```

Multiple generators can contribute to the same `user.g.dart`. Do not add a
separate part directive for each serializer or repository backend.
Consumer-generated files are normally ignored by Git, so regenerate and compile
the owning library instead of trusting locally present output.

## Development

The root `pubspec.yaml` is authoritative for workspace membership. Resolve the
workspace from the repository root:

```bash
dart pub get
```

Run focused analysis and tests from each affected package or example. The root
does not contain an all-workspace Dart test suite. `scripts/test-all.sh` is the
shared local gate; it validates the workspace-backed policy in
`tool/validation/inventory.json`, then checks every declared package and example.
Local mode intentionally excludes MongoDB, DynamoDB, and MySQL service-backed
tests; CI supplies those service lanes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the canonical contributor workflow and
[AGENTS.md](AGENTS.md) for repository-wide agent guidance.

## Platform support

Runtime requirements differ by package. Server and file-based APIs use
`dart:io`, SQLite uses a native embedded library, and MongoDB, DynamoDB, and
MySQL integrations require their corresponding services or local emulators. Do
not infer support for a target from this root package list; verify the selected
package and compile for the intended platform.

## License

MIT License. See package directories for package-specific metadata.
