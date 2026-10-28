# Identity serialization work record — issue #40

Branch: issue/identity-serialization. Target: issue/37-extensible-identity.
Prerequisite #39 was locally validated, merged by PR #47 at 6498f78 and closed.

## Frozen boundary contract

IdentityCodec<I> explicitly supplies toJson/fromJson and toKey/fromKey. The JSON
representation can be scalar or structured; the canonical string key must be
reversible and preserve kind/scope. URI escaping and database constraints remain
adapter responsibilities. Arbitrary identity toString output is not encoding.

IdentityCodecRegistry is instance-local. It supplies UuidIdentityCodec under the
stable key "uuid" and supports register<I>(stableKey, codec). Duplicate keys/types
are rejected. Typed operations use I; tagged operations use an explicit stable
registration key and restore the registered concrete kind. Unregistered/malformed
values fail clearly. No global registry or runtimeType-derived wire key is used.

Generated serializers retain their optional positional SerializationConfig
constructor and add a named withIdentityCodecs(registry, [config]) constructor.
Nested generated serializers share that registry. Static encode/decode helpers
accept an optional registry after the configuration. JsonSerializer/Serializer
interfaces remain the existing injection seams; adapters can receive the same
registry explicitly in composition.

The generated identityCodecs getter exposes the registry for composition and
keeps generated UUID-only serializers free of unused private-field warnings.
Registry key operations verify inverse equality and canonical spelling, rejecting
lossy encoders and alternate key aliases before adapter storage/transport.

The generator resolves concrete identity arguments and inherited generic field
types before emitting code. Annotated open generic consumers or untyped Identity
roots fail generation; a concrete consumer can inherit an unannotated generic
base. Recursive collection handling preserves typed identities and nullable
members through lists, sets, map values and codec-backed identity map keys.

## Generation owner and topology

One owner handles packages/dddart_json and its workspace example, sequentially.
Builder: dddart_json:json_serializable. Handwritten annotated libraries retain
their existing part directives; cached .json_serializable.g.part contributions
combine into the corresponding .g.dart. The new runtime cases are added to the
existing test_models.dart owner/combined part rather than a separate shared part.
Never hand-edit generated output. Verify the expected parts exist and compile
with their owner before accepting a successful build command.

Clean consumer regression tests create separate temporary packages/build caches;
they do not run generators concurrently against the owning package cache.

## Local behavior evidence

JSON generation passes and its expected combined parts compile. All 112 JSON
tests pass, including four native/scoped identity round trips, clean external
package generation and three unsupported declaration diagnostics. The clean
fixture includes a custom identity named UuidValue to prove type-based dispatch.

All 22 serialization tests pass, including six codec cases. Fatal-info analysis
and formatting pass for both packages. The workspace-derived serialization and
JSON package gates, JSON example gate and both archive/minimal-consumer lanes
pass. The JSON example's generated combined parts are current, analyzed and its
supported finite entrypoints run successfully. Publication dry-run is exempt
for these packages because their manifests set publish_to: none.

A clean consumer with no dependency overrides pins core, serialization and JSON
to b94bf700e31553e0b625ecd1169f9be1356e8a9a. Pub resolution, build_runner generation,
fatal-info analysis (including generated output) and execution pass for scoped
JSON with nullable identity collections, typed repository CRUD, canonical keys
and tagged identities. Fixture: /private/tmp/dddart-worky-json-consumer-acabce7.
Logs: /private/tmp/dddart-worky-implementation-20261028/json-git-consumer-final.log.

The initial immutable probe exposed a redundant null assertion in generated
collection callbacks. The corrected generator promotes local callback variables,
and the clean-package regression now covers nullable identity list/map elements.
The initial sandboxed fixture run could not write Pub's active_roots metadata;
the same six focused cases pass with normal pub-cache access. Neither failure
was counted as successful validation.

Commands:

```bash
dart run tool/validation/validate.dart package dddart_serialization --mode=local
dart run tool/validation/validate.dart consumer dddart_serialization
dart run tool/validation/validate.dart package dddart_json --mode=local
dart run tool/validation/validate.dart example dddart_json_example --mode=local
dart run tool/validation/validate.dart consumer dddart_json
```

This completes the owned serializer boundary. Document/SQL/REST/event adapter
migration and the final parent integration/review remain in #41–#44 and #37.
