import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_events_dynamodb/dddart_events_dynamodb.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

/// Explicit local-only table lifecycle; repository constructors never provision.
Future<void> main() async {
  final connection = DynamoConnection.local();
  final table =
      'dddart_example_${UuidValue.generate().uuid.replaceAll('-', '')}';
  await connection.client.createTable(
    tableName: table,
    billingMode: BillingMode.payPerRequest,
    attributeDefinitions: [
      AttributeDefinition(
          attributeName: 'pk', attributeType: ScalarAttributeType.s),
      AttributeDefinition(
          attributeName: 'sk', attributeType: ScalarAttributeType.s)
    ],
    keySchema: [
      KeySchemaElement(attributeName: 'pk', keyType: KeyType.hash),
      KeySchemaElement(attributeName: 'sk', keyType: KeyType.range)
    ],
  );
  try {
    final history = DynamoAggregateEventRepository(
        client: connection.client, tableName: table);
    final channels = DynamoEventChannelRepository(
        client: connection.client, tableName: table);
    final reference =
        AggregateReference(kind: 'game', id: UuidValue.generate());
    final head = await history.head(reference);
    final envelope = EventEnvelope(
        aggregate: reference,
        event: StoredEvent<Identity>(
            id: UuidValue.generate(),
            createdAt: DateTime.now().toUtc(),
            aggregateId: reference.id,
            eventType: 'example.changed.v1',
            eventJson: '{}'));
    await history.append(envelope);
    final recovered = await history.read(reference, after: head);
    if (recovered.events.single.envelope.id != envelope.id) {
      throw StateError('Recovery failed');
    }
    final before = await channels.resolve(reference);
    final rotation = await channels.rotate(reference, envelope.id);
    if (before.id == rotation.current.id) throw StateError('Rotation failed');
    print(
        'Durable history and random channel rotation passed on DynamoDB Local.');
  } finally {
    await connection.client.deleteTable(tableName: table);
    connection.dispose();
  }
}
