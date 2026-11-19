# Model a domain

Start with something people who use the product can recognize: confirming
a reservation. An aggregate owns the rule that the action can happen only
once. A value object owns the rule that a reservation needs a positive seat
count.

## Confirm a reservation

Start with the application from [Getting started](../quickstarts/core/README.md).
Save this file as `bin/modeling.dart`, then run `dart run bin/modeling.dart`:

<!-- dddart-source: docs/quickstarts/core/bin/modeling.dart -->
```dart
import 'package:dddart/dddart.dart';

class SeatCount extends Value {
  factory SeatCount({required int value}) {
    if (value < 1) {
      throw ArgumentError.value(
          value, 'value', 'At least one seat is required');
    }
    return SeatCount._(value);
  }

  const SeatCount._(this.value);
  final int value;

  @override
  List<Object?> get props => [value];
}

class ReservationConfirmed extends DomainEvent<UuidValue, UuidValue> {
  ReservationConfirmed({
    required super.aggregateId,
    required this.guestName,
    UuidValue? eventId,
    super.occurredAt,
    super.context,
  }) : super(eventId: eventId ?? UuidValue.generate());

  final String guestName;
}

class Reservation extends AggregateRoot<UuidValue> {
  Reservation({
    required this.guestName,
    required this.seats,
    bool confirmed = false,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  })  : _confirmed = confirmed,
        super(id: id ?? UuidValue.generate());

  final String guestName;
  final SeatCount seats;
  bool _confirmed;
  bool get confirmed => _confirmed;

  void confirm() {
    if (_confirmed) throw StateError('This reservation is already confirmed');
    _confirmed = true;
    touch();
    raiseEvent(ReservationConfirmed(
      aggregateId: id,
      guestName: guestName,
    ));
  }
}

Future<void> main() async {
  final Repository<Reservation, UuidValue> reservations =
      InMemoryRepository<Reservation, UuidValue>();
  final reservation = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  reservation.confirm();
  await reservations.save(reservation);

  final loaded = await reservations.getById(reservation.id);
  print('${loaded.guestName}: ${loaded.seats.value} seats, '
      'confirmed: ${loaded.confirmed}');
  print(loaded.getUncommittedEvents().single.runtimeType);
}
```
<!-- /dddart-source -->

`DomainEvent<UuidValue, UuidValue>` uses UUIDs for both the aggregate reference
and the event occurrence. The parameters are independent: a custom aggregate ID
can be paired with a UUID event ID, or either can use another `Identity` subtype.
`ReservationConfirmed` explicitly generates its event ID when none is supplied;
the `DomainEvent` base constructor requires it. Passing an existing ID preserves
the occurrence when restoring the event.

The value's equality comes from `props`; keep those properties immutable.
The aggregate keeps its identity while its state changes. `confirm()`
expresses a business action, updates the model, and records
`ReservationConfirmed`. It does not start IO or publish to a transport.

Keep related rules and child entities behind the aggregate root. Reference
other aggregates by ID when they have their own lifecycles.

## Test the rule before adding infrastructure

Construct a reservation and call `confirm()` twice. The first call records
the event; the second rejects the action. That test needs neither a serializer
nor a database. See [shared contracts](contracts.md) for the next
step: loading and saving the model through an application service.

## When an ID already exists

A reservation can generate a UUID. An issue imported from a tracker may already
have a number that only makes sense in its own repository. In that case, model
both the repository and number as its identity. The [typed identity example](../../packages/dddart/IDENTITY_GUIDE.md#use-a-scoped-identity)
shows how two independently constructed IDs can look up the same issue.
