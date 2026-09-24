import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('CloudFormation IDs are valid and table names remain exact', () {
    const cases = {
      'order-events.v1': 'OrderEventsV1Table',
      'orders__archive': 'OrdersArchiveTable',
      '_orders': 'OrdersTable',
      '123-orders': 'Dynamo123OrdersTable',
      '---': 'DynamoTable',
    };

    for (final entry in cases.entries) {
      final first = TestUserDynamoRepository.getCloudFormationTemplate(
        entry.key,
      );
      final second = TestUserDynamoRepository.getCloudFormationTemplate(
        entry.key,
      );
      final resourceId = first.split('\n')[1].trim().replaceFirst(':', '');

      expect(resourceId, entry.value);
      expect(resourceId, matches(RegExp(r'^[A-Za-z][A-Za-z0-9]*$')));
      expect(first, contains('TableName: ${entry.key}'));
      expect(second, first, reason: 'logical IDs must be stable');
    }
  });
}
