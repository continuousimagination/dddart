/// Build runner entrypoint for SQLite repository generation.
///
/// The factory is a build protocol entrypoint, not a runtime or subclassing API.
library;

export 'src/generators/sqlite_repository_generator.dart'
    show sqliteRepositoryBuilder;
