@TestOn('vm')
library;

import 'package:idb_shim/idb_client_memory.dart';
import 'package:test/test.dart';

import 'cancellation_contract.dart';

void main() => cancellationContract(newIdbFactoryMemory);
