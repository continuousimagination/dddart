# dddart_events_dynamodb

Durable server-side aggregate event history and random channel mappings for
short-lived or concurrent serverless invocations. Clients need neither this
package nor their own event database. See the
[distributed events guide](../../docs/DISTRIBUTED_EVENTS.md).

```dart
final history = DynamoAggregateEventRepository(
  client: connection.client,
  tableName: eventTableName,
  identityCodecs: identities,
);
final channels = DynamoEventChannelRepository(
  client: connection.client,
  tableName: eventTableName,
  identityCodecs: identities,
);
```

`connection` is the existing `DynamoConnection` from
`dddart_repository_dynamodb`. Injected SDK clients are also supported. Constructors
do not create resources. The AppSync package's CloudFormation template creates
the matching `pk`/`sk` table and `expiresAt` TTL, or accepts an existing table.

An append transaction commits the history record, UUID lookup and ingestion head
together. Retries with equivalent retained content return the original position;
conflicting UUID reuse fails. Queries are partitioned by a SHA-256 logical-key
digest and compare the stored full logical key to reject collisions. Scoped IDs
are preserved without truncation. A query ending at DynamoDB's byte limit resumes
from the last returned position rather than jumping to the head.

Retention defaults to seven days. Reads enforce expiration even when physical TTL
cleanup lags; heads/current-channel mappings do not expire. Explicit deletion
preserves a recovery floor. `deleteOlderThan` is an administrative maintenance
scan; normal polling/resolve/append never scan the table. Trigger deduplication
for rotation has a configurable seven-day retention; a much later replay can
cause another safe random rotation.

Run from the workspace root:

```bash
dart pub get
cd packages/dddart_events_dynamodb
dart test --exclude-tags=requires-dynamodb
# With DynamoDB Local at localhost:8000:
dart test --tags=requires-dynamodb
dart run example/history.dart
```

Tests use unique tables and delete only their own resources. Set
`DYNAMODB_ENDPOINT` for an alternative local endpoint. The finite example creates
and removes an isolated table on `DynamoConnection.local()`. Production resource
creation belongs to the application's deployment process.
