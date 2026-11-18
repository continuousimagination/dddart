# dddart_rest

Native Shelf HTTP resources with typed identities, JSON serialization, optional
authentication and per-operation authorization.

[Public server/client quickstart](../../docs/quickstarts/rest/README.md) ·
[Complete example programs](example/README.md) · [Public API](lib/dddart_rest.dart)

Start with the public quickstart to serve a note on a loopback port and read it
without a token. Add a verifier when an operation needs to know who is calling.

## Optional access policies

Try the [public leaderboard](example/README.md) to make an anonymous read and
see a write rejected until a caller has permission. The example uses a local
verifier and closes its server after the requests.

No verifier or security policy means public CRUD. Installing an
`authenticationHandler` defaults the resource to `AccessPolicy.authenticated()`.
An explicit `defaultPolicy` replaces that default, and `operationPolicies`
replaces it for each selected `CrudOperation`: `read`, `query`, `create`, `update`,
`delete`. A public read override works without credentials on the same resource
whose writes require authentication. No duplicate registration or dummy identity
is needed.

- `AccessPolicy.public()` permits anonymous requests.
- `AccessPolicy.authenticated()` requires the configured verifier; this establishes
  identity, not application ownership or tenant permissions.
- `AccessPolicy.custom(handler, authentication: AuthenticationRequirement.optional)`
  always calls the handler, including with `AnonymousCaller<TClaims>`. Select
  `AuthenticationRequirement.required` when anonymous evaluation is inappropriate.

Required authentication without a verifier is rejected at construction. Optional
operations skip verification when credentials are missing. If a verifier is
installed, supplied invalid credentials return 401 even on public operations;
they never become anonymous after failure. The default detector checks for an
Authorization header, including an empty one. Set `credentialsPresent` for a
cookie or other credential transport. Without a verifier, public requests remain
anonymous and request claims are never trusted.

`AuthorizationHandler<T, I, TClaims>.authorize(context)` receives one of:

| Context | Policy input supplied by the framework |
| --- | --- |
| `ReadContext` | Current persisted aggregate |
| `QueryContext` | Typed caller and untrusted filter parameters |
| `CreateContext` | Final proposed aggregate after `preCreate` |
| `UpdateContext` | Separate current and proposed aggregate snapshots |
| `DeleteContext` | Current persisted aggregate |

Custom aggregate policies require an explicit `authorizationSnapshot` function
that deep-copies the complete domain state, including permission fields omitted
from public JSON. It must preserve identity and metadata, detach mutable values,
and omit transient pending events. Use a domain copy function or a complete
persistence codec, never a lossy public projection. The framework deliberately
has no response-serializer fallback: public serialization must not rewrite the
stored owner seen by policy. Query-only policies do not need aggregate snapshots.
Public and authentication-only resources need no snapshot configuration.

For example, the ownership sample supplies `authorizationSnapshot: snapshotDocument`
alongside its custom policy. Changing a policy context object cannot modify storage
or normalize the eventual proposal. Use `preCreate` for normalization. `Caller<TClaims>` is either `AnonymousCaller` (no claims) or
`VerifiedCaller` (successful verifier result). Claims can be absent if the
application's verifier intentionally returns none.

Return `AuthorizationResult.allow()` or `AuthorizationResult.deny()`.
An allowed custom collection decision must explicitly provide a `QueryScope`;
`UnrestrictedQueryScope()` deliberately exposes all rows selected by that handler.
The framework does not infer a tenant predicate. Denied/thrown collection policies
never invoke query code, including unfiltered and pagination-only requests.

Requests negotiate JSON first, then verify credentials, deserialize/validate
identities, apply `preCreate` for creation, load any current state required by policy,
evaluate access, and only then return protected data or perform mutations.
Missing/invalid required credentials return 401; verified or custom anonymous
denial returns 403. `AuthorizationResult.deny(conceal: true)` returns the same
generic 404 as a missing record. Policy/verifier exceptions return generic 500,
without their private exception text, body, ETag or query counts. Access failures
cannot be overridden through `customExceptionHandlers`.

See [the ownership example](example/authorization_example.dart) for an exhaustive
policy using stored ownership, explicit owner transfer, public objects and scoped
queries. Treat proposed ownership/tenant fields as untrusted unless server-owned
normalization has assigned them. Policies must check the stored state first.

### Read authorization and query scope

Item policy evaluates a detached view of persisted state before the HTTP response
encoder or ETag builder runs. The explicit domain snapshot function is independent
of public serialization; a denied read produces no aggregate response. A concealed denial
and a missing item share the generic 404 body.

Filtered, unfiltered and pagination-only reads all pass through the same selected
collection policy. Scope is application-owned: constrain both the datastore query
and its count with the verified tenant/owner, then apply request filters and
pagination. A request such as `?tenant=someone-else` must never replace that verified
scope. An empty page can still carry the authorized total count, but never a global
count. The ownership example applies its scope before filtering and pagination;
production repositories should perform the equivalent selection in their datastore.

### Mutation authorization and atomic persistence

Custom mutation policies require `ConditionalAggregateRepository<T, I>`. An
incapable repository returns 501 before mutation; it never falls back to a
read/check/ordinary save. Generated SQLite, MySQL, MongoDB and DynamoDB repositories
and `InMemoryConditionalRepository` provide this capability.

For an existing PUT or DELETE, the policy receives the persisted aggregate and
caller (plus the separate PUT proposal). Its decision is bound to that loaded
revision even when the client omits If-Match. If another writer changes ownership
before commit, the CAS rejects the operation: 409 for an implicit policy condition,
or 412 for a client-supplied condition. Reload and make a new authorization decision;
the framework never retries with old permission and a new token. Ownership and
tenant transfer are application policy, not framework-defined roles or immutable
fields. The example checks stored ownership and explicitly permits administrator
transfers while rejecting ordinary owner/tenant reassignment.

POST is create-only. It authorizes the final `preCreate` proposal and uses atomic
create-if-absent when available. An existing identity returns 409 (412 with explicit
`If-None-Match: *`); POST with If-Match is unsupported (501), so create permission
cannot overwrite a protected record. PUT of a missing identity additionally uses
the create policy and `preCreate`, preserving the route ID. It returns 201 when
created. PUT's selected authentication requirement still applies before this lookup;
creation cannot be used to evade a stricter create policy.

A missing ordinary DELETE returns 404; a matching-revision delete of a missing
record returns 412. Explicit assert-absence deletion can return 204 after atomic
absence confirmation. No aggregate-specific hook runs when there is no aggregate
to inspect. Denial, exceptions and conflicts cause no persistence/publication or
pending-event acknowledgment. Policy snapshots cannot normalize stored/proposed
state; use `preCreate` for server-owned creation fields.

Unconfigured public CRUD and deliberately anonymous custom policies remain
supported. Plain repositories retain public/authentication-only CRUD and reject
sequential POST overwrite, but they cannot guarantee isolation of competing
creations. Use the conditional capability for that guarantee or for custom mutation
policy. An authenticated-only policy verifies identity without making an ownership
decision; use a custom policy when permissions depend on stored state.


## Typed identity contracts

Use `AggregateRoot<UuidValue>` for UUID models and `Repository<User, UuidValue>`
for UUID CRUD. Native models extend `AggregateRoot<IssueId>`. Both base
constructors require an ID; domain constructors can call `UuidValue.generate()`.
Register explicit `IdentityCodec<IssueId>` implementations in an instance-local
`IdentityCodecRegistry`; configure the server's `JsonSerializer` and
`CrudResource<Issue, IssueId, void>` with the same registry. Generated REST
repositories accept `identityCodecs: registry` and share it with body serialization.

`CrudResource<T, I, TClaims>`, `AuthorizationHandler<T, I, TClaims>` and
`QueryHandler<T, I, TClaims>` retain concrete identity and claim types. Read and
delete policies receive persisted aggregates; update policies receive separate
current and proposed snapshots. Query handlers receive typed caller and scope.

Client paths URI-encode canonical codec keys once. `HttpServer` decodes one
segment once; direct `CrudResource.handleGetById/handleUpdate/handleDelete`
callers supply decoded canonical keys. Slash, percent, punctuation and Unicode
remain data. Empty, malformed UTF-8 and dot-only (`.`/`..`) keys are unsupported
and fail before client I/O. Invalid/noncanonical server keys yield problem+json
400; valid missing IDs keep 404. Client 400 and 422 map to repository constraint
errors. POST validates the final aggregate's key after `preCreate`, rejecting
unsupported identities with 400 before authorization or persistence. A get
response with a different typed identity is rejected.

## HTTP and query behavior

`CrudResource<T, I, TClaims>` uses a JsonSerializer and typed repository. Item
routes support GET, POST, PUT and DELETE as documented in the
[resource implementation](lib/src/crud_resource.dart). JSON is the supported
request/response media format. Canonical identity keys are URI-escaped as one
segment; they are not implicitly UUID strings.

`collectionHandler` serves unfiltered/pagination-only reads; without it those
requests return 400. `queryHandlers` selects a named application filter. Handlers
receive the authorized query scope and must apply it to both rows and total count
before paging. Client filters may narrow permissions, never widen them.
`defaultSkip`, `defaultTake` and `maxTake` bound the normalized page request.
The [main server](example/main.dart) and [query handlers](example/lib/handlers/query_handlers.dart)
provide complete implementations. Repository CRUD alone supplies no universal scan.

Custom exception handlers map application exceptions to responses;
[the example handlers](example/lib/handlers/exception_handlers.dart) show the
actual callback contract. Default errors use problem responses. Keep sensitive
payloads and internal diagnostics out of public errors.

## Conditional requests

Strong ETags represent coherent persisted revisions, not timestamps. Conditional
GET can return 304. Mutation preconditions execute through an atomic repository
capability; `requirePrecondition` can require them. An unsupported backend cannot
provide compare-and-swap by checking and then saving. Conflicts, unsupported
capability and uncertain storage outcomes remain distinct; a 412 contains no
private current body or revision. See [conditional writes](../../docs/CONDITIONAL_WRITES.md)
and the [two-writer HTTP example](example/etag_concurrency_example.dart).

## Authentication providers and endpoints

Use [self_hosted_auth_example.dart](example/self_hosted_auth_example.dart) for
complete claims, JwtAuthHandler and AuthEndpoints composition. The claims loader
is authoritative on initial issuance and refresh; return null for ineligible
users. JWT code generation supplies convenience helpers, not automatic wiring.
Explicit claims parser/serializer/lifecycle callbacks remain required.

Refresh tokens require an adapter implementing RefreshTokenRepository and its
lookup contract. Device codes require DeviceCodeRepository, including one atomic
`consumeApproved` transition matching client, state, user and expiration. Generated
CRUD alone does not implement these auth storage protocols. No verified MongoDB
authentication adapter is shipped. The in-memory implementations are examples,
not durable production storage.

AuthEndpoints supplies login, refresh, logout, device verification and token
redemption routes; consult [its declarations](lib/src/auth_endpoints.dart) for
request/response fields. Device grants are bound to client ID and consumed once.
A lost successful token response can require a new login rather than replay.

[oauth_auth_example.dart](example/oauth_auth_example.dart) demonstrates JWKS-based
OAuthJwtAuthHandler validation. Issuer, audience, expiration, not-before and clock
skew are explicit configuration. The external provider owns login; DDDart does not
provision it. [custom_routes_example.dart](example/custom_routes_example.dart)
shows application routes. Apply authentication deliberately to those handlers.

## Client platforms

Run the Shelf server on the Dart VM. For a native or browser client, see the
[client guide](../dddart_rest_client/README.md) for token providers and credential storage.
