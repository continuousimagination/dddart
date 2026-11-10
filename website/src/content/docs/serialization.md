---
title: Generate JSON at the boundary
description: Generate serializer services, preserve identity across platforms, and control the wire format explicitly.
section: Build your domain
order: 20
---

## Keep conversion outside the domain's behavior

DDDart's JSON generator creates a separate `YourTypeJsonSerializer` service. Your aggregate keeps its business methods; the serializer handles a representation used by an API, a repository, or an event transport.

There are three packages involved:

| Package | Responsibility |
| --- | --- |
| `dddart` | Domain types such as `AggregateRoot`, `Value`, and `Identity` |
| `dddart_serialization` | `@Serializable()`, `Serializer<T>`, configuration, and identity codecs |
| `dddart_json` | `JsonSerializer<T>` and generated JSON serializer services |

JSON is the supplied format implementation. The generic `Serializer<T>` contract leaves room for other implementations; it does not mean YAML or Protocol Buffers serializers are included.

## Install the generator

Follow the [Git installation instructions](/dddart/docs/getting-started/) and add `dddart`, `dddart_serialization`, and `dddart_json` from the **same full commit SHA**. Add the generator runner as a development dependency:

```bash
dart pub add dev:build_runner
```

The model file must import `dart:convert`, the domain package, the serialization package, and the JSON package. The generated part shares those imports.

## Generate and use a serializer

Save this complete library as `lib/reservation.dart`:

```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'reservation.g.dart';

@Serializable()
class Reservation extends UuidAggregateRoot {
  Reservation({
    required this.guestName,
    required this.seats,
    this.note,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String guestName;
  final SeatCount seats;
  final String? note;
}

@Serializable()
class SeatCount extends Value {
  factory SeatCount({required int value}) {
    if (value < 1) throw ArgumentError('At least one seat is required');
    return SeatCount._(value);
  }

  const SeatCount._(this.value);
  final int value;

  @override
  List<Object?> get props => [value];
}
```

Generate the part:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then save this as `bin/serialization.dart` and run `dart run bin/serialization.dart`:

```dart
import '../lib/reservation.dart';

void main() {
  final serializer = ReservationJsonSerializer();
  final original = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  final json = serializer.toJson(original);
  final text = serializer.serialize(original);
  final restored = serializer.deserialize(text);

  print(json['guestName']); // Sam
  print(restored.id == original.id); // true
  print(restored.seats == original.seats); // true
}
```

The generated class implements `JsonSerializer<Reservation>`. Use `toJson` and `fromJson` for maps, and `serialize` and `deserialize` for strings. UUIDs use their string representation; timestamps use ISO 8601 text. A nullable field is omitted by default when its value is null.

## Control naming and nulls

Configuration precedence runs from a method call, to the serializer's constructor, to the concrete class's annotation, to framework defaults. A supplied configuration is a complete set of settings; it is not a field-by-field merge with lower levels. An ancestor's annotation does not contribute settings to its concrete descendant.

With the model above, this standalone program creates snake-case JSON and includes a null `note`:

```dart
import 'package:dddart_serialization/dddart_serialization.dart';

import '../lib/reservation.dart';

void main() {
  const apiFormat = SerializationConfig(
    fieldRename: FieldRename.snake,
    includeNullFields: true,
  );
  final serializer = ReservationJsonSerializer(apiFormat);
  final reservation = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  final wire = serializer.toJson(reservation);
  print(wire['guest_name']); // Sam
  print(wire.containsKey('note')); // true
  final restored = serializer.fromJson(wire);
  print(restored.guestName); // Sam

  // This call uses the framework settings instead of apiFormat.
  final ordinary = serializer.toJson(reservation, const SerializationConfig());
  print(ordinary['guestName']); // Sam
}
```

Supported naming strategies are unchanged names, `snake_case`, and `kebab-case`. Use the same effective format when encoding and decoding. The parent serializer passes its effective configuration and identity registry to nested serializers.

## Give custom identities an explicit codec

A domain identity describes equality. An `IdentityCodec<I>` describes its JSON and canonical-key representations. Those are separate responsibilities: a composite ID might use a JSON object on the wire and a reversible string key in storage.

This standalone example needs `dddart` and `dddart_serialization`; it does not require code generation:

```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

class IssueId extends Identity {
  const IssueId(this.repository, this.number);
  final String repository;
  final int number;

  @override
  List<Object?> get props => [repository, number];
}

class IssueIdCodec implements IdentityCodec<IssueId> {
  const IssueIdCodec();

  @override
  Object toJson(IssueId identity) => {
        'repository': identity.repository,
        'number': identity.number,
      };

  @override
  IssueId fromJson(Object? value) {
    if (value is! Map ||
        value['repository'] is! String ||
        value['number'] is! int) {
      throw const FormatException('Expected repository and integer number');
    }
    return IssueId(value['repository'] as String, value['number'] as int);
  }

  @override
  String toKey(IssueId identity) =>
      jsonEncode([identity.repository, identity.number]);

  @override
  IssueId fromKey(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List || decoded.length != 2 ||
        decoded[0] is! String || decoded[1] is! int) {
      throw const FormatException('Expected canonical issue key');
    }
    return IssueId(decoded[0] as String, decoded[1] as int);
  }
}

void main() {
  final codecs = IdentityCodecRegistry()
    ..register<IssueId>('issue.v1', const IssueIdCodec());
  const id = IssueId('team/booking', 12);
  final key = codecs.toKey(id);
  print(codecs.fromKey<IssueId>(key) == id); // true
  print(codecs.toTaggedJson(id)['type']); // issue.v1
}
```

For a generated `IssueJsonSerializer`, inject this registry using its `withIdentityCodecs(codecs)` constructor. Pass the same registry to the repository and event boundaries that need it. This constructor call assumes you have defined an annotated `Issue` aggregate and run the generator; it is not an additional built-in serializer.

Registry keys such as `issue.v1` are explicit, stable wire discriminators. Registries are instance-local; UUID support is included under `uuid`. Duplicate types or discriminator keys are rejected. Canonical key decoding rejects aliases that would re-encode differently, and encoding checks that the key round-trips losslessly. Each storage or HTTP adapter may impose additional key limits.

## Shape models for reconstruction

The generator supports concrete, non-generic subclasses of `AggregateRoot`, `Entity`, `Value`, and `DomainEvent`. It supports primitive fields, enums by name, `DateTime`, typed identities, nested supported domain objects, and recursive lists, sets, and maps. JSON map keys must be non-null strings or concrete identity types with key codecs. Dynamic or `Object` values still need to contain values that JSON itself can encode.

Use an unnamed constructor with named parameters corresponding to stored fields. For entities and aggregates, expose `id`, `createdAt`, and `updatedAt` in that constructor. Inherited application fields must be reconstructible through a named `super` parameter chain. Computed getters do not become stored fields; accessible stored fields do. A private field and a differently named public constructor parameter are not automatically mapped for you.

For serialized events, expose all base metadata as named constructor parameters: `aggregateId`, `eventId`, `occurredAt`, and `context`. Otherwise generation fails instead of silently inventing a new occurrence ID during deserialization. A pending aggregate event batch is transient bookkeeping and is not part of the serialized aggregate.

Run generation and analysis after changing a model. Treat generated code as build output; update the source model or configuration rather than editing its `.g.dart` part.

## Implementation references

- [Generator and supported type rules](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_json/lib/src/generators/serializable_generator.dart)
- [Identity codecs and registry](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_serialization/lib/src/identity_codec.dart)
- [Configuration precedence tests](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_json/test/annotation_configuration_precedence_test.dart)
- [Event metadata round-trip tests](https://github.com/continuousimagination/dddart/blob/b4aacf0671873e729a1a390dc2bb609b80c723e5/packages/dddart_json/test/domain_event_roundtrip_test.dart)
