// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conditional_binding.dart';

// **************************************************************************
// DynamoRepositoryGenerator
// **************************************************************************

/// Generated conditional repository for [shared.VersionedRecord].
class ConditionalProbeDynamoRepository
    extends DynamoConditionalRepository<shared.VersionedRecord> {
  /// Creates the typed conditional adapter using trusted configuration.
  ConditionalProbeDynamoRepository(
    DynamoConnection connection, {
    String? tableName,
  }) : super(
         connection,
         serializer: shared.VersionedRecordJsonSerializer(),
         tableName: tableName ?? "VersionedRecord",
       );
}

/// Generated conditional repository for [shared.VersionedRecord].
abstract class CustomConditionalProbeDynamoRepositoryBase
    extends DynamoConditionalRepository<shared.VersionedRecord>
    implements shared.VersionedPort {
  /// Creates the typed conditional adapter using trusted configuration.
  CustomConditionalProbeDynamoRepositoryBase(
    DynamoConnection connection, {
    String? tableName,
  }) : super(
         connection,
         serializer: shared.VersionedRecordJsonSerializer(),
         tableName: tableName ?? "VersionedRecord",
       );
  @override
  Future<shared.VersionedRecord Function(shared.VersionedRecord)> callback({
    int take = 20,
  });
}
