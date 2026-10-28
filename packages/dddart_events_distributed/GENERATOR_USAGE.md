# Distributed event registry generation

The verified workflow is described in [README.md](README.md). A concrete
`@Serializable()` DomainEvent<I> with named base metadata parameters generates
its JSON serializer and `createGeneratedEventRegistry` in the same owning
`.g.dart` part. Import the core, JSON, serialization and distributed-event public
libraries in that owner. Supply its explicit identity codec registry when creating
the generated registry. Use `@DistributedEvent('stable.key.v1')` to keep wire keys
independent of Dart renames; otherwise the source class name is the wire key.

Builders are `dddart_json:json_serializable` and
`dddart_events_distributed:event_registry`. Run them through build_runner in one
owning package/cache at a time. Verify the combined part exists and compiles with
its owner. Do not hand-edit generated output. The package build scans only
handwritten library/example-library inputs and its one identity fixture; nested
example caches are not inputs. Package/example generation is serialized.

Clean-consumer tests prove fresh generation, metadata/identity round trips,
wrong-ID analyzer failures, erased-ID diagnostics and duplicate wire-key errors.
Historical standalone registry-map sketches under `example/legacy` remain
excluded and are not the current generated contract. Broader deferred event and
AWS transport work is outside the identity change.
