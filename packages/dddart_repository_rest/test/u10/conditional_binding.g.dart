// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conditional_binding.dart';

// **************************************************************************
// RestRepositoryGenerator
// **************************************************************************

/// Generated conditional repository for [shared.VersionedRecord].
class ConditionalProbeRestRepository
    extends RestConditionalRepository<shared.VersionedRecord> {
  /// Creates the typed conditional adapter using trusted configuration.
  ConditionalProbeRestRepository(RestConnection connection)
    : super(
        connection,
        serializer: shared.VersionedRecordJsonSerializer(),
        resourcePath: '/VersionedRecord',
      );
}

/// Generated conditional repository for [shared.VersionedRecord].
abstract class CustomConditionalProbeRestRepositoryBase
    extends RestConditionalRepository<shared.VersionedRecord>
    implements shared.VersionedPort {
  /// Creates the typed conditional adapter using trusted configuration.
  CustomConditionalProbeRestRepositoryBase(RestConnection connection)
    : super(
        connection,
        serializer: shared.VersionedRecordJsonSerializer(),
        resourcePath: '/VersionedRecord',
      );
  @override
  Future<shared.VersionedRecord Function(shared.VersionedRecord)> callback({
    int take = 20,
  });
}
