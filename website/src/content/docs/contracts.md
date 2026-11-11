---
title: One domain, several applications
description: Arrange models, repositories, serializers, and events so that portable application code survives a change of platform or infrastructure.
section: Build your domain
order: 30
---

## Put the dependency in the constructor

An application service should say what it needs. It should not create a database connection every time it performs a domain action.

The following complete program takes a repository through its constructor. The action has no database, HTTP, Flutter, filesystem, or browser dependency:

```dart
import 'package:dddart/dddart.dart';

class Reservation extends UuidAggregateRoot {
  Reservation({required this.guest});
  final String guest;
  bool _confirmed = false;
  bool get confirmed => _confirmed;

  void confirm() {
    if (_confirmed) throw StateError('Already confirmed');
    _confirmed = true;
    touch();
  }
}

class ConfirmReservation {
  ConfirmReservation(this.reservations);
  final Repository<Reservation, UuidValue> reservations;

  Future<void> call(UuidValue id) async {
    final reservation = await reservations.getById(id);
    reservation.confirm();
    await reservations.save(reservation);
  }
}

Future<void> main() async {
  final repository = InMemoryRepository<Reservation, UuidValue>();
  final reservation = Reservation(guest: 'Sam');
  await repository.save(reservation);

  final confirm = ConfirmReservation(repository);
  await confirm(reservation.id);

  print((await repository.getById(reservation.id)).confirmed); // true
}
```

This example can run with only the core package. Replacing the repository with another implementation preserves the application's dependency contract. The concrete model and adapter must still support the chosen persistence/serialization mapping; the sample's private boolean is not offered as a generated-serialization model.

The server must also validate authorization and enforce domain rules against authoritative state. A remote CRUD save is a representation update, not automatically a server-side invocation of every domain method the client called. Expose an application command when the operation needs a server-owned workflow or transaction.

## Keep contracts small and truthful

`Repository<T, I>` promises three operations:

```dart
Future<T> getById(I id);
Future<void> save(T aggregate);
Future<void> deleteById(I id);
```

`T` is an aggregate root and `I` is its concrete identity type. A repository for `IssueId` does not silently accept an unrelated `CustomerId`. `save` is an upsert, while missing lookup and deletion are errors represented by `RepositoryException`.

Queries belong in an explicit application interface. A `findReservationsForGuest` method says something meaningful about the domain. A base interface with `getAll()` would encourage every implementation to pretend that an unbounded scan is equally appropriate.

The interface does not promise identical transaction isolation, latency, persistence lifetime, collection mappings, or concurrency behavior. Those are documented implementation capabilities. Use a fake to test application behavior; use adapter integration tests to prove the database or HTTP boundary.

## Organize the shared source

One practical structure is:

```text
shared_domain/
  models/          # Entities, values, identities, domain events
  contracts/       # Application-specific repository interfaces
  use_cases/       # Behavior expressed against those contracts
  serialization/   # Supported JSON mappings and identity codecs
server/
  repositories/    # Database adapters and query implementations
  api/             # HTTP routes, verified claims, access policy
  main.dart        # Creates connections and wires the application
web_or_mobile/
  repositories/    # Remote repositories or supported native storage
  authentication/  # Platform storage, login UI, redirects/deep links
  presentation/    # Widgets and platform lifecycle
```

This is an example organization, not a required folder convention. A small application can use the same boundaries inside one package.

Generated repository implementations are emitted into the annotated aggregate's Dart library. A model that imports the SQLite or MySQL adapter for generation also inherits that library's dependencies. Keep native-only generated models in the native/server portion of the application. For a completely portable shared domain, implement or delegate its repository interface in a separate adapter library, and perform any persistence representation mapping there. Do not assume that stacking every backend annotation on a single shared class yields one browser-safe library.

Generated JSON and REST mappings can be useful in a shared client/server library when its imports and chosen authentication implementation support both runtimes. Check the actual composition you ship.

## Share event meaning, choose delivery separately

A domain event describes a fact. A publication contract describes acceptance. A transport describes delivery. Keeping those separate lets the application reuse the fact without depending on a channel protocol.

| Contract | Responsibility |
| --- | --- |
| `DomainEvent<I>` | The typed aggregate reference, occurrence ID, timestamp, and event data |
| `EventBus` | Local typed delivery; originates with `publish`, receives with `deliver` |
| `EventPublisher` | Asynchronous acceptance of an occurrence |
| `EventRegistry` | Stable wire names and explicit serialization/reconstruction |
| `AggregateEventClient` | Logical watches, checkpoints, synchronization, and lifecycle |
| `AggregateEventTransport` | HTTP control/history and optional live delivery |

A Flutter view and a web view can both watch an `AggregateReference(kind: 'reservation', id: reservationId)`. Each app still owns its UI subscriptions, pause/resume hooks, token storage, and recovery decisions. A server validates membership from authoritative state before allowing subscription or publication.

When a local save publishes an event, capture the pending batch before the first asynchronous persistence step. Acknowledge accepted occurrences, leaving later or failed events pending. The provided helpers implement that ordering, but they do not create an atomic transaction between the aggregate database and the event store. See the [event guide](/dddart/docs/events/) for the exact guarantees.

## Know the current platform boundaries

| Piece | Portable behavior | Platform-specific choice |
| --- | --- | --- |
| Core models, typed IDs, values, in-memory repository, local bus | The exercised paths compile to JavaScript and run on the Dart VM | Core file logging needs a native filesystem |
| Generated JSON and identity codecs | Representation and reconstruction can be shared | Keep native adapter imports out of the model library |
| HTTP repositories and REST client | Shared HTTP and auth-provider contracts | Browser CORS, token storage, login navigation, and mobile callbacks |
| Aggregate watch and AppSync clients | Shared event types and client composition compile for JavaScript | Platform lifecycle; an actual deployed endpoint and credentials |
| SQLite repository | Native local persistence | The supplied adapter is FFI-based; it does not supply browser storage |
| MySQL, MongoDB, DynamoDB repositories | Shared repository interface | Trusted server/database connectivity and credentials |
| Configuration | Structural provider and resolution contracts can be shared | Built-in filesystem YAML and process environment providers are native |

The documentation checks exercised representative Dart VM programs and JavaScript compilation, with selected JavaScript programs also executed under Node. Those checks do not certify every package configuration, Flutter device, browser login flow, or live AWS deployment. Use the [examples](/dddart/docs/examples/) as a starting point for testing your composition.

## Let the shared language lead the abstraction

Share code because it represents the same concept and rules. Two teams can use the word “customer” for different things; separate bounded contexts may deserve different models and an explicit translation between them.

Likewise, avoid forcing every query, transport, or database operation through one universal interface. A useful contract captures the behavior that really is shared, and makes additional capabilities explicit.

Continue with [repository implementations](/dddart/docs/repositories/), [HTTP composition](/dddart/docs/http/), or [events and watches](/dddart/docs/events/).
