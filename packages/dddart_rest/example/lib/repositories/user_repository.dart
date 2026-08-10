import 'package:dddart/dddart.dart';

import '../models/user.dart';

/// One page returned by the example's explicit user read operations.
final class UserPage {
  const UserPage(this.items, {required this.totalCount});

  final List<User> items;
  final int totalCount;
}

/// Application-specific persistence contract for user collection reads.
abstract interface class UserRepository implements Repository<User> {
  Future<UserPage> list({required int skip, required int take});

  Future<UserPage> findByFirstName(
    String firstName, {
    required int skip,
    required int take,
  });

  Future<UserPage> findByEmail(
    String email, {
    required int skip,
    required int take,
  });
}

/// Instance-local user repository for this runnable example.
final class InMemoryUserRepository extends InMemoryRepository<User>
    implements UserRepository {
  @override
  Future<UserPage> list({required int skip, required int take}) async {
    return _page(getAllSync(), skip: skip, take: take);
  }

  @override
  Future<UserPage> findByFirstName(
    String firstName, {
    required int skip,
    required int take,
  }) async {
    final matches = getAllSync().where(
      (user) => user.firstName.toLowerCase() == firstName.toLowerCase(),
    );
    return _page(matches, skip: skip, take: take);
  }

  @override
  Future<UserPage> findByEmail(
    String email, {
    required int skip,
    required int take,
  }) async {
    final matches = getAllSync().where(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
    return _page(matches, skip: skip, take: take);
  }

  UserPage _page(
    Iterable<User> matchingUsers, {
    required int skip,
    required int take,
  }) {
    final matches = matchingUsers.toList(growable: false);
    return UserPage(
      List.unmodifiable(matches.skip(skip).take(take)),
      totalCount: matches.length,
    );
  }
}
