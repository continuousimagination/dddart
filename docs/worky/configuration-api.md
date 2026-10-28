# Structured configuration: API and implementation proposal

Status: implementation authorized on 28 October 2026; local validation underway.
Tracking: [#38](https://github.com/continuousimagination/dddart/issues/38).
Source baseline: `c538680619a11af79e7094c3087646189c313978`.

## Owner decisions

Breaking pre-release API changes are allowed. Preserve YAML structure and
ordered lists. Merge maps by key so an environment override for database.host
does not discard a lower-priority database.port. Replace lists wholesale.
A higher-priority explicit null masks lower-priority values; an absent key
allows fallback. Worky has no code yet, so acceptance uses a standalone
representative consumer.

## Proposed access API

Use a structural lookup result at both ConfigProvider and Configuration:

```dart
class ConfigLookup {
  // bool isPresent;
  // Object? value;  // null is allowed when isPresent is true.
}

abstract class ConfigProvider {
  ConfigLookup lookup(String path);
  Future<void> reload();
}
```

Provide explicit missing/present constructors with a read-only value.
Configuration exposes the same lookup operation, a presence check and focused
typed accessors, including getMap and a structural getList. Returned structures
are deeply immutable plain Dart values:

- Map<String, Object?>, preserving its entries and nested structure;
- List<Object?>, preserving sequence order and element boundaries;
- String, bool, int, double and explicit null.

Keep YAML wrapper types out of the public contract. Reject unsupported YAML
values or non-string map keys with a useful path/type error. A dotted lookup
path traverses maps; callers can inspect a returned subtree directly for keys
that contain literal punctuation. No application schema, project-selection
logic or priority policy belongs in this package.

Raw lookup distinguishes missing from explicit null. Nullable convenience
getters return null for either; required getters report missing keys separately
from present null/wrong-type values. Error messages identify the path and
expected/actual type without embedding the sensitive value.

Retain sensible scalar conveniences: getString accepts supported non-null
scalar values; numeric/bool getters accept corresponding typed scalars and
explicitly parse environment-backed strings under documented existing rules.
Do not stringify maps or lists to satisfy scalar access. Structural getList
returns an actual sequence and never splits a scalar string on commas.
Existing CSV-based getList consumers receive explicit migration examples.
ConfigProvider supplies scalar getString and a legacy dotted getSection
projection as concrete conveniences. The latter omits null, rejects lists and
is not the structural provider contract; getMap preserves complete subtrees.

## Resolution and precedence

Earlier providers retain higher precedence. Resolve the same effective tree
whether a caller looks up a parent subtree or an individual child path:

1. Absent values contribute nothing.
2. Explicit null is present and stops fallback at that path.
3. Maps merge recursively by key, with higher-priority entries winning.
4. Lists replace as a whole, including an empty list. Never merge by index.
5. A higher-priority scalar/list/map replaces a lower value of a different
   shape; do not resurrect descendants below a scalar or null.

Consequently, an empty overriding map contributes no entries when merged with
a lower map. It remains an empty map when no lower entries exist. An explicit
null masks a lower subtree. This empty-map rule is part of the proposal for
review rather than an unstated implementation convention.

Example: high database.host=prod plus low database.host=localhost and
database.port=5432 yields host=prod, port=5432. High database=null masks both.
High projects=[] replaces the entire lower projects list. High database=off
makes database.port inaccessible instead of falling through to a lower map.

EnvironmentConfigProvider supplies strings and its current hierarchical key
mapping. Do not implicitly parse environment values as YAML/JSON or turn
commas into list elements. Typed scalar accessors may parse strings. Detect
conflicting ancestor/descendant shapes within a provider and document a
deterministic path error rather than depending on iteration order.

## Work item and branch

Keep #38 as one focused package change covering the provider contract, YAML
and environment providers, facade resolution/accessors, validation/errors,
tests, examples, changelog and migration documentation.

Branch: `issue/38-structured-configuration`.
PR base: `feat/worky-changes`.
There is no implementation dependency on #37. The final feature branch must
prove that both capabilities work together.

## Behavioral acceptance and local checks

Tests cover:

- The projects example as two ordered records with string organization and
  integer number fields.
- Nested maps/lists, empty collections, null, missing and supported scalars.
- Strings containing commas and collections containing maps.
- Recursive map merging, whole-list replacement, parent/child lookup
  consistency, explicit-null masking and scalar/collection shape conflicts.
- Environment string semantics, retained scalar conversions, wrong types and
  safely worded path errors.
- Deep immutability and existing relevant provider/reload behavior.

Resolve workspace dependencies at the root. Run format checks, focused
configuration tests, package analysis/regression tests, the configuration
example and minimal outside-consumer validation. Then run the repository's
workspace-derived local gate against the integrated feature branch.
There is no generated code owned by dddart_config.

GitHub Actions is disabled; record actual local commands/results. Final
external-consumer evidence must resolve the exact immutable candidate revision
and read the ordered records with native scalar types.

The owner authorized implementation after reviewing these proposals and the
issue review. Actual commands and results belong in the dedicated configuration
work record; proposal text alone is not a test result.
Validated work may merge to feat/worky-changes; final branch review, merge to
main and publication remain separate owner actions.
