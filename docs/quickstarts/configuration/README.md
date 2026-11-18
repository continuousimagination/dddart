# Layered configuration

Use YAML for defaults and override the server port for one run. The program
checks the settings before a service would start.

## Set up the application

Create an empty directory outside the repository with a `bin` subdirectory.

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the application files

Save as `bin/configuration.dart`:

<!-- dddart-source: docs/quickstarts/configuration/bin/configuration.dart -->
```dart
import 'package:dddart_config/dddart_config.dart';

void main() {
  final config = Configuration([
    EnvironmentConfigProvider(prefix: 'BOOKING'),
    YamlConfigProvider('config.yaml'),
  ]);

  config.validate([
    ConfigRequirement(key: 'server.host', type: ConfigType.string),
    ConfigRequirement(
      key: 'server.port',
      type: ConfigType.integer,
      validator: (value) {
        final port = value as int;
        if (port < 1 || port > 65535) {
          throw ArgumentError('Invalid port');
        }
        return port;
      },
    ),
    ConfigRequirement(key: 'allowed_origins', type: ConfigType.list),
  ]);

  print(config.getRequiredString('server.host'));
  print(config.getRequiredInt('server.port'));
  print(config.getBoolOrDefault('logging.verbose', false));
  print(config.getRequiredList('allowed_origins'));
}
```
<!-- /dddart-source -->

Save as `config.yaml`:

<!-- dddart-source: docs/quickstarts/configuration/config.yaml -->
```yaml
server:
  host: 127.0.0.1
  port: 8080
logging:
  verbose: false
allowed_origins:
  - https://example.com
```
<!-- /dddart-source -->

## Run the example

<!-- dddart-source: docs/quickstarts/configuration/commands.sh -->
```sh
dart pub get
BOOKING_SERVER_PORT=9090 dart run bin/configuration.dart
```
<!-- /dddart-source -->

Expected output from `bin/configuration.dart`:

<!-- dddart-source: docs/quickstarts/configuration/expected/configuration.txt -->
```text
127.0.0.1
9090
false
[https://example.com]
```
<!-- /dddart-source -->

The YAML file sets the port to `8080`. The command supplies `9090` through the
first provider, so the second line changes. Run `dart run bin/configuration.dart`
without the environment override to see the YAML default.

## Optional: supply settings from memory

Implement a provider when settings come from another source. This one uses a
Dart map and works without a file.

Save as `bin/provider.dart`:

<!-- dddart-source: docs/quickstarts/configuration/bin/provider.dart -->
```dart
import 'package:dddart_config/dddart_config.dart';

class MapConfigProvider extends ConfigProvider {
  MapConfigProvider(Map<String, Object?> values)
      : _root = ConfigLookup.present(values);

  final ConfigLookup _root;

  @override
  ConfigLookup lookup(String path) => _root.at(path);

  @override
  Future<void> reload() async {}
}

void main() {
  final config = Configuration([
    MapConfigProvider({
      'booking': {
        'maximum_seats': 8,
        'supported_locales': ['en', 'es'],
      },
    }),
  ]);

  print(config.getRequiredInt('booking.maximum_seats')); // 8
  print(config.getRequiredList('booking.supported_locales')); // [en, es]
}
```
<!-- /dddart-source -->

Run these commands:

<!-- dddart-source: docs/quickstarts/configuration/guide_commands.sh -->
```sh
dart run bin/provider.dart
```
<!-- /dddart-source -->

Expected output from `bin/provider.dart`:

<!-- dddart-source: docs/quickstarts/configuration/expected/provider.txt -->
```text
8
[en, es]
```
<!-- /dddart-source -->

See the [configuration guide](../../../packages/dddart_config/README.md) for merging, validation, and reloads.
