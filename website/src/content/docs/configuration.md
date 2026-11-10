---
title: Compose application configuration
description: Layer environment variables over structured configuration, validate settings, and keep source details outside domain code.
section: Connect the pieces
order: 40
---

## Configure the application at its edges

`dddart_config` combines configuration sources behind `ConfigProvider`. Read and validate settings when wiring the application, then pass the values or dependencies your domain needs into constructors. A reservation should not need to know an environment-variable name or a YAML file path.

The supplied providers read environment variables and YAML files. These are native-runtime facilities: filesystem YAML and the process environment are appropriate for a server or other native Dart application, not a browser. The structural provider contract can also be implemented by an application-specific source.

Install `dddart_config` from the same repository revision as your other DDDart dependencies. See [Getting started](/dddart/docs/getting-started/).

## Layer environment variables over YAML

Create `config.yaml` in your application's working directory:

```yaml
server:
  host: 127.0.0.1
  port: 8080
logging:
  verbose: false
allowed_origins:
  - https://example.com
```

Save this complete program as `bin/configuration.dart`:

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

Run it from the directory containing `config.yaml`:

```bash
BOOKING_SERVER_PORT=9090 dart run bin/configuration.dart
```

The result uses port `9090` from the environment and keeps the YAML host and other settings. Earlier providers have higher precedence.

## Understand the merge rules

| Higher-priority value | Result |
| --- | --- |
| A map over another map | Merge recursively by key |
| A list | Replace the entire lower list or subtree |
| A scalar | Replace the lower subtree |
| Explicit null | Mask the lower value and its descendants |
| An absent key | Keep the lower value |

An empty map merges; it does not erase the lower map. An empty list replaces the lower list. A scalar or null in an intermediate provider forms a barrier: a later lookup cannot bypass it to recover a deeper value from a lower provider.

`Configuration` resolves the effective tree before looking up a dotted path, so `getMap('server')` and `getInt('server.port')` follow the same rules.

## Keep structure when reading values

Use `getRequiredList` or `getRequiredMap` for structured values. Lists preserve ordering; maps require string keys. Returned trees are copied and deeply immutable. `getString` accepts scalar values and rejects collections; it does not flatten a list into a string.

These APIs distinguish concepts that often get accidentally conflated:

- `lookup(path).isPresent` distinguishes absence from an explicit null.
- `contains(path)` is true for an explicit null.
- Optional typed getters return null for absence or explicit null.
- Required getters throw `MissingConfigException` for absence and `TypeConversionException` for explicit null or an incompatible value.
- Defaulted getters use the fallback for absence or explicit null; an invalid present value still fails conversion.

Dotted paths navigate maps, not list indexes. Read the list and inspect its elements when working with records. A literal dotted map key can be accessed from its containing map instead of through path lookup.

## Map environment names deliberately

Environment values remain strings. A single underscore in a variable name separates path segments; a double underscore represents a literal underscore. Names are converted to lowercase after removing the prefix.

| Environment variable | Configuration path |
| --- | --- |
| `BOOKING_SERVER_PORT` | `server.port` |
| `BOOKING_LOGGING_VERBOSE` | `logging.verbose` |
| `BOOKING_SLACK_BOT__TOKEN` | `slack.bot_token` |

Typed getters parse numeric and boolean strings. Boolean strings accept `true`, `1`, `yes`, and `on`, or their false counterparts, without case sensitivity. A comma-separated or JSON-looking environment string stays a string; `getList` does not parse it into a collection.

Conflicting names, such as setting both `BOOKING_SERVER` and `BOOKING_SERVER_PORT`, are rejected rather than silently choosing one. Prefer a prefix so the application reads a deliberate namespace.

## Supply a custom provider

A provider implements `lookup` and `reload`. The empty path must return its complete root map, or a missing result for an empty source. This enables consistent merging of parent and child paths.

This complete example supplies an in-memory configuration tree without filesystem or process-environment access:

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

A remote or embedded provider can use the same contract, but no cloud configuration provider is included automatically. Fetching, authentication, caching, and refresh policy belong to that implementation.

## Validate and reload explicitly

`validate()` collects missing, type-conversion, and custom-validation failures into a `ValidationException`. Optional requirements skip absent paths; an explicitly present null is still validated and fails a required typed read. Failure summaries identify keys without including configuration values or custom validator exception text.

Call `await config.reload()` to ask each provider to refresh. YAML reload rereads the file; environment reload rereads the process environment or the map supplied to that provider. This is explicit refresh, not a background file watcher. Providers reload in order; the combined operation is not an atomic transaction across sources. Values already passed into running services do not change automatically—reconfigure those services deliberately if necessary.

## Implementation references

- [Configuration lookup, precedence, and typed getters](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_config/lib/src/configuration.dart)
- [Environment name conversion](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_config/lib/src/environment_config_provider.dart)
- [Provider extension contract](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_config/lib/src/config_provider.dart)
- [Structured configuration tests](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_config/test/structured_configuration_test.dart)
