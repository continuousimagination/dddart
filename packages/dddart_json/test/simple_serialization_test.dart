import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('simple serialization test', () {
    const address = TestAddress(
      street: 'Test Street',
      city: 'Test City',
      zipCode: '12345',
    );

    // Test toJson using serializer
    final serializer = TestAddressJsonSerializer();
    final json = serializer.toJson(address);
    expect(json['street'], equals('Test Street'));
    expect(json['city'], equals('Test City'));
    expect(json['zipCode'], equals('12345'));

    print('Generated JSON: $json');

    // Test fromJson using serializer
    final deserialized = serializer.fromJson(json);
    expect(deserialized.street, equals('Test Street'));
    expect(deserialized.city, equals('Test City'));
    expect(deserialized.zipCode, equals('12345'));

    print('Deserialization successful!');
  });
}
