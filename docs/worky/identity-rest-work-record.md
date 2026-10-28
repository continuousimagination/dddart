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
