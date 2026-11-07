import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/event_publisher.dart';
import 'package:dddart/src/identity.dart';
import 'package:dddart/src/repository.dart';
import 'package:dddart/src/save_with_events.dart';

/// Adds pending-event publication to an existing basic repository.
///
/// The wrapped repository is responsible for persistence only; do not configure
/// it to publish the same events a second time. Custom repository implementations
/// can use [saveWithEvents] directly to preserve their additional query methods.
class EventPublishingRepository<T extends AggregateRoot<I>, I extends Identity>
    implements Repository<T, I> {
  /// Wraps [repository] with the common save/publication lifecycle.
  EventPublishingRepository({
    required this.repository,
    required this.publisher,
  });

  /// The underlying persistence implementation.
  final Repository<T, I> repository;

  /// The shared publisher owning retries and publication failure logging.
  final EventPublisher publisher;

  @override
  Future<T> getById(I id) => repository.getById(id);

  @override
  Future<void> deleteById(I id) => repository.deleteById(id);

  @override
  Future<void> save(T aggregate) => saveWithEvents(
        aggregate: aggregate,
        persist: () => repository.save(aggregate),
        publisher: publisher,
      );
}
