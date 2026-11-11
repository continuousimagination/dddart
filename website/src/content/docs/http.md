---
title: HTTP without a second domain model
description: Expose a repository through a JSON API, then use the same repository contract from a Dart or Flutter client.
section: Connect the pieces
order: 20
---

A database repository and an HTTP repository can serve the same application interface. The server owns database access and authorization. The client works with the same domain types, identities, serializers, and repository methods.

The two sides have different jobs:

| Server | Client |
| --- | --- |
| `dddart_rest` exposes a `Repository<T, I>` through Shelf handlers. | `dddart_repository_rest` generates a `Repository<T, I>` that calls those handlers. |
| A `JsonSerializer<T>` encodes the public representation. | The same serializer reconstructs the domain object. |
| Authentication verifies credentials; application policy decides access. | `AuthProvider` supplies a current token to `RestClient`. |

Start with [installation](/dddart/docs/getting-started/), [serialization](/dddart/docs/serialization/), and [repository contracts](/dddart/docs/repositories/). Add the REST packages from the same Git revision; these examples do not assume a published pub.dev release.

## Expose a repository

This complete helper turns an existing repository and serializer into a server. Your application supplies the concrete domain type and identity registry.

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

HttpServer createApi<T extends AggregateRoot<I>, I extends Identity>({
  required Repository<T, I> repository,
  required JsonSerializer<T> serializer,
  required IdentityCodecRegistry identities,
  required String resourcePath,
}) {
  final server = HttpServer(port: 8080);
  server.registerResource(CrudResource<T, I, void>(
    path: resourcePath,
    repository: repository,
    serializer: serializer,
    identityCodecs: identities,
  ));
  return server;
}
```

For an application-defined `Order` and its generated serializer, composition looks like this:

```dart
final identities = IdentityCodecRegistry(); // UUID is registered by default.
final server = createApi<Order, UuidValue>(
  repository: orders,
  serializer: OrderJsonSerializer.withIdentityCodecs(identities),
  identities: identities,
  resourcePath: '/orders',
);
await server.start();
// During application shutdown:
await server.stop();
```

`orders` is your chosen `Repository<Order, UuidValue>`. The unauthenticated helper is useful for a local example. Add authentication and application policy before exposing protected data.

The resource registers `GET /orders/:id`, `POST /orders`, `PUT /orders/:id`, and `DELETE /orders/:id`. A collection route also exists, but it needs an explicit query handler; the repository contract has no implicit “load everything” method.

Call `server.buildHandler()` instead of `start()` when a managed runtime already owns the HTTP listener. It returns the same Shelf handler without opening a port.

## Make collection reads explicit

Define queries in the language of your application. For example, an order repository could offer `findOpenOrders(customerId, skip:, take:)`. Register a corresponding `queryHandlers['customerId']` callback on the resource. The handler receives the repository, filter values, normalized pagination, and the authentication result.

For `GET /orders` without a filter, provide `collectionHandler`. That callback owns selection, access filtering, ordering, pagination, and any total count. Return `QueryResult(items, totalCount: count)`; the response body is a JSON array and an optional total is sent in `X-Total-Count`.

The current resource accepts one named filter at a time, plus `skip` and `take`. Unsupported filters, combined filters, or an unfiltered request without a `collectionHandler` return a client error. Defaults are `skip: 0`, `take: 50`, and a maximum of 100. Pagination does not automatically make an unbounded database query efficient: apply it in the datastore query.

## Generate the matching client repository

Add a REST annotation to an aggregate that already has JSON serialization:

```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'order.g.dart';

@Serializable()
@GenerateRestRepository(resourcePath: '/orders')
class Order extends UuidAggregateRoot {
  Order({
    required this.customer,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String customer;
}
```

With the JSON and REST builders installed, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then use the generated implementation through the shared interface:

```dart
final connection = RestConnection(baseUrl: 'https://api.example.com');
final Repository<Order, UuidValue> orders = OrderRestRepository(connection);

final order = Order(customer: 'Acme');
await orders.save(order);
final loaded = await orders.getById(order.id);
await orders.deleteById(loaded.id);

connection.dispose();
```

Use a base URL without a trailing slash. The generated `save` sends a PUT to the aggregate's identity URL, including for an initially new object; it relies on the server repository's save/upsert behavior. It does not automatically perform a POST or attach an `If-Match` header. The [REST repository implementation and examples](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_repository_rest) show custom query interfaces and generated base classes.

## Share identity codecs, not guessed URL formats

For a custom identity, register its codec and pass the same registry to the server resource, JSON serializer, and generated client repository. The REST adapter converts the canonical identity key into one encoded URL segment. It decodes that segment once on the server.

Do not manually split composite identities on slashes or replace characters with a lossy “URL-safe” approximation. Empty keys and the dot-only keys `.` and `..` are unsupported by this adapter. A response whose typed identity does not match the requested identity is rejected.

## Authentication and authorization are separate

`AuthenticationHandler<TClaims>` verifies an HTTP request. `CredentialVerifier<TClaims>` verifies a token without depending on HTTP, so native handlers can reuse the same verifier.

For an existing OIDC provider, configure `OAuthJwtAuthHandler` with the provider's JWKS URL, expected issuer, expected audience, and a typed claims parser. For built-in token issuance, `JwtAuthHandler` adds refresh-token and claims-loading behavior. Keep issuer and audience configuration explicit for the deployment you are connecting to.

The current `AuthorizationHandler<T, I, TClaims>` provides create, update, delete, and filtered-query hooks. An update hook receives the submitted aggregate; fetch authoritative ownership or membership when a decision depends on stored state. There is no built-in per-object read hook for `GET /orders/:id`, and unfiltered collection requests do not invoke the filtered-query authorization hook. Enforce those read policies in an application-owned handler or repository boundary, and in the `collectionHandler` that selects visible items.

On the client, inject your application's `AuthProvider`:

```dart
final connection = RestConnection(
  baseUrl: 'https://api.example.com',
  authProvider: authProvider,
);
```

`RestClient` requests `getIdToken()` before sending. A non-OIDC provider should return its appropriate JWT from that method. A token callback is also the bridge used by the [event transport](/dddart/docs/events/).

## Browser and mobile composition

The REST connection and client can compile for the browser. Their HTTP layer uses `package:http`; application services need not know whether they are running in a browser or in native Dart.

Authentication's surrounding platform work still belongs to the application:

- Native device-flow credentials use a filesystem path in `DeviceFlowAuthProvider`.
- `LocalhostCallbackStrategy` opens a local server and browser; it is a desktop or CLI strategy.
- `ManualCallbackStrategy` reads standard input. Despite an older source comment mentioning web use, it is not a browser UI.
- `CognitoAuthProvider` accepts `OAuthCredentialStore`, `OAuthLoginStore`, and `OAuthCallbackStrategy`. Supply browser or mobile implementations instead of selecting filesystem and localhost defaults. Navigation-based login uses `beginLogin()` before redirect and `completeLogin()` after the callback.

The stores decide what may persist on the platform. Login transactions contain private PKCE/state/nonce data; the implementation consumes them once. No browser storage implementation or mobile deep-link widget is bundled. The domain model and token contract are shared; navigation and storage remain platform adapters.

For browser requests, configure the server's allowed origins before starting it:

```dart
server.allowOrigins(['https://app.example.com']);
```

The built-in CORS helper covers ordinary JSON and authorization headers. If the browser client uses `If-Match` or reads `ETag` / `X-Total-Count`, add application middleware for the additional allow/expose headers.

## Understand the HTTP guarantees

Success bodies use JSON. Errors use `application/problem+json`. PUT requires the route identity to match the submitted aggregate identity. `If-Match` can detect a changed ETag and return 412, but the comparison and save are separate operations. It is a best-effort stale-update check, not an atomic conditional write; stronger concurrency guarantees belong in the repository or application transaction.

Aggregate JSON carries public state. It does not carry the local pending-event queue. Attach an explicit publisher to an event-enabled repository when you want saves to publish [domain events](/dddart/docs/events/).

See the [server implementation](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_rest/lib/src/crud_resource.dart), [client implementation](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_rest_client/lib/src/rest_client.dart), and [runnable REST examples](https://github.com/continuousimagination/dddart/tree/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_rest/example).
