---
title: Generate JSON
description: Generate a serializer for a Dart model, choose its JSON shape, and round-trip a typed identity.
section: Build your domain
order: 30
---

A reservation can enforce its own business rules without knowing how an API sends
it. With `@Serializable()`, DDDart generates a separate serializer for the model.
Use that serializer wherever the representation crosses a boundary.

## Generate and use a serializer

Follow the [JSON quickstart](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/json/README.md)
for the pubspec, complete reservation model, commands, and expected output.
Its model declares a `.g.dart` part. Run the builder in the owning package
before running the program; regenerate when you change the model.

The example creates a `ReservationJsonSerializer` and round-trips one
reservation. Use `toJson` for a map to include in another JSON object, or
`serialize` for a JSON string. Constructors must be able to reconstruct the
persisted fields. Keep runtime dependencies such as a file or database connection
out of a library you need to compile for the browser.

## Control naming and nulls

A `SerializationConfig` controls details such as field naming and nulls. An
explicit call config replaces the serializer's constructor config. Without
either, the model's annotation and defaults apply. Nested serializers get the
effective config too. Use the
[configuration example](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/json/bin/configuration.dart)
to compare the results.

## Give custom identities a codec

Use the stock codec for UUIDs. If an ID has domain-specific fields or scope,
register an `IdentityCodec<I>` that round-trips all of them. Give the same
registry to serializers, repositories, and event registries that cross that
boundary. For an example, see the
[scoped identity codec](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/json/bin/identity.dart).

Read the [serialization contract](https://github.com/continuousimagination/dddart/blob/main/docs/SERIALIZATION.md)
for exact precedence, codec composition, and how to distinguish bad input from
an application error.
