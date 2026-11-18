# Typed identity

`Identity` extends `Value`: equality includes runtime kind and structural `props`.
Keep every identity field immutable. Include every scope component; equal issue
numbers in different repositories must not collapse to the same identity.
`UuidValue` supplies UUID creation/validation, not an implicit fallback for an
externally identified entity.

`Entity<I>`, `AggregateRoot<I>`, `Repository<T, I>` and `DomainEvent<I>` retain the
concrete identity. Both entity and aggregate constructors require `id:`.
A domain constructor may explicitly choose `UuidValue.generate()`.
Event occurrence IDs remain UUIDs independently of their aggregate's identity.

## Use a scoped identity

In the application from the [core quickstart](../../docs/quickstarts/core/README.md),
save this file as `bin/identity.dart` and run `dart run bin/identity.dart`.
The repository finds the issue using a newly constructed ID with the same
repository name and number.

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

## Boundary contracts

Identity determines domain equality, not a universal storage representation.
Application codecs define structural JSON and canonical, reversible keys.
Do not encode `toString()`, concatenate scope components ambiguously or hash an
external identity into a UUID. Registry type keys are explicit wire contracts.

Pass the same codec registry through serializers, repositories and event
registries. Each adapter owns its key-size, comparison and URI-escaping rules.
See [serialization](../../docs/SERIALIZATION.md),
[capabilities](../../docs/CAPABILITIES.md) and the relevant
[adapter workflow](../../docs/QUICKSTARTS.md). Annotated open/erased identities
fail generation; supply a concrete identity type.
