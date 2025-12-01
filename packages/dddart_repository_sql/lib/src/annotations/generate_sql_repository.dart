/// Annotation for generating SQL repository implementations.
///
/// This is a base annotation that concrete implementations (like SQLite)
/// will extend with their own specific annotations.
class GenerateSqlRepository {
  /// Creates a SQL repository generation annotation.
  const GenerateSqlRepository();
}
