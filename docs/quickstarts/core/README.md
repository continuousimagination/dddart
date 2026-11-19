# Core model and local events

An order can be placed once. Give the order a `place()` method that enforces
that rule, save it in memory, and listen for `OrderPlaced`. You only need the
Dart SDK and access to fetch the dependencies.

## Set up the application

Create an empty application outside the DDDart repository:

```sh
mkdir dddart_core_quickstart
cd dddart_core_quickstart
mkdir -p bin
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`. For an existing application, see the
[Git installation guide](../../GIT_INSTALLATION.md).

<a id="model-and-run-an-order"></a>

## Model and publish an order

Save this file as `bin/main.dart`:

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

## Run it

<!-- dddart-source: docs/quickstarts/core/commands.sh -->
```sh
dart pub get
dart run bin/main.dart
```
<!-- /dddart-source -->

Expected output:

<!-- dddart-source: docs/quickstarts/core/expected/main.txt -->
```text
Sam: order placed = true
```
<!-- /dddart-source -->

The listener receives the ID of the saved order. That is how it knows which
order to load. The program subscribes before placing the order because the
local bus only delivers events to active listeners. Publishing after the save
means a failed save cannot announce a successful order.

Try adding a second `order.place();` immediately after the first. Run the
program again. The order throws `StateError` before anything is saved.
Remove the extra call to restore the successful run.

<a id="choose-your-next-step"></a>

## Where to go next

- To put a rule on a value, such as a positive seat count, follow
  [Model a domain](../../guides/modeling.md) using this same application.
- To send the model across a boundary, follow the [JSON quickstart](../json/README.md).
- To choose storage for your runtime, read the [repository guide](../../guides/repositories.md).
- To keep data after the program exits, try the [SQLite quickstart](../sqlite/README.md).
- For the reasoning behind capture, save, publish, and acknowledge, read the
  [domain event guide](../../../packages/dddart/DOMAIN_EVENTS_GUIDE.md).
