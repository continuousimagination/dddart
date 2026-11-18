# dddart_events_dynamodb

Durable history and channel mapping for DDDart event servers. Use this package
when multiple processes or short-lived handlers need to read the same streams;
clients do not connect to this store directly.

Inject `DynamoAggregateEventRepository` and `DynamoEventChannelRepository` with a
client from `DynamoConnection`, the table name, and the shared identity
registry. Constructors do not provision resources. Follow the
[history example](example/README.md) to run the complete table, append, read,
and cleanup flow with DynamoDB Local.

## Table schema

The table uses string `pk`/`sk` keys and numeric `expiresAt` TTL. No index is required:

| Partition / sort key | Content |
| --- | --- |
| `s#<sha256(logical)>` / `head` | Durable committed head, full logical key and recovery floor |
| Same stream partition / `p#<20-digit-position>` | Envelope, digest, ingestion time/position, TTL |
| `e#<identity-tuple>` / `id` | Retained occurrence identity lookup and canonical content digest |
| `m#s#<sha256(logical)>` / `state` | Durable current channel mapping |
| `c#<channel-uuid>` / `current` | Reverse current-channel lookup |
| `r#<identity-tuple>` / `rotation` | Idempotent previous/current rotation result and TTL |

Append atomically updates the head and writes both record/identity lookup with
conditional transactions. Uncertain successful requests can be retried safely;
conflicting occurrence content is rejected. Reads use consistent aggregate-partition
queries and preserve progress at DynamoDB byte/page boundaries. The stored full
logical key detects digest collisions. Normal reads/appends/resolution do not
scan the table. Explicit `deleteOlderThan` is an administrative maintenance scan;
deletion advances a durable recovery floor.

Event and rotation keys encode a JSON tuple of the registered identity kind and
canonical codec key. Source scope and case remain significant; UUIDs and custom
IDs with the same text do not collide. Keys exceeding the DynamoDB partition-key
byte limit are rejected before IO. Supply the same identity registry to history,
channel repositories, event serializers and transports. See the
[event identity migration](../../docs/DISTRIBUTED_EVENTS.md#event-identity-migration)
for the breaking envelope and lookup-key changes.

## Retention and recovery

Payload history and rotation deduplication have configurable retention. Readers
honor expiration even if DynamoDB has not yet physically deleted a TTL record.
Stream heads and current channel mappings do not expire. Cleanup advances the
recovery floor; a client missing required history must reload the aggregate.
A rotation trigger replayed after its retention window may rotate the channel
again. See [watch recovery](../../docs/DISTRIBUTED_EVENTS.md#watch-and-resume).

The [AppSync deployment guide](../dddart_events_appsync/DEPLOY.md) shows a
CloudFormation template that creates a matching table or uses an existing one.
