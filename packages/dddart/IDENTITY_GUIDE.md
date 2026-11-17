# Typed identity and UUID migration

Entity and aggregate identity is explicit and domain typed. Extend Identity to
define an immutable native string or scoped/composite identifier. UuidValue is
the supplied UUID implementation; an externally identified entity never receives
a generated UUID implicitly.

## Externally assigned identity

```dart
import 'package:dddart/dddart.dart';

class GitHubIssueId extends Identity {
  const GitHubIssueId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}

class GitHubIssue extends AggregateRoot<GitHubIssueId> {
  GitHubIssue({required super.id, required this.title});
  final String title;
}

class IssueImported extends DomainEvent<GitHubIssueId> {
  IssueImported({required super.aggregateId});
}

Future<void> example() async {
  final issue = GitHubIssue(
    id: const GitHubIssueId('github-assigned-native-id'),
    title: 'Support native identities',
  );
  final Repository<GitHubIssue, GitHubIssueId> repository =
      InMemoryRepository<GitHubIssue, GitHubIssueId>();
  await repository.save(issue);
  final loaded = await repository.getById(issue.id);
  loaded.raiseEvent(IssueImported(aggregateId: loaded.id));
  await repository.deleteById(loaded.id);
}
```

GitHub identity validation and whether to use a global identifier or a scoped
number are application choices. Dddart does not assign GitHub IDs or store a UUID
translation table. Repositories manage aggregate roots; nested Entity instances
stay within their aggregate's persistence boundary.

## Scoped and composite identities

```dart
class ScopedIssueId extends Identity {
  const ScopedIssueId(this.owner, this.repository, this.number);
  final String owner;
  final String repository;
  final int number;

  @override
  List<Object?> get props => [owner, repository, number];
}
```

Include every scope component in props. Issue number 12 in two repositories
then represents different identities. Identity inherits Value's runtime-kind
and structural-property equality/hash semantics: unrelated identity classes
are unequal even when their text matches. Keep fields and nested properties
immutable; changing equality properties after insertion into a map/set would
invalidate its key semantics. Unequal identities may have equal hash codes.

The concrete identity type is retained by Entity<I>, AggregateRoot<I>,
Repository<T, I>, InMemoryRepository<T, I> and DomainEvent<I>. The repository
bound requires T to extend AggregateRoot<I>. A repository for GitHubIssueId
rejects another identity kind at compilation, as do typed aggregate events.

## Existing UUID consumers

Use `Entity<UuidValue>` for UUID entities and `AggregateRoot<UuidValue>` for
UUID aggregates. Both require an ID, just like any other identity type:

```dart
class User extends AggregateRoot<UuidValue> {
  User({required super.id, super.createdAt, super.updatedAt});
}

final user = User(id: UuidValue.generate());
final sameIdentity = User(id: user.id);
final repository = InMemoryRepository<User, UuidValue>();
```

If a domain model should generate UUIDs, put that policy in its constructor:

```dart
class User extends AggregateRoot<UuidValue> {
  User({UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
}
```

`UuidValue.generate()` creates a UUID and `UuidValue.fromString()` validates an
existing UUID. The UUID representation and validation behavior remain available;
there are no UUID-specific entity or aggregate base classes.

UUID event subclasses now extend DomainEvent<UuidValue>. An event referring to a
native identity instead extends DomainEvent<ThatIdentity>; its own eventId still
uses UuidValue. One EventBus can carry events for different identity kinds and
subscriptions can select a concrete event type.

Changes to existing signatures:

| Before | After for a UUID consumer |
| --- | --- |
| Entity with implicit UUID | `Entity<UuidValue>` with an explicit ID |
| AggregateRoot with implicit UUID | `AggregateRoot<UuidValue>` with an explicit ID |
| Repository<User> | Repository<User, UuidValue> |
| InMemoryRepository<User> | InMemoryRepository<User, UuidValue> |
| DomainEvent | DomainEvent<UuidValue> |

General Entity<I>/AggregateRoot<I> creation requires id. Their timestamps,
mutable updatedAt/touch() behavior, aggregate event collection, repository
upsert semantics and missing-key exceptions retain their existing roles.
InMemoryRepository is an instance-local fake; its enumeration helpers do not
add collection queries to the Repository contract or prove database behavior.

## Storage and serialization

Identity defines domain equality, not an arbitrary string storage format.
Boundary codecs must explicitly encode/decode identities and preserve kind and
scope. Do not serialize toString() and assume the result is a UUID, concatenate
composite components ambiguously, or silently hash an external ID into a UUID.

Serializer/generator and adapter migration is tracked in #40–#44. A core type
test is not proof that a particular database, HTTP route or distributed event
format supports a custom identity. Each boundary must compile generated
consumers and prove the supported round-trips and database key equality.
