import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/device_code.dart';
import 'package:dddart_rest/src/device_code_lifecycle.dart';

/// Persistence contract for device authorization grants.
///
/// The grant-specific lookup methods avoid requiring full repository
/// enumeration. [consumeApproved] is the consistency boundary that makes a
/// device grant single-use.
abstract interface class DeviceCodeRepository<T extends DeviceCode>
    implements Repository<T> {
  /// Finds a device code by its human-readable user code.
  Future<T?> findByUserCode(String userCode);

  /// Finds a device code by its opaque device code.
  Future<T?> findByDeviceCode(String deviceCode);

  /// Atomically consumes one approved device grant.
  ///
  /// A successful operation must atomically match the opaque [deviceCode], the
  /// stored [clientId], `DeviceCodeStatus.approved`, a non-null user ID, and a
  /// grant that is not expired at [consumedAt]. It must persist a transition to
  /// `DeviceCodeStatus.consumed`, update the lifecycle timestamp, preserve the
  /// concrete type [T] and its subtype state, and return that consumed value.
  ///
  /// Returns `null` without mutation when any condition does not match. This
  /// operation must not be implemented as an ordinary read followed by
  /// [Repository.save], because that permits concurrent callers to succeed.
  Future<T?> consumeApproved({
    required String deviceCode,
    required String clientId,
    required DateTime consumedAt,
  });
}

/// Instance-local in-memory implementation of [DeviceCodeRepository].
///
/// This implementation is intended for examples and tests. It owns its storage
/// so the approved-to-consumed check and replacement happen synchronously in one
/// method invocation, before the returned [Future] completes.
final class InMemoryDeviceCodeRepository<T extends DeviceCode>
    implements DeviceCodeRepository<T>, QueryableRepository<T> {
  /// Creates an empty repository using [lifecycle] for the typed consume
  /// transition.
  InMemoryDeviceCodeRepository({
    required DeviceCodeLifecycle<T> lifecycle,
  }) : _lifecycle = lifecycle;

  final DeviceCodeLifecycle<T> _lifecycle;
  final Map<UuidValue, T> _storage = {};

  @override
  Future<T> getById(UuidValue id) {
    final aggregate = _storage[id];
    if (aggregate == null) {
      return Future.error(
        RepositoryException(
          'Aggregate with ID $id not found',
          type: RepositoryExceptionType.notFound,
        ),
      );
    }
    return Future.value(aggregate);
  }

  @override
  Future<void> save(T aggregate) {
    _storage[aggregate.id] = aggregate;
    return Future.value();
  }

  @override
  Future<void> deleteById(UuidValue id) {
    if (!_storage.containsKey(id)) {
      return Future.error(
        RepositoryException(
          'Aggregate with ID $id not found',
          type: RepositoryExceptionType.notFound,
        ),
      );
    }
    _storage.remove(id);
    return Future.value();
  }

  @override
  Future<T?> findByUserCode(String userCode) {
    for (final code in _storage.values) {
      if (code.userCode == userCode) {
        return Future.value(code);
      }
    }
    return Future.value();
  }

  @override
  Future<T?> findByDeviceCode(String deviceCode) {
    for (final code in _storage.values) {
      if (code.deviceCode == deviceCode) {
        return Future.value(code);
      }
    }
    return Future.value();
  }

  @override
  Future<T?> consumeApproved({
    required String deviceCode,
    required String clientId,
    required DateTime consumedAt,
  }) {
    T? approved;
    for (final code in _storage.values) {
      if (code.deviceCode == deviceCode && code.clientId == clientId) {
        approved = code;
        break;
      }
    }

    if (approved == null ||
        approved.status != DeviceCodeStatus.approved ||
        approved.userId == null ||
        consumedAt.isAfter(approved.expiresAt)) {
      return Future.value();
    }

    final consumed = _lifecycle.consume(
      approved,
      consumedAt: consumedAt,
    );
    _storage[consumed.id] = consumed;
    return Future.value(consumed);
  }

  @override
  Future<List<T>> getAll() => Future.value(getAllSync());

  /// Returns an unmodifiable snapshot of all stored device codes.
  List<T> getAllSync() => List.unmodifiable(_storage.values);

  /// Removes all stored device codes.
  void clear() => _storage.clear();
}
