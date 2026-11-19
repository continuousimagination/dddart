# dddart_json

Generated JSON map/string serializers for DDDart model hierarchies, with typed
configuration and explicit identity codecs.

## Complete setup

Follow the [JSON quickstart](../../docs/quickstarts/json/README.md). It includes a
Git manifest, all imports, a complete model constructor, its `.g.dart` part,
clean build_runner generation and executable map/string, configuration and
native-identity examples. Generated parts must be rebuilt after model changes.

Use `@Serializable` from `dddart_serialization`. The generator supports concrete
AggregateRoot, Entity, Value and DomainEvent hierarchies and resolves inherited
typed identity state. Open/erased identity types and unsupported fields fail
generation. There is no runtime reflection fallback.

## Configuration and errors

[Serialization semantics](../../docs/SERIALIZATION.md) is the authoritative
contract. Generated map/string/static methods and handwritten JsonSerializer
implementations accept `SerializationConfig?`. Per-call config replaces the
constructor config, which replaces the concrete annotation/defaults. Nested
serializers receive the effective config and the same identity registry.

`toJson`/`fromJson` operate on maps; `serialize`/`deserialize` operate on JSON text.
Input-shape and codec validation errors are normalized at explicit boundaries,
with typed exceptions, causes and stacks preserved. Unrelated application failures
are not relabeled as invalid input. Encoding a map does not itself verify that a
misbehaving codec's output can be encoded as a JSON string.

## Identity generation

Generated serializers expose a constructor using the stock UUID registry and
`withIdentityCodecs` for application identity kinds. Register the concrete codec
once per injected registry and share it throughout the model graph. The
[identity program](../../docs/quickstarts/json/README.md#give-custom-identities-a-codec) includes a
complete native ID/codec and round trip. Static helpers accept an explicit registry
when needed; no global identity registration is used.

## API and examples

The [public library](lib/dddart_json.dart) exposes `JsonSerializer`. The
[build configuration](build.yaml) invokes the internal generator; application
code uses the imports recorded in the [API inventory](../../docs/PUBLIC_API.md).
The [repository example](example/README.md) demonstrates nested domain models,
collections, naming strategies and enum serialization. For browser use, keep native database imports out of the model library.
