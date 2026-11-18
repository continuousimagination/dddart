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

class DeliveryId extends Identity {
  const DeliveryId(this.source, this.sequence);
  final String source;
  final int sequence;

  @override
  List<Object?> get props => [source, sequence];
}

class IssueImported extends DomainEvent<IssueId, DeliveryId> {
  IssueImported({required super.aggregateId, required super.eventId});
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
  final imported = IssueImported(
    aggregateId: loaded.id,
    eventId: const DeliveryId('tracker', 42),
  );
  loaded.raiseEvent(imported);
  print('${imported.eventId.source}:${imported.eventId.sequence}');
}
