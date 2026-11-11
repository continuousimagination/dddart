---
title: Model the language of your domain
description: Give business concepts a name, keep rules with the model, and choose identities that fit your domain.
section: Build your domain
order: 10
---

## Start with the conversation

A reservation is confirmed. An order is placed. A subscription is cancelled. These are useful names because the people doing the work already use them.

Model those actions directly. A method named `confirm()` gives a conversation, a test, a button, and a server operation the same point of reference. DDDart supplies a few building blocks; your team decides what the concepts mean and which rules they must protect.

| Building block | Use it for | Equality |
| --- | --- | --- |
| `Value` | A quantity, address, date range, or other immutable concept | Concrete type and the properties in `props` |
| `Identity` | A domain-specific identifier, including its scope | The same value semantics as `Value` |
| `Entity<I>` | Something whose identity survives changes to its attributes | Concrete entity type and `id` |
| `AggregateRoot<I>` | The entry point that protects a group of related objects | Entity equality, plus pending domain events |
| `DomainEvent<I>` | A fact about something that happened to an aggregate | Its event occurrence ID |

`UuidEntity` and `UuidAggregateRoot` are convenient specializations when a generated UUID fits the domain. General entities and aggregates require an explicit identity.

## Build a reservation

This complete example needs only the `dddart` dependency from [Getting started](/dddart/docs/getting-started/). Save it as `bin/reservations.dart` and run `dart run bin/reservations.dart`.

```dart
import 'package:dddart/dddart.dart';

class SeatCount extends Value {
  factory SeatCount({required int value}) {
    if (value < 1) {
      throw ArgumentError.value(value, 'value', 'At least one seat is required');
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

class Reservation extends UuidAggregateRoot {
  Reservation({
    required this.guestName,
    required this.seats,
    bool confirmed = false,
    super.id,
    super.createdAt,
    super.updatedAt,
  }) : _confirmed = confirmed;

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

The aggregate owns the rule that a reservation cannot be confirmed twice. The application owns when to save it. Calling `raiseEvent()` records a pending event; this ordinary in-memory save does **not** publish or clear it. [Events](/dddart/docs/events/) explains the publication lifecycle.

This example is a domain model, not a generated-serialization model. Generated serializers reconstruct stored fields through named constructor parameters. The [serialization guide](/dddart/docs/serialization/) shows a complete model shaped for that boundary; private stored fields and differently named constructor parameters need deliberate treatment.

## Choose the aggregate boundary

Keep objects that must satisfy an invariant together behind an aggregate's methods. Store and retrieve the aggregate through its repository. DDDart's repository contract accepts aggregate roots, not arbitrary nested entities.

For example, a reservation may own its assigned seats. The aggregate can decide whether an assignment is valid. A `Customer` in another aggregate usually remains a reference by identity instead of becoming part of every reservation's persistence graph.

The base class does not discover business rules, enforce every aggregate boundary, or create a transaction across repositories. Those are modeling and implementation decisions. See [Repository contracts](/dddart/docs/repositories/) for the persistence side.

## Use the identity the domain already has

A UUID is useful when your application creates identities. It is not necessary when another system already supplies a meaningful identifier. Include the full scope of a composite identity so that two locally equal numbers remain distinct.

This is another standalone core-only example:

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
  final Repository<Issue, IssueId> issues = InMemoryRepository<Issue, IssueId>();
  final issue = Issue(
    id: const IssueId('team/booking', 12),
    title: 'Explain cancellation rules',
  );
  await issues.save(issue);
  final loaded = await issues.getById(const IssueId('team/booking', 12));
  print(loaded.title);
}
```

`IssueId('team/booking', 12)` and `IssueId('team/billing', 12)` are different identities. Another identity class with identical properties is also different. A `Repository<Issue, IssueId>` requires an `IssueId` for lookup and deletion; passing an unrelated ID type is a compile-time error in typed Dart code.

A custom identity also needs an explicit codec when it crosses JSON, storage, HTTP, or event boundaries. An identity's `toString()` is for presentation or debugging, not an implicit storage format. See [Serialization](/dddart/docs/serialization/#give-custom-identities-an-explicit-codec).

## Keep values immutable

Include the properties that define the concept in `props`. Values compare nested lists and finite iterables in order; sets and maps compare without regard to insertion order. Lists, sets, maps, and other iterables remain distinct categories. Cyclic collections are not supported.

A `final` list reference does not make its contents immutable. Copy caller-owned collections into unmodifiable collections when constructing a value. Mutating equality properties after using a value as a map key or set member can make it impossible to find reliably.

Entities behave differently: their equality uses identity, not a snapshot of every field. Updating an entity does not make it a new entity. `createdAt` and `updatedAt` are initialized by the base constructor; call `touch()` when your domain method changes state. A save does not automatically imply that the model's timestamp changed.

## Test the rule before the infrastructure

Test `confirm()` and the resulting state and pending event directly. Use `InMemoryRepository` to exercise an application service against the repository contract. It stores object references in an instance-local map, so it is a convenient fake, not a simulation of serialization, isolation, or database transactions.

Share the domain model and its tests between the server and clients. Keep platform-specific adapters in composition code, as described in [One domain, several runtimes](/dddart/docs/contracts/).

## Implementation references

- [Entity and UUID specializations](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart/lib/src/entity.dart)
- [Aggregate roots and captured event batches](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart/lib/src/aggregate_root.dart)
- [Value equality](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart/lib/src/value.dart)
- [Typed-identity tests](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart/test/identity_test.dart)
