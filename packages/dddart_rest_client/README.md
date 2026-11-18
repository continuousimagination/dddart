# dddart_rest_client

HTTP client and token providers for making authenticated requests.

[Capability boundaries](../../docs/CAPABILITIES.md) · [Supported imports](../../docs/PUBLIC_API.md)

## Get started

For a public endpoint, use a plain HTTP client or a generated repository with
`RestConnection(baseUrl: ...)`. The [public HTTP quickstart](../../docs/quickstarts/rest/README.md)
shows both calls.

For an authenticated request, construct [RestClient](lib/src/rest_client.dart)
with an `AuthProvider`. It calls `getIdToken()` before sending a request and
sets the bearer header. Its path helpers resolve URLs against `baseUrl` and
encode JSON bodies. Close the client when finished. The server decides which
operations a caller can perform.

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

Use the [CLI example](example/README.md) to try device login with a configured server.
