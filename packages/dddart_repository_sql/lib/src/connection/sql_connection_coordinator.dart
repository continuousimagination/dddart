import 'dart:async';

import 'package:dddart/dddart.dart';

/// Serializes independent callers of one physical SQL connection.
///
/// Transactions own the connection in their asynchronous execution context.
/// Nested transactions join that owner and mark it rollback-only on failure,
/// even when the caller catches the inner exception. Statements within an owner
/// are also serialized. Work escaping a completed transaction is rejected.
class SqlConnectionCoordinator {
  final Object _zoneKey = Object();
  final _queue = _SerialQueue();

  _TransactionOwner? get _owner {
    final owner = Zone.current[_zoneKey] as _TransactionOwner?;
    if (owner != null && (!owner.active || !owner.accepting)) {
      throw StateError('The transaction execution context has ended');
    }
    return owner;
  }

  /// Runs one driver operation, waiting for any unrelated transaction to finish.
  Future<T> run<T>(Future<T> Function() action) async {
    final owner = _owner;
    if (owner == null) return _queue.run(action);
    return owner.commands.run(() async {
      if (!owner.active) throw StateError('The transaction has ended');
      try {
        return await action();
      } catch (_) {
        owner.rollbackOnly = true;
        rethrow;
      }
    });
  }

  /// Rejects opening/closing the connection from inside a transaction callback.
  void requireOutsideTransaction() {
    if (_owner != null) {
      throw StateError(
        'Connection lifecycle changes are not allowed in a transaction',
      );
    }
  }

  /// Defers publication until the outer transaction has committed.
  Future<void> afterCommit(Future<void> Function() action) async {
    final owner = _owner;
    if (owner == null) {
      await action();
    } else {
      owner.afterCommit.add(action);
    }
  }

  /// Owns the connection until commit/rollback completes.
  ///
  /// Driver callbacks must bypass [run]. A failed begin, failed commit, or failed
  /// rollback invalidates the physical connection; [invalidate] must close it.
  /// A failed commit has an uncertain outcome; cleanup cannot prove rollback.
  /// Other original errors are retained if cleanup also fails.
  Future<T> transaction<T>({
    required Future<T> Function() action,
    required Future<void> Function() begin,
    required Future<void> Function() commit,
    required Future<void> Function() rollback,
    required Future<void> Function() invalidate,
  }) async {
    final parent = _owner;
    if (parent != null) {
      try {
        return await action();
      } catch (_) {
        parent.rollbackOnly = true;
        rethrow;
      }
    }
    final owner = _TransactionOwner();
    final result = await _queue.run(() async {
      return runZoned(
        () async {
          var began = false;
          var committing = false;
          try {
            await begin();
            began = true;
            final result = await action();
            owner.accepting = false;
            await owner.commands.drain;
            if (owner.rollbackOnly) throw const SqlTransactionRolledBack();
            committing = true;
            await commit();
            return result;
          } catch (error) {
            owner.accepting = false;
            await owner.commands.drain;
            var broken = !began || committing;
            if (began) {
              try {
                await rollback();
              } catch (_) {
                broken = true;
              }
            }
            if (broken) {
              try {
                await invalidate();
              } catch (_) {
                // Keep the original transaction error, not a cleanup error.
              }
            }
            if (committing) {
              throw ConditionalWriteUncertainException(cause: error);
            }
            rethrow;
          } finally {
            owner.active = false;
          }
        },
        zoneValues: {_zoneKey: owner},
      );
    });
    for (final callback in owner.afterCommit) {
      await callback();
    }
    return result;
  }
}

/// An inner operation failed, so the enclosing transaction cannot commit.
class SqlTransactionRolledBack implements Exception {
  /// Creates a rollback-only transaction failure.
  const SqlTransactionRolledBack();

  @override
  String toString() =>
      'Transaction rolled back after a nested operation failed';
}

class _TransactionOwner {
  bool active = true;
  bool accepting = true;
  bool rollbackOnly = false;
  final commands = _SerialQueue();
  final afterCommit = <Future<void> Function()>[];
}

class _SerialQueue {
  Future<void>? _tail;

  Future<void> get drain => _tail ?? Future.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_tail, release.future)) _tail = null;
    }
  }
}
