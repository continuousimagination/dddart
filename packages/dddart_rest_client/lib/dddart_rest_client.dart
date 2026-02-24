/// Client library for dddart_rest APIs with automatic authentication
///
/// Provides HTTP client with automatic token management, device flow
/// authentication, and support for both self-hosted and OAuth providers.
library dddart_rest_client;

export 'src/auth_provider.dart';
export 'src/cognito_auth_provider.dart';
export 'src/device_flow_auth_provider.dart';
export 'src/localhost_callback_strategy.dart';
export 'src/manual_callback_strategy.dart';
export 'src/oauth_callback_strategy.dart';
export 'src/rest_client.dart';
