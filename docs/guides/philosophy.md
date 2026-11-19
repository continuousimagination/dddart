# Why DDDart

When people say “confirm a reservation,” the code should tell them what
confirmation means. Give the action a name, make its rules explicit, and write
a test that everyone involved can recognize. Domain-driven design calls the
vocabulary the team uses together a shared or ubiquitous language.

| In a conversation | In the model | A question to answer together |
| --- | --- | --- |
| A reservation holds two seats | `Reservation` and `SeatCount` | Can a reservation have zero seats? |
| Confirm this reservation | `reservation.confirm()` | What must be true before confirmation? |
| The reservation was confirmed | `ReservationConfirmed` | Who needs to react and what do they need to know? |
| Find a guest's reservations | A named repository query | Which records may this caller see? |

## Model an action before choosing storage

An aggregate gives related rules a place to live. Values express concepts
with their own equality and validation. A repository gives application
code a way to load and save a model. An event describes a fact that other
code can act on. DDDart supplies these building blocks; the people who
understand the product choose the boundaries.

Start with a model and a test. Add a generator, database, API, or notification
transport when the application needs one. The same Dart model can run in
tests, on a server, or in a client if its dependencies fit that runtime.

[Build your first model](../quickstarts/core/README.md) or
[read about sharing contracts](contracts.md).
