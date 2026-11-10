---
title: Getting started
description: Install from Git, give a business concept a home, and run a complete domain-and-repository example.
section: Start here
order: 20
---

## Install the current pre-release

The dddart packages are currently installed from Git. The examples in this guide use the same immutable revision, `b4aacf0671873e729a1a390dc2bb609b80c723e5`, so they do not silently change when the repository advances. Core, generation, and example checks for these guides used Dart 3.9.4. Flutter applications use their bundled Dart SDK.

Create a small Dart application:

```bash
dart create -t console dddart_starter
cd dddart_starter
```

Add this entry to your `pubspec.yaml` under `dependencies`:

```yaml
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: b4aacf0671873e729a1a390dc2bb609b80c723e5
      path: packages/dddart
```

Then resolve the dependency:

```bash
dart pub get
```

Use `flutter pub get` in a Flutter project. Commit your application's `pubspec.lock` so its resolved dependency graph is reproducible. A hosted dependency such as `dddart: ^0.9.0` is not a substitute for this Git installation.

## Model one useful action

Save the following complete program as `bin/orders.dart`. It defines an order, records the fact that it was placed, and stores the order through a repository interface.

```dart
import 'package:dddart/dddart.dart';

class OrderPlaced extends DomainEvent<UuidValue> {
  OrderPlaced({required super.aggregateId});
}

class Order extends UuidAggregateRoot {
  Order({required this.customer});

  final String customer;
  bool _placed = false;
  bool get isPlaced => _placed;

  void place() {
    if (_placed) throw StateError('The order is already placed');
    _placed = true;
    touch();
    raiseEvent(OrderPlaced(aggregateId: id));
  }
}

Future<void> main() async {
  final Repository<Order, UuidValue> orders =
      InMemoryRepository<Order, UuidValue>();
  final bus = EventBus();
  final received = bus.on<OrderPlaced>().first;
  final order = Order(customer: 'Sam');

  order.place();
  final batch = order.captureUncommittedEvents();
  await orders.save(order);

  for (final event in batch.events) {
    bus.publish(event);
  }
  batch.acknowledgeAll();

  final event = await received;
  final loaded = await orders.getById(event.aggregateId);
  print('${loaded.customer}: order placed = ${loaded.isPlaced}');
  await bus.close();
}
```

Run it:

```bash
dart run bin/orders.dart
```

The program prints `Sam: order placed = true`. Calling `place()` twice fails the domain rule. The event has the same typed aggregate identity used by the repository.

This example deliberately uses a local bus and an in-memory repository. The repository keeps object references; it is not durable storage. A local `publish()` enqueues delivery; it does not wait for every listener's business operation. The explicit `received` future waits for the event used in this example. See [Events](/dddart/docs/events/) for asynchronous publication, retries, and durable acceptance.

## Understand the pieces you just used

| Piece | What it contributes |
| --- | --- |
| `UuidAggregateRoot` | An aggregate identity, lifecycle timestamps, and a pending event queue |
| `place()` | A business action and its rule, owned by your model |
| `Repository<Order, UuidValue>` | A typed contract for get, save, and delete |
| `InMemoryRepository` | A simple implementation for this local example |
| `DomainEvent<UuidValue>` | A fact tied to an aggregate, with its own occurrence ID |
| `EventBus` | Typed local delivery to interested listeners |

The general `AggregateRoot<I>` takes an explicit identity. Use `UuidAggregateRoot` when a generated UUID is appropriate; use a custom `Identity` when the domain already has an identifier or needs a composite scope.

## Add JSON or other packages

For JSON generation, add direct Git entries for `dddart_serialization` and `dddart_json` with the same `url` and `ref`, changing `path` to the corresponding `packages/<name>` directory. Add `build_runner` as a development dependency, then follow the complete [serialization how-to](/dddart/docs/serialization/).

Some adapters still declare sibling dddart dependencies as hosted packages. Until publication, those need same-revision Git `dependency_overrides` in the **consuming application's root pubspec**. Adding a direct Git dependency alone does not change a transitive hosted dependency's source.

The [complete override fragment](/dddart/downloads/git-dependencies.yaml) lists all 17 dddart packages pinned to the revision used here. Copy its `dependency_overrides` section into your root pubspec, and add the packages your own code imports under `dependencies` as shown in the fragment. The fragment is configuration to merge into your existing pubspec, not a complete application manifest. Keep all dddart refs aligned when updating.

For working inside this repository instead, use the root Dart workspace:

```bash
git clone https://github.com/continuousimagination/dddart.git
cd dddart
git checkout b4aacf0671873e729a1a390dc2bb609b80c723e5
dart pub get
```

The [examples guide](/dddart/docs/examples/) identifies the commands, generation steps, and external services each example needs.

## Choose your next step

- [Modeling](/dddart/docs/modeling/): values, aggregate boundaries, identities, and business rules.
- [Shared contracts](/dddart/docs/contracts/): organize the code you want to reuse on server, web, and mobile.
- [JSON serialization](/dddart/docs/serialization/): generate a representation that preserves the domain's types.
- [Repositories](/dddart/docs/repositories/): move from in-memory storage to SQLite or another adapter.
- [HTTP](/dddart/docs/http/): expose a repository on the server and consume it from a client.
- [Events](/dddart/docs/events/): connect local behavior to aggregate watches and retained history.
