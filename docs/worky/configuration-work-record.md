# Configuration work record — issue #38

## Scope and authorization

Branch: issue/38-structured-configuration. PR: #46. Target: feat/worky-changes.
Owner authorization on 28 October 2026: incorporate warranted review refinements
and implement the issues, continuing until a blocker or necessary clarification.
Merge authority stops at feat/worky-changes; main and publication remain separate.

The implementation preserves structured YAML, native scalar types, ordered lists,
explicit null, immutable subtrees and consistent layered lookup. Maps merge;
lists replace; null/scalar/list barriers in intermediate providers mask lower
descendants. Three-provider cases are mandatory acceptance evidence.

ConfigProvider is an abstract base with structural lookup/reload and inherited
scalar conveniences. The empty path selects the complete root tree. Existing
scalar getSection is retained as a projection, omitting null and rejecting lists.
Custom providers migrate to a root tree. This deliberate refinement avoids
discarding useful scalar access while keeping structure authoritative.

## Ownership and generated state

Owned package: packages/dddart_config, including its workspace example and
documentation. No generator or generated part is owned by this change.
Workspace dependencies were resolved from the root; ignored lock/cache state
was created by Pub. No old generated artifacts were reused for configuration.

## Behavioral evidence so far

- Focused structured suite: 19 tests passed, including ordered records, native
  types, null/absence/empty values, immutable snapshots, environment strings,
  safe errors, malformed values, reload preservation and intermediate barriers.
- Complete configuration regression suite: 154 tests passed after migration of
  intentional list/error semantics.
- Package analysis with fatal infos: passed.
- Owned Dart formatting check: passed.

Existing environment tests previously depended on whichever variables happened
to exist on the host, and many key-conversion tests had conditional no-op bodies.
They now use explicit environments and test each underscore convention both
with and without a prefix. Host ancestor/descendant variable collisions are a
documented error; no source silently wins by iteration order.

## Remaining completion evidence

- Workspace-derived package, example and minimal external-consumer lanes.
- Clean external consumer resolving the exact pushed immutable candidate.
- Integrated feature-branch regression gate after identity work joins it.
- Final independent feature-branch review requested by the owner.

No formal CLI-generated lifecycle approvals or independent code-review result
are claimed by this record. Actual evidence is recorded here and in GitHub;
the final review is still required before main integration.
