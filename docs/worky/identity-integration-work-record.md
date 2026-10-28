# Identity/configuration integration work record

Tracking: #37 and #38. Integration target: feat/worky-changes.
Main remains c538680619a11af79e7094c3087646189c313978.

## Implemented children

| Issue | Boundary | Merged PR | Focused/package evidence |
| --- | --- | --- | --- |
| #38 | Structured configuration | #46 | 154 tests, example/archive/Git consumers |
| #39 | Typed core/UUID convenience/events | #47 | 210 tests, negative type checks, Git consumer |
| #40 | Codecs and JSON generation | #48 | 22 serialization and 112 initial JSON tests, clean generation |
| #41 | MongoDB and DynamoDB | #49 | 82 and 113 service-backed tests, example/archive/Git consumers |
| #42 | SQL, SQLite and MySQL | #50 | 85, 94 and 191 tests, schema/collation/rollback and consumers |
| #43 | REST server/repositories/client | #51 | 308, 110 and 88 tests, URI/auth/consumer checks |
| #44 | Stored/distributed events | #52 | 88 event and 114 final JSON tests, generated/cursor/transport cases |

Individual work records hold commands, contracts, generated ownership and limits.
The accepted API document is identity-api.md. Local tests are required because
GitHub Actions is disabled. No independent review or release is claimed here.

## Immutable integration consumer

Revision: 81313391f7f8348ec5c4d4f17d594b72419581a7, pushed on the final child branch.
The integration parent contains that exact library source; following child
commits change only tests/documentation. Confirm with a diff of packages/*/lib.

The standalone /private/tmp/dddart-worky-integrated-consumer-8131339 resolves all
13 relevant dddart packages via Git at that SHA, with documented Git overrides.
Its fresh combined part includes JSON, SQLite/MySQL/MongoDB/DynamoDB/REST
repositories and event registrations; generation, fatal analysis and execution
pass. It exercises structured presence/null/list and three-provider masking,
native/scoped IDs with case/punctuation/Unicode, CRUD/update/delete isolation and
nullable references in all four database adapters, REST backed by real SQLite,
and tagged native/scoped/UUID event ingestion/reconstruction. No synthetic UUID
mapping or implemented Worky application is assumed.

MySQL and Mongo use isolated probe databases. Dynamo probe tables and the Mongo
probe database are cleaned after success. Provisioned services are the task-owned
MongoDB, DynamoDB Local and MySQL containers; existing stopped containers/data
are untouched. Final service gates use the repository's documented test fixtures.

## Final gates

Validator self-analysis, formatting, self-tests and inventory check pass. The
inventory covers 15 public packages and 13 examples, with 22 root workspace
members and no unaccounted exemptions. Full package/archive/example integration
and final provisioned-service lanes are in progress; this record will be updated
with actual results before the parent merges to the feature branch.

Evidence logs and scripts: /private/tmp/dddart-worky-implementation-20261028.
Optional real AWS/OIDC and the explicitly excluded legacy event/server examples
remain unrun. Main merge and publication are not authorized in this task.
