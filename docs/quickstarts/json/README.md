# JSON generation and round trip

Use Dart **3.13.7**, the development SDK used for these checks. This is a verified
setup, not a claim about the minimum SDK on every platform (#98 tracks that).
The DDDart dependencies below use one immutable Git revision; they do not require
published DDDart packages. See [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md)
for source overrides and [the support matrix](https://github.com/continuousimagination/dddart/blob/main/docs/CAPABILITIES.md) for platform limits.

Create an empty directory **outside this repository**, then create the named files:

```sh
mkdir dddart_json_quickstart
cd dddart_json_quickstart
mkdir -p bin lib
```

Save as `pubspec.yaml` (the fixture uses `.txt` only to keep it out of the monorepo workspace):

<!-- dddart-source: docs/quickstarts/json/pubspec.yaml.txt -->
```yaml
name: dddart_json_quickstart
publish_to: none
environment:
  sdk: '>=3.13.7 <4.0.0'
dependencies:
  dddart:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart
  dddart_json:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_json
  dddart_serialization:
    git:
      url: https://github.com/continuousimagination/dddart.git
      ref: 56607ac8d3913b8e896ac03f8ecff58473d62ce2
      path: packages/dddart_serialization
dev_dependencies:
  build_runner: ^2.4.0
```
<!-- /dddart-source -->

Save as `bin/configuration.dart`:

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

Save as `bin/identity.dart`:

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

Save as `bin/main.dart`:

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

Save as `lib/reservation.dart`:

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

Resolve dependencies, generate from clean build state, analyze, and run:

```sh
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart run bin/main.dart
dart run bin/configuration.dart
dart run bin/identity.dart
```

Expected output for `bin/main.dart`:

```text
Sam
true
true
```

`bin/configuration.dart` prints:

```text
Sam
true
Sam
Sam
```

`bin/identity.dart` prints:

```text
true
issue.v1
```

The program finishes and closes its resources. Delete the temporary application directory when finished.
