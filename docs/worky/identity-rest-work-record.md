# REST identity work record — issue #43

Branch: issue/identity-rest. Target: issue/37-extensible-identity.
Baseline e4df263 includes validated core, serialization and database adapters.
One owner controls all REST package/example generation and combined parts.

## Frozen contract

CrudResource<T, I, TClaims> and AuthorizationHandler<T, I, TClaims> constrain T
against AggregateRoot<I>; repository CRUD and delete authorization retain I.
QueryHandler<T, I> keeps the existing in-process callback/pagination behavior with
Repository<T, I>. Read-only QueryResult/ETag/response builders need only T.
Stock auth infrastructure keeps UUID record IDs through UuidAggregateRoot and
typed UUID repository contracts; token semantics and concurrency are unchanged.

Both server and generated client accept an optional named identityCodecs
registry. Configure the JsonSerializer with the same registrations; no dependency
on a concrete serializer is introduced in CrudResource. Generated repositories
share their registry with their generated serializer. UUID registration is stock.
Resource construction rejects missing identity registration.

The canonical codec key occupies exactly one URI segment: the client URI-encodes
once; HttpServer decodes shelf_router's encoded segment once; direct CrudResource
callers supply a decoded canonical key. Codec validation follows routing. Invalid
or noncanonical incoming keys produce 400 Problem Details, valid absent IDs keep
404, missing server codec configuration fails construction. Client 400/422 errors
map to RepositoryException.constraint; other existing status/transport mapping is
preserved. Generated getById rejects a response with a different typed ID.

REST keys must be nonempty lossless UTF-8 and cannot be dot-only path segments
("." or ".."); those cannot survive general URI path normalization. Reject before
client I/O. Slashes, percent signs, query/fragment punctuation, whitespace and
Unicode remain identity data. Native and scoped codecs explicitly define their
canonical keys; arbitrary toString is never used as a wire key.

## Generation and completion gate

Generate dddart_rest (JWT claims and JSON owning parts) before repository_rest
(JSON plus rest_repository), then the owning examples. Verify parts compile.
Focused direct-resource tests and injected-http.Client generated-repository tests
prove typed keys/errors independently before the in-process routed round trip.
Clean custom-interface generation and wrong-ID compile checks, UUID/auth
regressions, all affected package/example/archive-consumer lanes and an immutable
Git consumer complete this child. Final integration/review remain on #37.

## Completion evidence

- All 308 REST server tests pass, including three focused native identity cases
  covering decoded lookup/update/delete, typed authorization, malformed keys,
  missing codec configuration, valid absent IDs and exactly-once routing.
- All 110 REST repository tests pass. Injected-client cases prove canonical URI
  encoding, body/key registry agreement, local failures before transport, 400
  constraint mapping, response-ID verification, custom named methods and routed
  native/scoped/UUID CRUD. A fresh isolated generated custom-interface consumer
  compiles/runs; analyzer-negative cases reject unrelated ID lookup/deletion.
- Both package lanes pass required generation, fatal analysis, formatting, tests
  and zero-warning publication dry runs. A stale failed repository builder cache
  was removed with build_runner clean; the complete clean gate passed.
- All three REST archive-consumer lanes pass with only their declared dependency
  closures. Stock device/refresh-token generated runtime parts are included in
  Git/archives alongside standard_claims.g.dart; they are generated, not edited.
- The REST server, repository and shared-client example lanes pass. Server and
  authenticated-client entrypoints are compile-only under the existing policy;
  no user OAuth/OIDC credentials or live external auth service were exercised.
- A separate outside-workspace consumer resolves six packages at immutable
  revision 1987b67cd515b056a389b88c728d4d5101dd7336. Documented Git overrides keep
  shared core/serialization/JSON/client dependencies at that revision. Fresh
  combined JSON/REST generation and fatal analysis pass. The public registered
  server plus generated client prove native/scoped/UUID CRUD and scoped/case
  collision isolation without sockets. Stock auth JSON and claims compile/run.

Commands: `dart run tool/validation/validate.dart package NAME --mode=local`,
`consumer NAME --mode=local` and `example NAME --mode=local` for the corresponding
REST packages/examples. Logs are under
/private/tmp/dddart-worky-implementation-20261028. The immutable fixture is
/private/tmp/dddart-worky-rest-consumer-1987b67.
