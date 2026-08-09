# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING:** `CrudResource<T>` now requires one `JsonSerializer<T>` through
  `serializer` instead of a content-type-to-serializer map.
- **BREAKING:** `ResponseBuilder<T>.ok`, `.created`, and `.okList` now accept a
  `JsonSerializer<T>` and no longer take a positional content-type argument.
- CRUD success bodies use `application/json`; collection bodies are valid JSON
  arrays and stock errors use `application/problem+json`.
- `Accept` values that do not allow JSON return 406, and `POST`/`PUT` requests
  without `Content-Type: application/json` return 415, before request side
  effects.
- `PUT` now rejects a deserialized aggregate whose ID differs from the route ID
  with a problem+json 400 response before authorization, ETag lookup, or
  persistence.
- `OAuthJwtAuthHandler` now rejects expired and not-yet-valid JWTs, with a
  configurable `clockSkewTolerance` that defaults to zero.
- **BREAKING:** `JwtAuthHandler` now requires an asynchronous `claimsLoader`
  keyed by validated user ID. It reloads authoritative application claims for
  initial issuance and refresh, and a `null` result refuses token issuance.
- **BREAKING:** `AuthEndpoints` no longer accepts `claimsBuilder`; claim loading
  belongs to `JwtAuthHandler`. Application claims are included only in access
  tokens, never in opaque refresh tokens.

### Added

- **ETag-based optimistic concurrency control** - Prevent lost updates from concurrent modifications
  - `ETag` header automatically included in GET, POST, and PUT responses
  - `If-Match` header validation in PUT requests
  - `412 Precondition Failed` response when ETag mismatches
  - Two ETag strategies: `timestamp` (default) and `contentHash`
  - `ETagGenerator` class for generating and validating ETags
  - `ConcurrencyException` for handling concurrency conflicts
  - Backward compatible - `If-Match` header is optional
  - Example: `example/etag_concurrency_example.dart`

## [0.9.0] - 2024-11-17

### Changed

**BREAKING: Package renamed from `dddart_http` to `dddart_rest`**

This package has been renamed to better reflect its purpose of providing RESTful CRUD APIs for DDD aggregate roots, distinguishing it from other HTTP concerns like webhook handling.

#### Migration Required

**1. Update pubspec.yaml:**
```yaml
dependencies:
  dddart_rest: ^0.9.0  # Changed from dddart_http
```

**2. Update imports:**
```dart
// Before
import 'package:dddart_http/dddart_http.dart';

// After
import 'package:dddart_rest/dddart_rest.dart';
```

**3. Update logger configuration (if used):**
```dart
// Before
Logger('dddart.http').level = Level.INFO;

// After
Logger('dddart.rest').level = Level.INFO;
```

#### What Changed
- Package name: `dddart_http` → `dddart_rest`
- Import path: `package:dddart_http/*` → `package:dddart_rest/*`
- Logger name: `dddart.http` → `dddart.rest`

#### What Stayed the Same
- All API surfaces remain identical
- No breaking changes to functionality
- All class names and methods unchanged

### Internal
- Removed circular dependency with `dddart_webhooks` package
- Removed `registerWebhook()` method from `HttpServer` (webhooks should use `WebhookResource` directly)

## [0.8.0] and earlier

See git history for changes prior to the rename.
