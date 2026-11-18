import 'package:dddart/dddart.dart';

import 'lib/user_aggregate.dart';
import 'lib/user_registered_event.dart';

/// Two listeners react independently to a single registration.
Future<void> main() async {
  final users = InMemoryRepository<UserAggregate, UuidValue>();
  final bus = EventBus();
  try {
    final registrations = bus.on<UserRegisteredEvent>();
    final welcome = registrations.first.then(
      (event) => print('Welcome, ${event.fullName}!'),
    );
    final membership = registrations.first.then(
      (event) => print('Member registered in ${event.organizationId}'),
    );

    final user = UserAggregate.register(
      email: 'sam@example.com',
      fullName: 'Sam',
      organizationId: 'book-club',
    );
    final pending = user.captureUncommittedEvents();
    await users.save(user);
    for (final event in pending.events) {
      bus.publish(event);
      pending.acknowledge(event);
    }
    await Future.wait([welcome, membership]);
  } finally {
    await bus.close();
  }
}
