# Serialization contract

`dddart_serialization` owns `Serializable`, `SerializationConfig`, identity
codecs, and `Serializer<T, C extends Object>`. A format chooses its configuration
type `C`; it need not accept JSON options. `dddart_json` supplies
`JsonSerializer<T> implements Serializer<T, SerializationConfig>` and generated
serializers. All JSON map/string/constructor/static configuration parameters are
`SerializationConfig?`. Wrong types fail static analysis; dynamic invocations
fail Dart's parameter check with `TypeError` before serialization begins.

## Defaults and composition

The default is `FieldRename.none` and `includeNullFields: false`. For generated
serializers, the concrete class's annotation replaces those defaults, an explicit
constructor config replaces the annotation, and a per-call config replaces the
constructor config. These are **whole configurations**, not field-by-field merges.
An ancestor's annotation is not merged into a concrete class's annotation.
`null` means use the serializer's default; it does not reset to framework defaults.

Nested serializers receive the parent's effective config and the same
instance-local `IdentityCodecRegistry`. Config overrides never replace codecs.
UUID has a stock codec; register each other concrete identity kind explicitly.
Static `encode`/`decode` construct a fresh serializer with annotation defaults;
pass config and registry explicitly when needed. No global registry is used.

`toJson`/`fromJson` work with maps. `serialize`/`deserialize` work with strings.
Map encoding does not run a JSON encoder: a misbehaving codec can return a value
that only fails when the caller subsequently encodes the map. Codec outputs must
be JSON-compatible, and their keys must be reversible and collision-free.

## Error boundaries

| Failure | Result |
| --- | --- |
| Malformed JSON text | DeserializationException with FormatException cause and captured stack |
| Null or non-object JSON where an object is required | DeserializationException |
| Missing required field, wrong field type, malformed timestamp/UUID/codec input | DeserializationException at the field/codec boundary; cause and stack retained |
| Codec rejects encoding with FormatException | SerializationException with cause and stack |
| JSON encoder rejects output, including a cycle or unsupported object | SerializationException with JsonUnsupportedObjectError cause and stack |
| Existing SerializationException or DeserializationException | Same exception object is rethrown, with its original type, metadata and stack |
| Wrong configuration type | Compile-time error, or TypeError for dynamic invocation |
| Duplicate/invalid registry registration | ArgumentError at registration; missing codec remains a typed SerializationException |
| Unrelated application failure (for example StateError from a codec or constructor) | Propagates unchanged; it is not relabeled as malformed input |

A codec signals invalid input with `FormatException` or a typed serialization
exception. Type casts while decoding an input field are also normalized. Do not
use an arbitrary application exception as an input-validation signal.

Generated serializers and handwritten serializers use the same
`JsonSerializer.encodeValue` and `JsonSerializer.readValue` boundaries. Handwritten
serializers can extend `JsonSerializer<T>` to inherit string behavior, implement
map methods with these helpers, validate the object shape, and keep application
constructors outside field-reading closures. Implementing the interface directly
also means implementing its contract; a custom override can always violate a
Dart interface's behavioral promises.

Errors normalized by these boundaries expose `cause` and `stackTrace`; deliberate
validation errors need not have an underlying cause. These diagnostics are for
application logging. HTTP responses still apply their own error/redaction policy.

## Verification

From the repository root, after resolving dependencies from the pubspecs:

```sh
dart tool/validation/validate.dart package dddart_serialization --mode=ci
dart tool/validation/validate.dart package dddart_json --mode=ci
```

The JSON gate regenerates fixtures before testing. The parity suite exercises
handwritten and generated serializers, and the isolated consumer rejects wrong
configuration on both generated and generic interfaces. Existing annotation,
constructor/per-call, nullable-field and typed-identity suites cover composition.
Fresh generation is the supported path; 1.0 is the first compatibility baseline.
