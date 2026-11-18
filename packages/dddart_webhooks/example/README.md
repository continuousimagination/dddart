# dddart_webhooks examples

Start the local receiver, then paste its printed command in a second terminal. It uses OpenSSL to sign the same bytes that curl sends. The receiver responds with the processed event type. Stop the server with Ctrl+C.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_webhooks/example
dart pub get
dart run raw_json_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [custom_verifier_example.dart](custom_verifier_example.dart) | Configured integration | Check incoming requests with a provider-specific verifier. |
| [form_encoded_example.dart](form_encoded_example.dart) | Configured integration | Decode form fields into a typed payload. |
| [raw_json_example.dart](raw_json_example.dart) | Configured integration | Deserialize a JSON event and dispatch it by type. |
