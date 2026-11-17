# dddart_serialization

Format-neutral serialization contracts, annotations, configuration and explicit
identity codecs. JSON generation lives in [dddart_json](../dddart_json/README.md).
Core domain models remain independent of any serialization format.

[Complete JSON workflow](../../docs/quickstarts/json/README.md) ·
[Serialization contract](../../docs/SERIALIZATION.md) ·
[Public API](lib/dddart_serialization.dart)

## Contracts and configuration

`Serializer<T, C extends Object>` chooses a format-specific configuration type.
JSON uses `SerializationConfig`, with `FieldRename.none`, `snake` and `kebab`, and
`includeNullFields`. Configurations replace whole configurations; they are not
merged field by field. See the contract guide for annotation, constructor,
per-call and nested precedence, and exact error/cause behavior.

`@Serializable()` marks a supported generated model. The JSON builder supports
AggregateRoot, Entity, Value and DomainEvent hierarchies; inspect its current
validation rules and run clean generation. A custom format is responsible for
its own supported model shapes. This package does not supply YAML or Protobuf
serialization or enforce domain encapsulation at runtime.

## Identity codecs

`IdentityCodecRegistry` is an injected instance, not global state. UUID has a
stock codec; each application identity needs an explicit JSON and canonical-key
codec registered under a stable type key. Share the registry with generated
serializers and repositories. The complete
[native identity example](../../docs/quickstarts/json/bin/identity.dart) shows
the ID, codec, and canonical key round trip. The
[generated event test](../dddart_json/test/domain_event_roundtrip_test.dart)
shows a registry supplied to a generated serializer.

JSON encoding can use native scalars or scoped structures. Key encoding must be
reversible and collision-free; decoding rejects noncanonical aliases. Do not use
`toString`, an ambiguous concatenation or a UUID hash as an implicit key codec.
URI escaping and database size/comparison rules belong to the adapter.

`toTaggedJson`/`fromTaggedJson` add an explicit type key for heterogeneous streams.
Duplicate kinds/keys, unknown kinds, and malformed values fail. Choose stable
keys so consumers can decode values after a Dart class is renamed.
