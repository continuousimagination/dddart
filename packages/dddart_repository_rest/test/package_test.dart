import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:test/test.dart';

void main() {
  group('Package', () {
    test('can be imported', () {
      // This test verifies that the package can be imported successfully
      // and that the main exports are available
      expect(GenerateRestRepository, isNotNull);
      expect(RestConnection, isNotNull);
    });
  });
}
