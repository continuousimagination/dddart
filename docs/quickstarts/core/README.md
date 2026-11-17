# Core model and local events

The example manifest uses one immutable Git revision; it does not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_core_quickstart
cd dddart_core_quickstart
mkdir -p bin
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.
It declares the SDK requirement and all dependency constraints.

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

<!-- dddart-source: docs/quickstarts/core/commands.sh -->
```sh
dart pub get
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Optional additional guide programs: copy their named files from the
[modeling](https://continuousimagination.github.io/dddart/docs/modeling/),
[contracts](https://continuousimagination.github.io/dddart/docs/contracts/) and
[repository](https://continuousimagination.github.io/dddart/docs/repositories/) guides
into `bin` before running these commands.

<!-- dddart-source: docs/quickstarts/core/guide_commands.sh -->
```sh
dart run bin/repository.dart
dart run bin/contracts.dart
dart run bin/modeling.dart
dart run bin/identity.dart
```
<!-- /dddart-source -->

Expected output from `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/core/expected/main.txt -->
```text
Sam: order placed = true
```
<!-- /dddart-source -->

The program finishes and closes its resources. Delete the temporary application directory when finished.
The repository holds object references and the event bus is local. This example
does not promise durable storage, listener completion, or an atomic outbox.
