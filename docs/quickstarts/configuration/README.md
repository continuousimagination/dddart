# Layered configuration

Create an empty application directory outside the repository
and copy the following named files. The manifest pins Git dependencies to the
same revision as the primary quickstarts.

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.
It declares the SDK requirement and all dependency constraints.

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

Run these commands:

<!-- dddart-source: docs/quickstarts/configuration/commands.sh -->
```sh
dart pub get
dart analyze --fatal-infos
BOOKING_SERVER_PORT=9090 dart run bin/configuration.dart
```
<!-- /dddart-source -->

Run these commands:

<!-- dddart-source: docs/quickstarts/configuration/guide_commands.sh -->
```sh
dart run bin/provider.dart
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

Expected output from `bin/provider.dart`:

<!-- dddart-source: docs/quickstarts/configuration/expected/provider.txt -->
```text
8
[en, es]
```
<!-- /dddart-source -->

Remove the temporary application directory when finished. See the
[documentation gate](../../../tool/documentation/README.md) for isolation, CI,
service boundaries and the separate hosted release checks.
