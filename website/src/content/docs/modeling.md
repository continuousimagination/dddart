---
title: Model a domain
description: Make a rule explicit with a value, a typed identity, an aggregate action, and an event.
section: Build your domain
order: 10
---

Start with something people who use the product can recognize: confirming
a reservation. An aggregate owns the rule that the action can happen only
once. A value object owns the rule that a reservation needs a positive seat
count.

## Confirm a reservation

Start with the application from [Getting started](/dddart/docs/getting-started/).
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

class ReservationConfirmed extends DomainEvent<UuidValue> {
  ReservationConfirmed({
    required super.aggregateId,
    required this.guestName,
    super.eventId,
    super.occurredAt,
    super.context,
  });

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

The value's equality comes from `props`; keep those properties immutable.
The aggregate keeps its identity while its state changes. `confirm()`
expresses a business action, updates the model, and records
`ReservationConfirmed`. It does not start IO or publish to a transport.

Keep related rules and child entities behind the aggregate root. Reference
other aggregates by ID when they have their own lifecycles.

## Use an identity that fits the domain

A UUID works when the application assigns an ID. An issue number in an
external system can instead be part of a scoped identity. The number alone
would confuse issues in different repositories. Save this file as
`bin/identity.dart` and run `dart run bin/identity.dart`:

<!-- dddart-source: docs/quickstarts/core/bin/identity.dart -->
```dart
import 'package:dddart/dddart.dart';

class IssueId extends Identity {
  const IssueId(this.repository, this.number);
  final String repository;
  final int number;

  @override
  List<Object?> get props => [repository, number];
}

class Issue extends AggregateRoot<IssueId> {
  Issue({required super.id, required this.title});
  final String title;
}

Future<void> main() async {
  final Repository<Issue, IssueId> issues =
      InMemoryRepository<Issue, IssueId>();
  final issue = Issue(
    id: const IssueId('team/booking', 12),
    title: 'Explain cancellation rules',
  );
  await issues.save(issue);
  final loaded = await issues.getById(const IssueId('team/booking', 12));
  print(loaded.title);
}
```
<!-- /dddart-source -->

A typed repository accepts only that identity kind. When a custom identity
crosses a JSON or persistence boundary, give it a
[codec](/dddart/docs/serialization/#give-custom-identities-a-codec) that
round-trips both the scope and number.

## Test the rule before adding infrastructure

Construct a reservation and call `confirm()` twice. The first call records
the event; the second rejects the action. That test needs neither a serializer
nor a database. See [shared contracts](/dddart/docs/contracts/) for the next
step: loading and saving the model through an application service.
