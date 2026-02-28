# Steering Benchmark Findings: dddart

Date: 2026-02-28
Benchmark used: `/Users/sean/Development/silly_sentence_game/.kiro/steering/architecture_guardrails.md`

## Scope
This report applies the Silly Sentence Game steering criteria to the `dddart` repository to identify architectural/process risks.

## Findings

### 1) [P2] Concrete repository coupling in core auth/query paths
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/auth_endpoints.dart:415`
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/auth_endpoints.dart:606`
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/jwt_auth_handler.dart:211`
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/jwt_auth_handler.dart:284`
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/crud_resource.dart:681`
- Details: these flows branch directly on `InMemoryRepository` and call `getAll()`, throwing `UnsupportedError` for other repository types.
- Steering mismatch: capability-first design over concrete-type checks.

### 2) [P2] Refresh token generation reimplements randomness incorrectly
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/jwt_auth_handler.dart:306`
- Details: `_generateRefreshToken()` claims cryptographic randomness but derives bytes from `DateTime.now().microsecondsSinceEpoch % 256`.
- Risk: low-entropy/predictable token material.
- Steering mismatch: avoid reimplementing existing primitives when robust platform/library functionality exists.

### 3) [P3] Large multi-responsibility orchestrators in `dddart_rest`
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/crud_resource.dart:45` (719 LOC)
- File: `/Users/sean/Development/dddart/packages/dddart_rest/lib/src/auth_endpoints.dart:38` (743 LOC)
- Details: each class handles many concerns (routing behavior, validation, auth, error mapping, pagination/query policy, endpoint-specific response shaping) in single units.
- Steering mismatch: complexity trigger and orchestrator-thinning guidance.

### 4) [P3] Library-level auth components hardcode console I/O
- File: `/Users/sean/Development/dddart/packages/dddart_rest_client/lib/src/cognito_auth_provider.dart:80`
- File: `/Users/sean/Development/dddart/packages/dddart_rest_client/lib/src/device_flow_auth_provider.dart:86`
- File: `/Users/sean/Development/dddart/packages/dddart_rest_client/lib/src/localhost_callback_strategy.dart:52`
- File: `/Users/sean/Development/dddart/packages/dddart_rest_client/lib/src/manual_callback_strategy.dart:36`
- Details: auth providers/strategies emit direct `print` output in library code paths.
- Steering mismatch: diagnostics/UI output should be injectable or caller-controlled rather than hardwired.

## Notes
- I did not find obvious pass-through wrapper classes in core `dddart` source analogous to the prior `PlayerRepository` issue.
- Most findings are architecture/coupling concerns rather than immediate correctness failures.

## Summary
- No broad "framework duplicated by app wrapper" pattern stood out in `dddart` itself.
- Primary improvement areas are repository capability abstraction, security-safe token generation, decomposition of oversized orchestrators, and output/logging injection boundaries.
