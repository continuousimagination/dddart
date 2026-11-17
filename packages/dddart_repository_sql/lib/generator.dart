/// Supported build-time extension API for SQL adapter generators.
///
/// These helpers consume resolved analyzer elements. Use this library only in
/// builder code; application runtime imports belong in dddart_repository_sql.dart.
/// CollectionKind is the collection analyzer's enum. Relationship analysis keeps
/// its own internal traversal classification out of this export namespace.
library;

export 'dddart_repository_sql.dart';
export 'src/schema/collection_analyzer.dart';
export 'src/schema/identity_type.dart';
export 'src/schema/relationship_analyzer.dart' hide CollectionKind;
export 'src/schema/schema_generator.dart';
export 'src/schema/type_mapper.dart';
