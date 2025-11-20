part of 'user_with_custom_repo.dart';

/// Concrete MongoDB repository implementation for UserWithCustomRepo.
///
/// This class extends the generated abstract base class and implements
/// the custom query methods using MongoDB queries.
class UserWithCustomRepoMongoRepository
    extends UserWithCustomRepoMongoRepositoryBase {
  /// Creates a repository instance.
  UserWithCustomRepoMongoRepository(Db database) : super(database);

  /// Finds a user by their email address.
  @override
  Future<UserWithCustomRepo?> findByEmail(String email) async {
    try {
      final doc = await _collection.findOne(where.eq('email', email));

      if (doc == null) {
        return null;
      }

      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');

      return _serializer.fromJson(doc);
    } catch (e) {
      throw RepositoryException(
        'Failed to find user by email: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  /// Finds all users with the given last name.
  @override
  Future<List<UserWithCustomRepo>> findByLastName(String lastName) async {
    try {
      final docs =
          await _collection.find(where.eq('lastName', lastName)).toList();

      return docs.map((doc) {
        // Convert MongoDB _id back to id field for deserialization
        doc['id'] = doc['_id'];
        doc.remove('_id');
        return _serializer.fromJson(doc);
      }).toList();
    } catch (e) {
      throw RepositoryException(
        'Failed to find users by last name: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
}
