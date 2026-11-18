---
title: Getting started
description: Model an order, save it in memory, and react to a domain event in one application.
section: Start here
order: 10
---

Start with an order that can be placed once. You'll save it through a repository
and listen for the event that the order was placed. This example uses the core
package, a local event bus, and no external services.

## Set up the application

With the Dart SDK installed, create an empty application directory outside the DDDart checkout and a `bin` subdirectory inside it. Copy the
[core example pubspec](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/core/pubspec.yaml.txt)
into the application as `pubspec.yaml`. Run `dart pub get` in that directory.
For an existing app, see the
[Git installation guide](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md).

## Model and run an order

Save this code as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/core/bin/main.dart -->
```dart
import 'package:dddart/dddart.dart';

class OrderPlaced extends DomainEvent<UuidValue, UuidValue> {
  OrderPlaced({required super.aggregateId})
      : super(eventId: UuidValue.generate());
}

class Order extends AggregateRoot<UuidValue> {
  Order({required this.customer}) : super(id: UuidValue.generate());

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
<!-- /dddart-source -->

Run `dart run bin/main.dart` from the application directory:

<!-- dddart-source: docs/quickstarts/core/expected/main.txt -->
```text
Sam: order placed = true
```
<!-- /dddart-source -->

The listener subscribes before the order is placed. `place()` records the
event on the order. Saving and publishing are separate steps so a failed save
cannot announce a successful order. When the listener receives the event, it
uses the order ID to load the saved state. The data lasts for this run.

**Try the rule.** Add a second `order.place();` immediately after the first
and run again. The order rejects the second call before the program reaches
`save`. Remove it to return to the successful run.

## Choose your next step

- [Model a domain](/dddart/docs/modeling/) with values, aggregate rules, and
  typed IDs.
- [Generate JSON](/dddart/docs/serialization/) when a model needs a wire format.
- [Choose a repository](/dddart/docs/repositories/) when you need persistence.
