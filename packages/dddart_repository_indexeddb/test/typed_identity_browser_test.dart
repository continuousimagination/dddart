@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';

import 'typed_identity_contract.dart';

void main() => typedIdentityContract(() => idbFactoryNative);
