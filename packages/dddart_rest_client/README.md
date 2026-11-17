# dddart_rest_client

HTTP client helpers with optional authentication and explicit token-provider lifecycles.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Installation and runnable setup

Follow the [complete rest workflow](../../docs/quickstarts/rest/README.md)
for the current Git manifest, named files, clean generation where required,
expected output and cleanup. Hosted release installation remains separate under
#30. Use the documented development SDK; 1.0 is the first compatibility baseline.

## Public and authenticated requests

[RestClient](lib/src/rest_client.dart) wraps an HTTP client and an optional
`AuthProvider`. Its path methods resolve against `baseUrl`; JSON bodies are encoded
by the helpers. Without a provider, requests remain anonymous. With a provider,
the client obtains a token before sending. Close the client when finished.

Authentication failures are distinct from HTTP status responses. Installing a
client provider does not define server authorization; public resources and
per-operation server policies remain supported.

## Authentication providers

| Provider | Flow and prerequisites |
| --- | --- |
| [DeviceFlowAuthProvider](lib/src/device_flow_auth_provider.dart) | Self-hosted device flow using `authUrl`, `clientId`, `credentialsPath`; display the supplied URL/code through `onOutput`, then poll for a bound single-use grant |
| [CognitoAuthProvider](lib/src/cognito_auth_provider.dart) | Authorization-code flow with PKCE, configured authorization/token endpoints and callback strategy; this is not Cognito device flow |
| [AuthProvider](lib/src/auth_provider.dart) | Application extension point for other token/login/storage implementations |

Device grants are single-use and bound to the configured client ID. A lost success
response can require a new login. Providers attempt refresh when credentials
expire; callers must handle authentication failure and deliberate re-login.
Cognito additionally exposes ID-token claims and the subject through its methods.
`beginLogin`/`completeLogin` support application-managed callback handling.

## Credential storage and platforms

The supplied providers write JSON credential files to the configured path. This
is not encrypted storage or an OS keychain. Applications own access permissions,
secrets handling, storage lifecycle and platform-appropriate alternatives. Built-in
file storage and localhost/manual callback strategies use native IO; browser and
mobile callback/storage integrations need their own implementation and tests.

The [example programs](example/README.md) include basic requests and a CLI tool.
They are compile-checked because running them requires a configured auth/server
and user interaction. The [public HTTP workflow](../../docs/quickstarts/rest/README.md)
provides a finite anonymous server/client check without those prerequisites.

## API and validation

The [public library](lib/dddart_rest_client.dart) links the current API declarations. Detailed
contracts live with those declarations instead of duplicated signatures here.
[Repository examples](example/README.md) list their runtime/service requirements.
From the repository root, run the package and example commands in
[validation](../../scripts/README.md). Required service/browser lanes must be
available; compiling a configured sample does not prove a live deployment.
