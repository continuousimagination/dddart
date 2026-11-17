# Core model and local events

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_core_quickstart
cd dddart_core_quickstart
mkdir -p bin
```

Save as `pubspec.yaml` (the fixture uses `.txt` only to keep it out of the monorepo workspace):

<!-- dddart-source: docs/quickstarts/core/pubspec.yaml.txt -->
```yaml
name: dddart_core_quickstart
publish_to: none
environment:
  sdk: '>=3.13.7 <4.0.0'
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart
```
<!-- /dddart-source -->

Save as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/core/bin/main.dart -->
```dart
import 'package:dddart/dddart.dart';

class OrderPlaced extends DomainEvent<UuidValue> {
  OrderPlaced({required super.aggregateId});
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

Resolve dependencies, analyze, and run:

```sh
dart pub get
dart analyze --fatal-infos
dart run bin/main.dart
```

Expected output:

```text
Sam: order placed = true
```

The program finishes and closes its resources. Delete the temporary application directory when finished.
The repository holds object references and the event bus is local. This example
does not promise durable storage, listener completion, or an atomic outbox.
