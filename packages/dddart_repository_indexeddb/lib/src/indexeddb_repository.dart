import 'package:dddart/dddart.dart';
import 'package:idb_shim/idb.dart';

/// Serializes one detached aggregate snapshot. Implementations must include
/// everything needed to reconstruct the aggregate, including its identity.
typedef AggregateEncoder<T extends AggregateRoot> = String Function(
    T aggregate);

/// Reconstructs a fresh aggregate from a previously encoded snapshot.
typedef AggregateDecoder<T extends AggregateRoot> = T Function(String snapshot);

/// An IndexedDB-backed implementation of dddart's basic Repository contract.
///
/// The caller supplies an [IdbFactory] so browser code can use
/// `idbFactoryNative` without a silent in-memory fallback. This class only
/// implements basic CRUD. Conditional revisions, multi-record transactions,
/// operation receipts, and migration fences require a separate contract.
class IndexedDbRepository<T extends AggregateRoot> implements Repository<T> {
  IndexedDbRepository({
    required IdbFactory factory,
    required this.databaseName,
    required this.storeName,
    required this.encode,
    required this.decode,
    this.codecVersion = 1,
  }) : _factory = factory {
    if (databaseName.isEmpty || storeName.isEmpty || codecVersion < 1) {
      throw ArgumentError('Database, store and codec version must be valid');
    }
  }

  final IdbFactory _factory;
  final String databaseName;
  final String storeName;
  final AggregateEncoder<T> encode;
  final AggregateDecoder<T> decode;
  final int codecVersion;
  Future<Database>? _opening;
  bool _closed = false;

  Future<Database> _database() {
    if (_closed) {
      throw const RepositoryException(
        'Repository has been closed',
        type: RepositoryExceptionType.connection,
      );
    }
    return _opening ??= _factory.open(
      databaseName,
      version: 1,
      onUpgradeNeeded: (event) {
        if (!event.database.objectStoreNames.contains(storeName)) {
          event.database.createObjectStore(storeName);
        }
      },
    ).catchError((Object error) {
      _opening = null;
      throw _storageFailure('open', error);
    });
  }

  @override
  Future<T> getById(UuidValue id) async {
    final Object? stored;
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadOnly);
      final committed = transaction.completed;
      stored = await transaction.objectStore(storeName).getObject(id.uuid);
      await committed;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('read', error);
    }
    if (stored == null) {
      throw RepositoryException(
        'Aggregate $id was not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    try {
      if (stored is! Map ||
          stored['id'] != id.uuid ||
          stored['codecVersion'] != codecVersion ||
          stored['payload'] is! String) {
        throw const FormatException('Invalid stored aggregate envelope');
      }
      final aggregate = decode(stored['payload'] as String);
      if (aggregate.id != id) {
        throw const FormatException('Stored aggregate identity mismatch');
      }
      return aggregate;
    } catch (error) {
      throw RepositoryException(
        'Aggregate $id could not be decoded',
        type: RepositoryExceptionType.constraint,
        cause: error,
      );
    }
  }

  @override
  Future<void> save(T aggregate) async {
    final String payload;
    try {
      payload = encode(aggregate);
    } catch (error) {
      throw RepositoryException(
        'Aggregate ${aggregate.id} could not be encoded',
        type: RepositoryExceptionType.constraint,
        cause: error,
      );
    }
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadWrite);
      final committed = transaction.completed;
      await transaction.objectStore(storeName).put({
        'id': aggregate.id.uuid,
        'codecVersion': codecVersion,
        'payload': payload,
      }, aggregate.id.uuid);
      await committed;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('save', error);
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadWrite);
      final committed = transaction.completed;
      final store = transaction.objectStore(storeName);
      final existing = await store.getObject(id.uuid);
      if (existing == null) {
        await committed;
        throw RepositoryException(
          'Aggregate $id was not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      await store.delete(id.uuid);
      await committed;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('delete', error);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final opening = _opening;
    if (opening != null) (await opening).close();
  }

  RepositoryException _storageFailure(String operation, Object error) {
    final description = error.toString();
    final type = description.contains('ConstraintError')
        ? RepositoryExceptionType.duplicate
        : description.contains('DataError')
            ? RepositoryExceptionType.constraint
            : RepositoryExceptionType.connection;
    return RepositoryException(
      'IndexedDB $operation failed',
      type: type,
      cause: error,
    );
  }
}
