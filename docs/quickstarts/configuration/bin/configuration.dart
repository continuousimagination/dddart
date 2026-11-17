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
