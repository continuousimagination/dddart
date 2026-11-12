import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:crypto/crypto.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:idb_shim/idb.dart';

import 'transaction_error_guard_stub.dart'
    if (dart.library.js_interop) 'transaction_error_guard_web.dart'
    as native_guard;

/// Serializes one detached aggregate snapshot. Implementations must include
/// everything needed to reconstruct the aggregate, including its identity.
typedef AggregateEncoder<T extends AggregateRoot<Identity>> = String Function(
    T aggregate);

/// Reconstructs a fresh aggregate from a previously encoded snapshot.
typedef AggregateDecoder<T extends AggregateRoot<Identity>> = T Function(
    String snapshot);

/// An IndexedDB-backed implementation of dddart's basic Repository contract.
///
/// The caller supplies an [IdbFactory] so browser code can use
/// `idbFactoryNative` without a silent in-memory fallback. This class only
/// implements basic CRUD and an optional conditional transaction capability.
/// Schema upgrades preserve existing records and validate the codec before use.
class IndexedDbRepository<T extends AggregateRoot<I>, I extends Identity>
    implements Repository<T, I>, ConditionalRepository<T, I> {
  IndexedDbRepository({
    required IdbFactory factory,
    required this.databaseName,
    required this.storeName,
    required this.encode,
    required this.decode,
    IdentityCodecRegistry? identityCodecs,
    this.codecVersion = 1,
    this.maxReceipts = 100000,
  })  : _factory = factory,
        _identityCodecs = identityCodecs ?? IdentityCodecRegistry() {
    if (!_identityCodecs.contains<I>()) {
      throw ArgumentError('Register the concrete repository identity codec');
    }
    if (databaseName.isEmpty ||
        storeName.isEmpty ||
        codecVersion < 1 ||
        maxReceipts < 1) {
      throw ArgumentError('Database, store and codec version must be valid');
    }
  }

  final IdbFactory _factory;
  final IdentityCodecRegistry _identityCodecs;
  final String databaseName;
  final String storeName;
  final AggregateEncoder<T> encode;
  final AggregateDecoder<T> decode;
  final int codecVersion;

  /// Maximum durable operation receipts. Receipts are never silently pruned.
  final int maxReceipts;
  Future<Database>? _opening;
  bool _closed = false;

  Future<Database> _database() {
    if (_closed) {
      throw const RepositoryException(
        'Repository has been closed',
        type: RepositoryExceptionType.connection,
      );
    }
    return _opening ??= _openAndValidate().catchError((Object error) {
      _opening = null;
      if (error is RepositoryException) throw error;
      throw _storageFailure('open', error);
    });
  }

  Future<Database> _openAndValidate() async {
    Database? db;
    RepositoryException? upgradeFailure;
    try {
      db = await _factory.open(
        databaseName,
        version: _schemaVersion,
        onUpgradeNeeded: (event) async {
          try {
            if (!event.database.objectStoreNames.contains(storeName)) {
              if (event.oldVersion != 0) {
                throw _invalidStored('Existing database has a different store');
              }
              event.database.createObjectStore(storeName);
            }
            // The marker and version change commit together. A failed scan or
            // write aborts the upgrade, preserving the old database.
            final store = event.transaction.objectStore(storeName);
            if (event.oldVersion != 0) {
              await _validateLegacyRecords(store);
            }
            final existing = await store.getObject(_schemaKey);
            if (existing != null) {
              throw _invalidStored('Schema marker already exists');
            }
            await store.put({
              'kind': 'schema',
              'version': _schemaVersion,
              'codecVersion': codecVersion,
            }, _schemaKey);
          } catch (error) {
            upgradeFailure = error is RepositoryException
                ? error
                : _storageFailure('upgrade', error);
            try {
              event.transaction.abort();
            } catch (_) {
              // A request failure can already have aborted the transaction.
            }
          }
        },
      );
      final transaction = db.transaction(storeName, idbModeReadOnly);
      final marker = await _runCommitted(
        transaction,
        () => transaction.objectStore(storeName).getObject(_schemaKey),
      );
      if (marker is! Map ||
          marker['kind'] != 'schema' ||
          marker['version'] != _schemaVersion ||
          marker['codecVersion'] != codecVersion) {
        throw _invalidStored('Database schema or codec is incompatible');
      }
      return db;
    } catch (_) {
      db?.close();
      if (upgradeFailure != null) throw upgradeFailure!;
      rethrow;
    }
  }

  Future<void> _validateLegacyRecords(ObjectStore store) async {
    final indexedOwners = <String, String>{};
    final claimedOwners = <String, String>{};
    int? receiptCount;
    var receipts = 0;
    await for (final cursor in store.openCursor(autoAdvance: true)) {
      final key = cursor.primaryKey;
      final raw = cursor.value;
      if (key == _receiptCountKey) {
        if (raw is! Map ||
            raw.length != 2 ||
            raw['kind'] != 'receiptCount' ||
            raw['count'] is! int ||
            (raw['count'] as int) < 0) {
          throw _invalidStored('Legacy receipt count is malformed');
        }
        receiptCount = raw['count'] as int;
      } else if (key is String && key.startsWith(_receiptPrefix)) {
        if (raw is! Map || raw['digest'] is! String) {
          throw _invalidStored('Legacy receipt is malformed');
        }
        try {
          final id = UuidValue.fromString(key.substring(_receiptPrefix.length));
          _parseReceipt(raw, id, raw['digest'] as String);
        } on ArgumentError {
          throw _invalidStored('Legacy receipt ID is malformed');
        }
        receipts++;
      } else if (key is String && key.startsWith(_uniquePrefix)) {
        if (raw is! Map ||
            raw.length != 2 ||
            raw['kind'] != 'unique' ||
            raw['owner'] is! String ||
            !_validStoredUniqueKey(key)) {
          throw _invalidStored('Legacy unique index is malformed');
        }
        try {
          _idFromKey(raw['owner'] as String);
        } on ArgumentError {
          throw _invalidStored('Legacy unique owner is malformed');
        }
        indexedOwners[key] = raw['owner'] as String;
      } else {
        if (key is! String ||
            raw is! Map ||
            raw['id'] != key ||
            raw['codecVersion'] != codecVersion ||
            raw['payload'] is! String) {
          throw _invalidStored('Legacy aggregate needs explicit migration');
        }
        late final I id;
        try {
          id = _idFromKey(key);
          if (decode(raw['payload'] as String).id != id) {
            throw const FormatException('Legacy aggregate identity mismatch');
          }
        } catch (_) {
          throw _invalidStored('Legacy aggregate payload is malformed');
        }
        if (raw['managed'] == true) {
          if (raw.length != 6) {
            throw _invalidStored('Legacy conditional aggregate is malformed');
          }
          for (final uniqueKey in _storedState(raw, id).uniqueKeys) {
            if (claimedOwners.containsKey(uniqueKey)) {
              throw _invalidStored('Legacy unique value has multiple claims');
            }
            claimedOwners[uniqueKey] = key;
          }
        } else if (raw.length != 3) {
          throw _invalidStored('Legacy basic aggregate is malformed');
        }
      }
    }
    if ((receiptCount ?? 0) != receipts ||
        indexedOwners.length != claimedOwners.length ||
        indexedOwners.entries
            .any((entry) => claimedOwners[entry.key] != entry.value)) {
      throw _invalidStored('Legacy metadata does not match its records');
    }
  }

  @override
  Future<T> getById(I id) async {
    _key(id);
    final Object? stored;
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadOnly);
      stored = await _runCommitted(
        transaction,
        () => transaction.objectStore(storeName).getObject(_key(id)),
      );
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
          stored['id'] != _key(id) ||
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
    _key(aggregate.id);
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
      await _runCommitted(transaction, () async {
        final store = transaction.objectStore(storeName);
        final previous = await store.getObject(_key(aggregate.id));
        _assertBasicWritable(previous, aggregate.id);
        await store.put({
          'id': _key(aggregate.id),
          'codecVersion': codecVersion,
          'payload': payload,
        }, _key(aggregate.id));
        return null;
      });
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('save', error);
    }
  }

  @override
  Future<void> deleteById(I id) async {
    _key(id);
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadWrite);
      await _runCommitted(transaction, () async {
        final store = transaction.objectStore(storeName);
        final existing = await store.getObject(_key(id));
        if (existing == null) {
          throw RepositoryException(
            'Aggregate $id was not found',
            type: RepositoryExceptionType.notFound,
          );
        }
        _assertBasicWritable(existing, id);
        await store.delete(_key(id));
        return null;
      });
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('delete', error);
    }
  }

  @override
  Future<VersionedAggregate<T, I>> getVersioned(I id) async {
    _key(id);
    final Object? raw;
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadOnly);
      raw = await _runCommitted(
        transaction,
        () => transaction.objectStore(storeName).getObject(_key(id)),
      );
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('read versioned', error);
    }
    if (raw == null) {
      throw RepositoryException(
        'Aggregate $id was not found',
        type: RepositoryExceptionType.notFound,
      );
    }
    return _decodeVersioned(raw, id);
  }

  @override
  Future<VersionedAggregate<T, I>> findUnique(UniqueValue value) async {
    final key = _uniqueKey(value);
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadOnly);
      final result = await _runCommitted(transaction, () async {
        final store = transaction.objectStore(storeName);
        final index = await store.getObject(key);
        if (index == null) {
          throw const RepositoryException(
            'Unique value was not found',
            type: RepositoryExceptionType.notFound,
          );
        }
        if (index is! Map ||
            index['kind'] != 'unique' ||
            index['owner'] is! String) {
          throw _invalidStored('Unique index is malformed');
        }
        final owner = _idFromKey(index['owner'] as String);
        final raw = await store.getObject(_key(owner));
        if (raw == null) throw _invalidStored('Unique index owner is missing');
        if (!_storedState(raw, owner).uniqueKeys.contains(key)) {
          throw _invalidStored('Unique index is not claimed by its owner');
        }
        return _decodeVersioned(raw, owner);
      });
      return result! as VersionedAggregate<T, I>;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('find unique', error);
    }
  }

  @override
  String digestFor(ConditionalCommit<T, I> request) => _prepare(request).digest;

  @override
  Future<CommitResult<I>> commitConditional(
      ConditionalCommit<T, I> request) async {
    final prepared = _prepare(request);
    final Transaction transaction;
    try {
      final db = await _database();
      transaction = db.transaction(storeName, idbModeReadWrite);
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _storageFailure('start conditional transaction', error);
    }
    try {
      final result = await _runCommitted(
        transaction,
        () => _performConditional(transaction.objectStore(storeName), prepared),
      );
      return result! as CommitResult<I>;
    } on RepositoryException {
      rethrow;
    } catch (_) {
      // Once dispatched, a failed future is not proof of rollback. A retry
      // with the same operation ID and digest checks the durable receipt.
      return _uncertain(prepared.operationId, prepared.digest);
    }
  }

  @override
  Future<CommitResult<I>> resolveOperation(
    UuidValue operationId,
    String payloadDigest,
  ) async {
    if (payloadDigest.isEmpty) throw ArgumentError.value(payloadDigest);
    try {
      final db = await _database();
      final transaction = db.transaction(storeName, idbModeReadOnly);
      final raw = await _runCommitted(
        transaction,
        () => transaction
            .objectStore(storeName)
            .getObject(_receiptKey(operationId)),
      );
      if (raw == null) return _uncertain(operationId, payloadDigest);
      return _parseReceipt(raw, operationId, payloadDigest);
    } on RepositoryException catch (error) {
      if (error.type == RepositoryExceptionType.constraint) rethrow;
      return _uncertain(operationId, payloadDigest);
    } catch (_) {
      return _uncertain(operationId, payloadDigest);
    }
  }

  _PreparedCommit<I> _prepare(ConditionalCommit<T, I> request) {
    if (request.mutations.isEmpty || request.mutations.length > 32) {
      throw ArgumentError('A commit needs 1 to 32 mutations');
    }
    final mutations = <_PreparedMutation<I>>[];
    final ids = <String>{};
    for (final mutation in request.mutations) {
      if (!ids.add(_key(mutation.id))) {
        throw ArgumentError('Duplicate aggregate ID in one commit');
      }
      if (mutation.isDelete && mutation.expected.isAbsent) {
        throw ArgumentError('Delete requires a matching revision');
      }
      if (mutation.uniqueValues.length > 16) {
        throw ArgumentError('Too many unique values for one aggregate');
      }
      final uniqueKeys = <String>{};
      for (final value in mutation.uniqueValues) {
        if (!uniqueKeys.add(_uniqueKey(value))) {
          throw ArgumentError('Duplicate unique value in one aggregate');
        }
      }
      String? payload;
      if (!mutation.isDelete) {
        final aggregate = mutation.aggregate;
        if (aggregate == null || aggregate.id != mutation.id) {
          throw ArgumentError('Put aggregate identity changed');
        }
        try {
          payload = encode(aggregate);
        } catch (error) {
          throw RepositoryException(
            'Aggregate ${mutation.id} could not be encoded',
            type: RepositoryExceptionType.constraint,
            cause: error,
          );
        }
        if (utf8.encode(payload).length > 1048576) {
          throw ArgumentError('Encoded aggregate exceeds 1 MiB');
        }
      }
      mutations.add(_PreparedMutation(
        mutation.id,
        mutation.expected.revision,
        payload,
        uniqueKeys.toList()..sort(),
      ));
    }
    mutations.sort((a, b) => _key(a.id).compareTo(_key(b.id)));
    final encoded = jsonEncode([
      codecVersion,
      for (final mutation in mutations)
        [
          _key(mutation.id),
          mutation.expectedRevision,
          mutation.payload,
          mutation.uniqueKeys,
        ],
    ]);
    return _PreparedCommit(
      request.operationId,
      sha256.convert(utf8.encode(encoded)).toString(),
      mutations,
    );
  }

  Future<Object?> _performConditional(
    ObjectStore store,
    _PreparedCommit<I> request,
  ) async {
    final existingReceipt =
        await store.getObject(_receiptKey(request.operationId));
    if (existingReceipt != null) {
      return _parseReceipt(
          existingReceipt, request.operationId, request.digest);
    }
    final countRaw = await store.getObject(_receiptCountKey);
    final count = switch (countRaw) {
      null => 0,
      {'kind': 'receiptCount', 'count': int value} when value >= 0 => value,
      _ => throw _invalidStored('Receipt count is malformed'),
    };
    if (count >= maxReceipts) {
      throw const RepositoryException(
        'Operation receipt capacity reached',
        type: RepositoryExceptionType.constraint,
      );
    }

    final currentRaw = await Future.wait(
      [
        for (final mutation in request.mutations)
          store.getObject(_key(mutation.id))
      ],
    );
    final current = <String, _StoredState?>{};
    for (var i = 0; i < request.mutations.length; i++) {
      final mutation = request.mutations[i];
      final raw = currentRaw[i];
      if (mutation.expectedRevision == null && raw != null ||
          mutation.expectedRevision != null && raw == null) {
        return _writeReceipt(
          store,
          count,
          _rejected(request, CommitRejection.staleRevision),
        );
      }
      if (raw != null) {
        final state = _storedState(raw, mutation.id);
        if (mutation.expectedRevision != state.revision) {
          return _writeReceipt(
            store,
            count,
            _rejected(request, CommitRejection.staleRevision),
          );
        }
        current[_key(mutation.id)] = state;
      } else {
        current[_key(mutation.id)] = null;
      }
    }

    final desiredOwners = <String, String>{};
    final currentOwners = <String, String>{};
    final releasedOwners = <String, String>{};
    for (final mutation in request.mutations) {
      final oldKeys =
          current[_key(mutation.id)]?.uniqueKeys ?? const <String>[];
      for (final key in oldKeys) {
        if (currentOwners.containsKey(key) &&
            currentOwners[key] != _key(mutation.id)) {
          throw _invalidStored('Unique value has multiple stored owners');
        }
        currentOwners[key] = _key(mutation.id);
        if (!mutation.uniqueKeys.contains(key)) {
          releasedOwners[key] = _key(mutation.id);
        }
      }
      for (final key in mutation.uniqueKeys) {
        final previous = desiredOwners[key];
        if (previous != null && previous != _key(mutation.id)) {
          return _writeReceipt(
            store,
            count,
            _rejected(request, CommitRejection.uniqueConflict),
          );
        }
        desiredOwners[key] = _key(mutation.id);
      }
    }
    final keys = {...currentOwners.keys, ...desiredOwners.keys}.toList()
      ..sort();
    final indexRaw =
        await Future.wait([for (final key in keys) store.getObject(key)]);
    final owners = <String, String?>{};
    for (var i = 0; i < keys.length; i++) {
      final raw = indexRaw[i];
      if (raw == null) {
        owners[keys[i]] = null;
      } else if (raw is Map &&
          raw['kind'] == 'unique' &&
          raw['owner'] is String) {
        owners[keys[i]] = raw['owner'] as String;
      } else {
        throw _invalidStored('Unique index is malformed');
      }
    }
    for (final entry in currentOwners.entries) {
      if (owners[entry.key] != entry.value) {
        throw _invalidStored('Unique index owner does not match aggregate');
      }
    }
    for (final entry in desiredOwners.entries) {
      final holder = owners[entry.key];
      if (holder != null &&
          holder != entry.value &&
          releasedOwners[entry.key] != holder) {
        return _writeReceipt(
          store,
          count,
          _rejected(request, CommitRejection.uniqueConflict),
        );
      }
    }

    final revisions = <I, String>{};
    final writes = <Future<Object?>>[];
    for (final key in releasedOwners.keys) {
      writes.add(store.delete(key));
    }
    for (final entry in desiredOwners.entries) {
      writes
          .add(store.put({'kind': 'unique', 'owner': entry.value}, entry.key));
    }
    for (final mutation in request.mutations) {
      if (mutation.payload == null) {
        writes.add(store.delete(_key(mutation.id)));
      } else {
        final revision = UuidValue.generate().uuid;
        revisions[mutation.id] = revision;
        writes.add(store.put({
          'id': _key(mutation.id),
          'codecVersion': codecVersion,
          'payload': mutation.payload,
          'managed': true,
          'revision': revision,
          'uniqueKeys': mutation.uniqueKeys,
        }, _key(mutation.id)));
      }
    }
    final result = CommitResult<I>(
      operationId: request.operationId,
      payloadDigest: request.digest,
      decision: CommitDecision.committed,
      revisions: Map<I, String>.unmodifiable(revisions),
    );
    await Future.wait(writes);
    return _writeReceipt(store, count, result);
  }

  Future<Object?> _writeReceipt(
    ObjectStore store,
    int previousCount,
    CommitResult<I> result,
  ) async {
    await Future.wait([
      store.put({
        'kind': 'receipt',
        'digest': result.payloadDigest,
        'decision': result.decision.name,
        'rejection': result.rejection?.name,
        'revisions': {
          for (final entry in result.revisions.entries)
            _key(entry.key): entry.value,
        },
      }, _receiptKey(result.operationId)),
      store.put({'kind': 'receiptCount', 'count': previousCount + 1},
          _receiptCountKey),
    ]);
    return result;
  }

  CommitResult<I> _parseReceipt(
      Object raw, UuidValue operationId, String digest) {
    if (raw is! Map ||
        raw.length != 5 ||
        raw['kind'] != 'receipt' ||
        raw['digest'] is! String ||
        (raw['digest'] as String).isEmpty) {
      throw _invalidStored('Operation receipt is malformed');
    }
    if (raw['digest'] != digest) {
      throw const RepositoryException(
        'Operation ID was reused with different payload',
        type: RepositoryExceptionType.constraint,
      );
    }
    final decisionName = raw['decision'];
    final rejectionName = raw['rejection'];
    if (decisionName is! String ||
        !{'committed', 'rejected'}.contains(decisionName) ||
        (decisionName == 'committed' && rejectionName != null) ||
        (decisionName == 'rejected' &&
            (rejectionName is! String ||
                !{'staleRevision', 'uniqueConflict'}
                    .contains(rejectionName)))) {
      throw _invalidStored('Operation receipt outcome is malformed');
    }
    final decision = CommitDecision.values.byName(decisionName);
    final rejection = rejectionName == null
        ? null
        : CommitRejection.values.byName(rejectionName as String);
    final encodedVersions = raw['revisions'];
    if (encodedVersions is! Map) {
      throw _invalidStored('Operation receipt revisions are malformed');
    }
    final revisions = <I, String>{};
    for (final entry in encodedVersions.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          (entry.value as String).isEmpty) {
        throw _invalidStored('Operation receipt revisions are malformed');
      }
      try {
        revisions[_idFromKey(entry.key as String)] = entry.value as String;
      } on ArgumentError {
        throw _invalidStored('Operation receipt revisions are malformed');
      }
    }
    if (decision == CommitDecision.rejected && revisions.isNotEmpty) {
      throw _invalidStored('Rejected operation has revisions');
    }
    return CommitResult<I>(
      operationId: operationId,
      payloadDigest: digest,
      decision: decision,
      rejection: rejection,
      revisions: Map<I, String>.unmodifiable(revisions),
    );
  }

  _StoredState _storedState(Object raw, I id) {
    if (raw is! Map ||
        raw['id'] != _key(id) ||
        raw['codecVersion'] != codecVersion ||
        raw['payload'] is! String ||
        raw['managed'] != true ||
        raw['revision'] is! String ||
        (raw['revision'] as String).isEmpty ||
        raw['uniqueKeys'] is! List) {
      throw _invalidStored(
          'Conditional aggregate is malformed or needs migration');
    }
    final keys = raw['uniqueKeys'] as List;
    if (keys.any((key) => key is! String || !_validStoredUniqueKey(key)) ||
        keys.toSet().length != keys.length) {
      throw _invalidStored('Conditional aggregate unique values are malformed');
    }
    return _StoredState(raw['revision'] as String, List<String>.from(keys));
  }

  VersionedAggregate<T, I> _decodeVersioned(Object raw, I id) {
    final state = _storedState(raw, id);
    try {
      final aggregate = decode((raw as Map)['payload'] as String);
      if (aggregate.id != id) throw const FormatException('Identity mismatch');
      return VersionedAggregate(aggregate, state.revision);
    } catch (error) {
      throw RepositoryException(
        'Aggregate $id could not be decoded',
        type: RepositoryExceptionType.constraint,
        cause: error,
      );
    }
  }

  void _assertBasicWritable(Object? raw, I id) {
    if (raw == null) return;
    if (raw is! Map ||
        raw.length != 3 ||
        raw['id'] != _key(id) ||
        raw['codecVersion'] != codecVersion ||
        raw['payload'] is! String ||
        raw.containsKey('managed') ||
        raw.containsKey('revision') ||
        raw.containsKey('uniqueKeys')) {
      throw _invalidStored(
          'Stored aggregate is managed, malformed, or needs migration');
    }
    try {
      if (decode(raw['payload'] as String).id != id) {
        throw const FormatException('Stored aggregate identity mismatch');
      }
    } catch (error) {
      throw RepositoryException(
        'Stored aggregate cannot be safely replaced or deleted',
        type: RepositoryExceptionType.constraint,
        cause: error,
      );
    }
  }

  String _uniqueKey(UniqueValue value) {
    if (value.index.isEmpty ||
        value.index.length > 256 ||
        value.value.length > 256) {
      throw ArgumentError(
          'Unique index and value must be at most 256 characters');
    }
    return '$_uniquePrefix${base64Url.encode(utf8.encode(jsonEncode([
          value.index,
          value.value,
        ])))}';
  }

  bool _validStoredUniqueKey(String key) {
    if (!key.startsWith(_uniquePrefix)) return false;
    try {
      final decoded = jsonDecode(
          utf8.decode(base64Url.decode(key.substring(_uniquePrefix.length))));
      if (decoded is! List ||
          decoded.length != 2 ||
          decoded[0] is! String ||
          decoded[1] is! String) {
        return false;
      }
      return _uniqueKey(
              UniqueValue(decoded[0] as String, decoded[1] as String)) ==
          key;
    } catch (_) {
      return false;
    }
  }

  // Keep the reviewed UUID storage format intact. Other concrete identity
  // kinds use an injective namespace, disjoint from UUIDs and metadata keys.
  String _key(I id) {
    try {
      final key = _identityCodecs.toKey<I>(id);
      if (utf8.decode(utf8.encode(key)) != key) {
        throw const FormatException('Identity key is not lossless UTF-8');
      }
      if (I == UuidValue) return key;
      final tag = _identityCodecs.toTaggedKey(id);
      return '$_aggregatePrefix${base64Url.encode(utf8.encode(jsonEncode([
            tag['type'],
            key,
          ])))}';
    } catch (error) {
      throw RepositoryException(
        'Invalid aggregate identity key',
        type: RepositoryExceptionType.constraint,
        cause: error,
      );
    }
  }

  I _idFromKey(String storedKey) {
    try {
      final String key;
      if (I == UuidValue) {
        key = storedKey;
      } else {
        if (!storedKey.startsWith(_aggregatePrefix)) {
          throw const FormatException('Identity kind needs explicit migration');
        }
        final tag = jsonDecode(utf8.decode(base64Url.decode(
          storedKey.substring(_aggregatePrefix.length),
        )));
        if (tag is! List || tag.length != 2 || tag[1] is! String) {
          throw const FormatException('Malformed identity key');
        }
        key = tag[1] as String;
      }
      final id = _identityCodecs.fromKey<I>(key);
      if (_key(id) != storedKey) {
        throw const FormatException('Noncanonical identity key or kind');
      }
      return id;
    } catch (_) {
      throw _invalidStored('Stored identity key is malformed or incompatible');
    }
  }

  String _receiptKey(UuidValue id) => '$_receiptPrefix${id.uuid}';

  CommitResult<I> _rejected(
          _PreparedCommit<I> request, CommitRejection reason) =>
      CommitResult<I>(
        operationId: request.operationId,
        payloadDigest: request.digest,
        decision: CommitDecision.rejected,
        rejection: reason,
      );

  CommitResult<I> _uncertain(UuidValue id, String digest) => CommitResult<I>(
        operationId: id,
        payloadDigest: digest,
        decision: CommitDecision.uncertain,
      );

  RepositoryException _invalidStored(String message) => RepositoryException(
        message,
        type: RepositoryExceptionType.constraint,
      );

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final opening = _opening;
    if (opening != null) (await opening).close();
  }

  /// Attach the completion error handler before issuing the first request.
  /// A failed request can also abort its transaction, yielding two separate
  /// failed futures. A failed request setup may leave earlier writes queued,
  /// so this aborts explicitly and observes both outcomes before returning.
  Future<Object?> _runCommitted(
    Transaction transaction,
    Future<Object?> Function() action,
  ) async {
    final completionFuture = transaction.completed;
    native_guard.guardNativeTransactionError(transaction);
    final completion = completionFuture.then<AsyncError?>(
      (_) => null,
      onError: (Object error, StackTrace stack) => AsyncError(error, stack),
    );
    Object? result;
    AsyncError? actionFailure;
    var abortRequested = false;
    try {
      result = await action();
    } catch (error, stack) {
      actionFailure = AsyncError(error, stack);
      // A failed request setup need not abort IndexedDB automatically. Abort
      // before any queued writes can commit without their receipt.
      try {
        transaction.abort();
        abortRequested = true;
      } catch (_) {
        // It may already have aborted or committed; completion decides whether
        // the caller can treat this as a confirmed failure.
      }
    }
    final commitFailure = await completion;
    if (actionFailure != null) {
      if (abortRequested && commitFailure != null) {
        Error.throwWithStackTrace(
            actionFailure.error, actionFailure.stackTrace);
      }
      if (commitFailure == null) {
        throw StateError(
          'Transaction completed after its action failed: ${actionFailure.error}',
        );
      }
    }
    if (commitFailure != null) {
      Error.throwWithStackTrace(commitFailure.error, commitFailure.stackTrace);
    }
    return result;
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

const _aggregatePrefix = '__dddart_aggregate__';
const _uniquePrefix = '__dddart_unique__';
const _receiptPrefix = '__dddart_receipt__';
const _receiptCountKey = '__dddart_receipt_count__';
const _schemaKey = '__dddart_schema__';
const _schemaVersion = 2;

final class _PreparedCommit<I extends Identity> {
  const _PreparedCommit(this.operationId, this.digest, this.mutations);

  final UuidValue operationId;
  final String digest;
  final List<_PreparedMutation<I>> mutations;
}

final class _PreparedMutation<I extends Identity> {
  const _PreparedMutation(
    this.id,
    this.expectedRevision,
    this.payload,
    this.uniqueKeys,
  );

  final I id;
  final String? expectedRevision;
  final String? payload;
  final List<String> uniqueKeys;
}

final class _StoredState {
  const _StoredState(this.revision, this.uniqueKeys);

  final String revision;
  final List<String> uniqueKeys;
}
