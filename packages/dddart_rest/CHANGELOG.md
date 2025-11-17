# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
