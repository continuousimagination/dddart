# dddart_repository_rest

Generated HTTP repositories sharing the typed DDDart aggregate contract.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Get started

Run the [HTTP quickstart](../../docs/quickstarts/rest/README.md) for a complete application.

## Model and connection

Annotate a complete aggregate with `@Serializable()` and
`@GenerateRestRepository(resourcePath: ...)`, and declare its owning generated
part. The quickstart supplies all imports, builders and setup. IDs use explicit
JSON/key codecs, and the transport URI-escapes canonical keys as one path segment.

[RestConnection](lib/src/connection/rest_connection.dart) accepts a base URL and
optional auth provider/client. Public endpoints work without authentication.
Share the connection across repositories and dispose its resources when finished.
The [REST client guide](../dddart_rest_client/README.md) documents provider and
credential-storage behavior.

## Reads and updates

Generated CRUD maps domain models through generated JSON. Collection reads are
application methods, not an implicit getAll contract. Use a custom repository
interface and handwritten subclass for query parameters, result bounds and
continuation rules. The [custom sample](example/custom_repository_example.dart)
contains the complete owning-library layout.

Versioned reads and conditional operations use strong server ETags and HTTP
preconditions. The server must implement the matching atomic capability;
generation cannot create concurrency guarantees in a plain CRUD backend.
A conflict requires an explicit reload/recompute decision. Do not retry with a
new revision automatically. [Conditional writes](../../docs/CONDITIONAL_WRITES.md)
records unsupported and uncertain outcomes.

Error translation maps HTTP failures to repository exceptions. Authentication is
optional and separate from storage preconditions. Browser use also requires
application CORS, callback and credential-storage choices; native auth providers
do not become browser-compatible by being used through an HTTP repository.

For custom query routes and a client with credentials, see the [package examples](example/README.md).
