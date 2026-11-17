# Core model and local events

Save an order and react to its domain event in one Dart process. This example
needs no database or generator.

## Set up the application

Create an empty application outside the DDDart repository:

```sh
mkdir dddart_core_quickstart
cd dddart_core_quickstart
mkdir -p bin
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Model and publish an order

Save this file as `bin/main.dart`:

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

## Run it

<!-- dddart-source: docs/quickstarts/core/commands.sh -->
```sh
dart pub get
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/core/expected/main.txt -->
```text
Sam: order placed = true
```
<!-- /dddart-source -->

The order records an event before saving. The program publishes it after the
save, acknowledges the captured batch, and waits for the listener before
closing its bus. The in-memory repository keeps object references and loses
its data when the process ends.

## Try the other core programs

Copy the named files from the
[modeling](https://continuousimagination.github.io/dddart/docs/modeling/),
[shared contracts](https://continuousimagination.github.io/dddart/docs/contracts/),
and [repositories](https://continuousimagination.github.io/dddart/docs/repositories/)
guides into `bin`, then run:

<!-- dddart-source: docs/quickstarts/core/guide_commands.sh -->
```sh
dart run bin/repository.dart
dart run bin/contracts.dart
dart run bin/modeling.dart
dart run bin/identity.dart
```
<!-- /dddart-source -->

Delete the temporary application directory when finished. Use the
[example index](../../QUICKSTARTS.md) to choose a serializer, persistent
repository, or integration.
