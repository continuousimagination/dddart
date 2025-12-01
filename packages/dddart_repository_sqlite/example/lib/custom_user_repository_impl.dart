/// Implementation of custom repository methods.
library;

import 'package:dddart/dddart.dart';

import 'custom_user.dart';

/// Concrete implementation of CustomUserRepository.
///
/// Extends the generated abstract base class and implements
/// custom query methods by leveraging the base repository's
/// getById method and filtering in memory.
///
/// Note: In a real application with large datasets, you would
/// want to implement these queries using raw SQL for better
/// performance. This example uses a simpler approach for
/// demonstration purposes.
class CustomUserRepositoryImpl extends CustomUserSqliteRepositoryBase {
  /// Creates a custom user repository implementation.
  CustomUserRepositoryImpl(super.connection);

  // Cache of all users for filtering
  final _userCache = <UuidValue, CustomUser>{};

  @override
  Future<List<CustomUser>> findActiveUsers() async {
    // In a real implementation, this would use a SQL query:
    // SELECT * FROM custom_users WHERE isActive = 1 ORDER BY name
    //
    // For this example, we'll use a workaround since we can't access
    // the protected members directly.

    // This is a simplified implementation that demonstrates the concept
    // In production, you would implement proper SQL queries
    final allUsers = _userCache.values.toList();
    return allUsers.where((u) => u.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<CustomUser>> findByEmailPattern(String pattern) async {
    // In a real implementation:
    // SELECT * FROM custom_users WHERE email LIKE ? ORDER BY email
    final allUsers = _userCache.values.toList();
    return allUsers.where((u) => u.email.contains(pattern)).toList()
      ..sort((a, b) => a.email.compareTo(b.email));
  }

  @override
  Future<int> countUsers() async {
    // In a real implementation:
    // SELECT COUNT(*) as count FROM custom_users
    return _userCache.length;
  }

  @override
  Future<List<CustomUser>> findRegisteredAfter(DateTime date) async {
    // In a real implementation:
    // SELECT * FROM custom_users WHERE registeredAt > ? ORDER BY registeredAt
    final allUsers = _userCache.values.toList();
    return allUsers.where((u) => u.registeredAt.isAfter(date)).toList()
      ..sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
  }

  // Override save to maintain cache
  @override
  Future<void> save(CustomUser aggregate) async {
    await super.save(aggregate);
    _userCache[aggregate.id] = aggregate;
  }

  // Override deleteById to maintain cache
  @override
  Future<void> deleteById(UuidValue id) async {
    await super.deleteById(id);
    _userCache.remove(id);
  }

  // Override getById to maintain cache
  @override
  Future<CustomUser> getById(UuidValue id) async {
    final user = await super.getById(id);
    _userCache[id] = user;
    return user;
  }
}
