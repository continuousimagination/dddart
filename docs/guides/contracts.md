# Share contracts

Let an application service say what it needs through a constructor. The
application entrypoint chooses a repository that can provide it.

## Put the repository in the constructor

In the application from [Getting started](../quickstarts/core/README.md),
save this file as `bin/contracts.dart` and run `dart run bin/contracts.dart`:

<!-- dddart-source: docs/quickstarts/core/bin/contracts.dart -->
```dart
import 'package:dddart/dddart.dart';

class Reservation extends AggregateRoot<UuidValue> {
  Reservation({required this.guest}) : super(id: UuidValue.generate());
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
<!-- /dddart-source -->

`ConfirmReservation` loads and saves a typed aggregate. The caller creates the
in-memory repository. A native or server application can supply a persistent
adapter, and a client can call a corresponding HTTP API.

## Keep platform choices at the edge

Place portable models and application interfaces in a library that does not
import native IO. Generated parts share the annotated library's imports, so
adding a native database annotation or import there can exclude it from a
browser build. Keep native persistence in a separate server library when
the browser and server share models.

| Where it runs | What to compose there |
| --- | --- |
| A local test | An in-memory repository and local event listeners |
| A native app | A native storage adapter or HTTP client, with lifecycle and credential storage |
| A trusted server | A database repository and authoritative policies |
| A browser | An HTTP or native IndexedDB repository with browser-appropriate login and storage |

Share domain code where it makes sense. The server still applies access rules
and validates state changes. Use the [adapter guide](repositories.md)
to choose storage and check its transaction and query guarantees.
