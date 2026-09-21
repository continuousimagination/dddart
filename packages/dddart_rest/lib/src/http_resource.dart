import 'package:shelf/shelf.dart';

/// Typed HTTP registration contract shared by ordinary and conditional resources.
abstract interface class HttpResource {
  /// Trusted collection path, independent of caller-supplied identities.
  String get path;

  /// Handles one item read.
  Future<Response> handleGetById(Request request, String id);

  /// Handles a collection query, or explicitly rejects unsupported querying.
  Future<Response> handleQuery(Request request);

  /// Handles collection creation, or explicitly rejects unsupported creation.
  Future<Response> handleCreate(Request request);

  /// Handles one item write.
  Future<Response> handleUpdate(Request request, String id);

  /// Handles one item removal/retirement.
  Future<Response> handleDelete(Request request, String id);
}
