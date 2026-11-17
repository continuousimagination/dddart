# JSON generation and round trip

Generate a serializer for a reservation, then round-trip it as a map and as
JSON text. The model stays responsible for its domain data; the serializer
owns the representation.

## Set up the application

Create an empty application outside the DDDart repository:

```sh
mkdir dddart_json_quickstart
cd dddart_json_quickstart
mkdir -p bin lib
```

Copy the [example pubspec](pubspec.yaml.txt) into the application as `pubspec.yaml`.

## Add the model

Save this file as `lib/reservation.dart`. The `.g.dart` part is generated in the
next step.

<!-- dddart-source: docs/quickstarts/json/lib/reservation.dart -->
```dart
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'reservation.g.dart';

@Serializable()
class Reservation extends AggregateRoot<UuidValue> {
  Reservation({
    required this.guestName,
    required this.seats,
    this.note,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  }) : super(id: id ?? UuidValue.generate());

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
<!-- /dddart-source -->

## Generate and run

Save this file as `bin/main.dart`:

<!-- dddart-source: docs/quickstarts/json/bin/main.dart -->
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
<!-- /dddart-source -->

Run these commands in the application directory:

<!-- dddart-source: docs/quickstarts/json/commands.sh -->
```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
```
<!-- /dddart-source -->

The program prints the restored guest name and verifies the ID and seat count:

<!-- dddart-source: docs/quickstarts/json/expected/main.txt -->
```text
Sam
true
true
```
<!-- /dddart-source -->

## Try naming and null options

Save this file as `bin/configuration.dart`. It uses the generated reservation
serializer above to show naming and null behavior:

<!-- dddart-source: docs/quickstarts/json/bin/configuration.dart -->
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
<!-- /dddart-source -->

## Try a custom identity

Save this file as `bin/identity.dart`. It registers a scoped ID codec,
round-trips the canonical key, and shows the tagged JSON type:

<!-- dddart-source: docs/quickstarts/json/bin/identity.dart -->
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
    if (decoded is! List ||
        decoded.length != 2 ||
        decoded[0] is! String ||
        decoded[1] is! int) {
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
<!-- /dddart-source -->

Run both programs from the application directory:

<!-- dddart-source: docs/quickstarts/json/guide_commands.sh -->
```sh
dart run bin/configuration.dart
dart run bin/identity.dart
```
<!-- /dddart-source -->

Expected configuration output:

<!-- dddart-source: docs/quickstarts/json/expected/configuration.txt -->
```text
Sam
true
Sam
Sam
```
<!-- /dddart-source -->

Expected identity output:

<!-- dddart-source: docs/quickstarts/json/expected/identity.txt -->
```text
true
issue.v1
```
<!-- /dddart-source -->

Delete the temporary application directory when finished. See the
[serialization contract](../../SERIALIZATION.md) for precedence and error
behavior.
