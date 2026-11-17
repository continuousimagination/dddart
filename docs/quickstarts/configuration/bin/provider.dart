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
