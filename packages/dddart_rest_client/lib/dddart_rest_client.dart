/// dddart_rest_client: supported DDDart application and extension APIs.
///
/// Complete setup and runnable examples:
/// https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/rest/README.md
///
/// Supported imports and extension contracts:
/// https://github.com/continuousimagination/dddart/blob/main/docs/PUBLIC_API.md
library dddart_rest_client;

export 'src/auth_provider.dart';
export 'src/cognito_auth_provider.dart';
export 'src/device_flow_auth_provider.dart';
export 'src/localhost_callback_strategy.dart';
export 'src/manual_callback_strategy.dart';
export 'src/oauth_callback_strategy.dart';
export 'src/oauth_credential_store.dart';
export 'src/oauth_login_store.dart';
export 'src/rest_client.dart';
