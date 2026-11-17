import 'dart:js_interop';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/native_web/indexed_db_web.dart' as idb;
import 'package:idb_shim/src/native_web/native_transaction.dart';

/// The pinned idb_shim dependency dereferences a nullable transaction.error
/// during a bubbling request-error event. The subsequent abort event carries
/// the final transaction result. Leave that handler in place and suppress the
/// unsafe intermediate callback until idb_shim fixes it upstream.
void guardNativeTransactionError(Transaction transaction) {
  if (transaction is TransactionNative) {
    transaction.idbTransaction.onerror = (idb.Event event) {}.toJS;
  }
}
