# dddart_config

Layered configuration with typed scalar access, immutable structured values,
explicit absence/null semantics and startup validation.

[Complete configuration workflow](../../docs/quickstarts/configuration/README.md) ·
[API source](lib/dddart_config.dart) · [Capabilities](../../docs/CAPABILITIES.md)

## Setup and examples

Follow the [quickstart](../../docs/quickstarts/configuration/README.md) to override a YAML setting
with an environment variable. For a service that reloads settings or checks
required keys at startup, see the [package examples](example/README.md).
The built-in file and environment providers need native IO. For a browser,
supply a provider that reads from a source available there.

## Provider precedence

Providers appear from highest to lowest priority. Maps merge recursively by key;
lists replace wholesale, including empty lists. Explicit null masks fallback;
absence permits it. An empty map contributes no overriding entries to a lower map.
A scalar, list or null at an intermediate priority is a replacement barrier:
higher maps cannot bring back lower descendants hidden by that replacement.

`lookup` and `contains` distinguish absence from explicit null. Nullable getters
return null for either. Required getters report absence as MissingConfigException
and explicit null/wrong type as TypeConversionException. Default getters follow
their documented API behavior. Configuration values and returned collections are
deeply immutable plain Dart values, preserving list order and native scalar types.

Use `getMap`/`getRequiredMap` for subtrees and `getList`/`getRequiredList` for actual
structural lists. The empty path addresses the complete effective root. Dot paths
traverse maps; inspect a subtree directly for literal dotted keys or list elements.
`getSection` is a scalar projection with dotted keys: it omits null and rejects
lists. It does not replace structural map access.

## Environment naming and conversion

With prefix `MYAPP`, `MYAPP_DATABASE_HOST` maps to `database.host` and
`MYAPP_SLACK_BOT__TOKEN` maps to `slack.bot_token`. A single underscore separates
path components; double underscores preserve an underscore inside a component.
Values remain strings: commas or JSON text do not create a collection. Put lists
and maps in YAML or a structural provider.

Normalized duplicate paths and scalar/descendant shape collisions fail. Without
a prefix, ambient names with empty components such as `_` are ignored; with an
explicit prefix, malformed selected names are errors. Prefer a dedicated prefix.
Typed scalar getters parse numeric and boolean strings. Boolean text accepts
true/false, 1/0, yes/no and on/off without case sensitivity. Collections are not
stringified by `getString`. Unsupported/cyclic structures and non-string map keys
fail with path context.

## Validation, reload and custom providers

`ConfigRequirement` declares the path, type, requiredness and optional validator.
Run `validate` before starting the application. Errors report paths/types while
omitting configuration values and callback exception text. Do not log secrets in
custom validation code. The [validation sample](example/validation_example.dart)
shows complete success and failure cases.

Await `Configuration.reload()` to reload its providers. The
[reload example](example/reload_example.dart) exercises this lifecycle. Implement
`ConfigProvider.lookup` and `reload` for custom providers; `lookup('')` must expose
the whole root tree so merging and ancestor masking are consistent. The base
provides scalar convenience access. See the
[standalone provider example](../../docs/quickstarts/configuration/README.md#supply-a-custom-provider).
