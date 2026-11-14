@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';

import 'cancellation_contract.dart';

void main() => cancellationContract(() => idbFactoryNative, native: true);
