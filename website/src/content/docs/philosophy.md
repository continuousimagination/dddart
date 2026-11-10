---
title: A shared language, all the way down
description: Why dddart brings the human side of domain-driven design together with portable Dart models and explicit contracts.
section: Start here
order: 10
---

## Start with the people doing the work

Good software begins with people understanding one another. A developer, a designer, a product manager, and an operations specialist should be able to discuss the same reservation, the same approval, and the same rule without translating the conversation into four different vocabularies.

This is the part of domain-driven design we care about most: **a shared language that makes it into the software**. DDD calls this a ubiquitous language. It belongs to the whole team. People who understand the business help shape it; the code gives it a precise, executable form.

If the team says “confirm a reservation,” a method named `confirm()` and an event named `ReservationConfirmed` make sense. A test can say that an already confirmed reservation cannot be confirmed again. A button, a support conversation, and a code review now point at the same behavior.

This goes beyond renaming a database table. The model should express what the words mean, including the rules that distinguish a meaningful action from an arbitrary field change.

| In the conversation | In the model | A question the team can answer together |
| --- | --- | --- |
| “A reservation holds two seats.” | `Reservation` and `SeatCount` | Can a reservation have zero seats? |
| “Confirm this reservation.” | `reservation.confirm()` | What must be true before confirmation? |
| “The reservation was confirmed.” | `ReservationConfirmed` | Who needs to react, and what do they need to know? |
| “Find this customer's reservations.” | An explicit repository query | Which reservations should this person be allowed to see? |

The vocabulary will change as the team learns. That is healthy. Treat a surprising class name or an awkward method as a reason to revisit the conversation, not just to invent another abstraction.

## Keep the parts of DDD that help

DDDart supplies a small set of tools for giving that language structure. Values express immutable concepts. Entities retain identity as their attributes change. Aggregates keep related rules behind an entry point. Repositories provide a contract for retrieving and saving aggregates. Events name meaningful facts.

These are tools for reasoning. An aggregate is useful when it helps explain who owns a rule. A value object is useful when it makes invalid states harder to construct. A repository interface is useful when application code can describe its needs without depending on a particular database client.

DDDart does not require a microservice for every aggregate, event sourcing for every application, or an elaborate directory tree before the first feature. A single-process application with an in-memory repository is a perfectly reasonable place to start. Add the pieces that solve a problem you actually have.

The framework also cannot decide the right aggregate boundary for your business. A base class does not enforce every invariant or turn two independent writes into a transaction. Those decisions remain visible in your model and in the implementations you choose.

## Let the same ideas travel across the stack

Dart gives us an unusual opportunity: the server, browser, and Flutter application can use the same language and share real source code. We can carry a domain model further than a diagram or a generated API type.

Consider an application service that accepts `Repository<Reservation, UuidValue>`. Its work is to load a reservation, apply a domain action, and save it. It does not need to know whether the implementation is an in-memory fake, a database adapter, or an HTTP client repository.

The interface describes what the application needs. The app's entry point chooses how to provide it:

| Environment | Shared code | Implementation chosen there |
| --- | --- | --- |
| A unit test | Domain objects and application services | An in-memory repository and local event handling |
| A server | The same domain types, identities, and contracts | A database repository, authentication, and authoritative policy |
| A web application | Shared models, serializers, repository interfaces, and event definitions | HTTP repositories, browser login/storage, and aggregate watches |
| A mobile application | The same portable model and application code | Remote repositories or suitable native storage, plus mobile lifecycle integration |

This also applies to events. The application can watch a logical aggregate and receive a typed domain event without making an AppSync channel or polling endpoint part of its business model. HTTP polling and an optional live transport implement the same watch contract.

Shared code reduces the places where a concept can quietly acquire different meanings. A serializer reconstructs the same identity type. An event keeps its occurrence ID. A repository query keeps the name the team chose for it.

## Share contracts, respect boundaries

Portability works when dependencies are chosen deliberately. The same contract can have several implementations; those implementations still have different capabilities.

The current SQLite adapter uses native FFI. MySQL and MongoDB connections belong on a trusted server. Browser authentication needs browser-appropriate storage and navigation. File logging needs a filesystem. A client repository crossing a network has latency and failure modes that an in-memory fake does not.

Keep native adapter imports out of a library you intend to share with the browser. Generated repository code becomes part of its annotated model's Dart library, so adding every backend annotation to one shared model is not a universal deployment strategy. The [contracts guide](/dddart/docs/contracts/) explains how to arrange the boundaries.

Reusing a domain rule on a client can make the experience more responsive, but the server still enforces it against authoritative state. A client calling `confirm()` is not proof that the caller has permission to confirm anything. Shared models do not remove trust boundaries.

The same honesty applies to events: durable acceptance, live delivery, and a listener finishing its work are separate milestones. We document those guarantees instead of hiding them behind the word “event.”

## Make the repetitive work earn its keep

There is little value in manually rewriting the same field mapping for every JSON representation or basic repository operation. DDDart generates that code where its supported model and backend contracts are explicit.

Generation should make the interesting code easier to see. Your domain still owns its vocabulary and behavior. Your application still chooses its queries, authentication policy, transaction boundaries, and infrastructure. Generated code handles the mapping around those choices.

There are constraints: constructors must let serializers reconstruct state, identity codecs must define stable representations, and different databases support different collection shapes. The how-to guides show those details. A small, honest abstraction is more useful than a promise that every backend behaves identically.

## Begin with one meaningful action

Pick something a person using your product would recognize: place an order, confirm a reservation, approve a document. Name the concepts with the people who understand them. Write the rule, model the action, and make a test demonstrate its meaning.

Then choose the infrastructure that lets the action reach the people who need it.

[Build your first model](/dddart/docs/getting-started/) or [explore the shared contracts](/dddart/docs/contracts/).
