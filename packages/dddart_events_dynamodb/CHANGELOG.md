> Historical record; it may describe retired APIs. For current usage, start at
> [the documentation index](../../docs/README.md).

# Changelog

## 0.1.0 — Unreleased

- Atomic retained aggregate history with committed ingestion positions,
  idempotent occurrence IDs, pagination and expiration/floor recovery semantics.
- Durable random channel resolution and idempotent event-driven rotation.
- Injected DynamoDB clients, DynamoDB Local integration tests and a finite example.

## Unreleased

- Breaking: event lookup and rotation keys use registered identity-kind/canonical-key tuples. Preserve custom event identities across persistence and retries; reject oversized keys before IO. Migrate retained envelopes, lookup keys and digests together.
