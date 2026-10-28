# Document identity work record — issue #41

Branch: issue/identity-document-backends. Target: issue/37-extensible-identity.
Prerequisites #39/#40 merged through 0f31995. No implementation workers share
this checkout or its build caches.

## Frozen adapter contract

Generated repositories implement Repository<Aggregate, ConcreteIdentity>, or the
declared custom repository interface. Constructors accept an optional named
identityCodecs registry and share it with the generated JSON serializer.
Repository generation resolves the instantiated AggregateRoot<I> ancestor and
rejects erased/open roots. Custom methods retain generic/positional/named/default
parameters; generated bases remain abstract when custom behavior is required.

All operations obtain a lossless canonical codec key before database I/O.
MongoDB stores UTF-8 bytes as binary _id, independent of collection collation,
and retains the serializer's structural id field. fromDocument removes only the
physical key and is available for explicit custom query implementations. This
changes the physical schema from the previous string _id; existing collections
require explicit migration/recreation, including UUID consumers.

DynamoDB retains a string partition key named id. It accepts only 1–2048 lossless
UTF-8 bytes and restores structural identity through fromKey/toJson before JSON
deserialization. fromItem provides that conversion for custom reads. No implicit
scan/enumeration or UUID translation table is introduced. Complete item/document
limits and other database constraints remain enforced by the service.

Constraint sources: [DynamoDB limits](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Constraints.html),
[DynamoDB string comparison](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html),
[MongoDB identity rules](https://www.mongodb.com/docs/manual/core/document/).
The BSON size ceiling is documented in
[MongoDB limits](https://www.mongodb.com/docs/manual/reference/limits/).

## Generation and services

One owner generates MongoDB, DynamoDB and their examples sequentially. Builders:
dddart_json:json_serializable plus dddart_repository_mongodb:mongo_repository or
dddart_repository_dynamodb:dynamo_repository. Their cache contributions combine
into existing declared .g.dart parts; the identity models reuse test_models.dart.
Verify output presence and analyze/compile each owning library. No manual output
edits. Standalone document examples resolve from their own directories.

Dedicated containers dddart-worky-mongo-20261028 and
dddart-worky-dynamo-20261028 were created from cached images on unused loopback
ports 27017/8000. Existing stopped containers and their data were untouched.
Tests use only these disposable services. Record behavior/gates below once run.

## Focused evidence

MongoDB: four focused key/service tests pass. Native IDs retain case, trailing
spaces and unsafe/Unicode characters under a case-insensitive collection
collation; scoped local numbers coexist and custom typed reads round-trip.
Malformed Unicode is rejected for save/get/delete with no open connection.

DynamoDB: four focused key/service tests pass. Native/scoped IDs survive real
CRUD and custom reads; empty/oversized/malformed UTF-8 keys fail before I/O.
Native UTF-8 byte boundaries and malformed/noncanonical item keys are tested.

Initial full runs passed all existing service behavior but exposed a stale
generator-text expectation and generated Mongo error-message nullability warnings
in the new clean consumer. These are corrected; final full/gate results follow.
