# dddart Agent-Native Architecture Study 001

> **Historical study brief.** This file preserves the follow-up design task used
> after Experiment 001. Proposed APIs and optimization language here are not
> current dddart contracts; use `skills/dddart-architect/SKILL.md` and current
> exported source for operational guidance.

## Purpose

This task follows **dddart Agent Parallelism Experiment 001**.

That experiment showed that a representative feature decomposed into three theoretically parallel implementation tasks, but only one could practically complete its declared local validation gate without depending on another worker, unrelated source changes, or shared generated state.

The goal of this study is **not** to implement fixes yet.

The goal is to determine:

> **What is the smallest coherent set of changes to dddart that would make the three theoretically parallel workers from Experiment 001 independently completable?**

Treat the current dddart design as evidence, not as a sacred constraint.

Prefer the smallest architectural change that solves the problem, but do not preserve current APIs or source topology merely for compatibility if doing so prevents safe independent development.

Do not redesign dddart wholesale unless the evidence clearly requires it.

---

## Governing Principle

Evaluate every proposal against this objective:

> **Maximize safe independent change.**

The target is not “make dddart easier for AI to understand.”

The target is:

> **Make independently specified changes independently implementable, independently provable, and mechanically integrable.**

The long-term context is a development system in which a feature may be decomposed into many bounded work items and assigned to ephemeral autonomous workers executing concurrently.

---

## Source Material

Read:

`docs/experiments/agent-parallelism-001-results.md`

Treat that report as the baseline.

Inspect the repository as deeply as needed to validate, refine, or challenge its conclusions.

Do not assume every proposed opportunity in that report is necessarily the right design.

---

## Primary Question

Design the smallest coherent architectural changes that could turn the Experiment 001 baseline from:

- theoretical concurrent workers: **3**
- practical concurrent workers: **1**

into:

- theoretical concurrent workers: **3**
- practical concurrent workers: **3**

The desired state is that the three initially parallel implementation workers can:

1. be dispatched concurrently from shared contracts;
2. work within bounded ownership areas;
3. avoid depending on one another's implementations;
4. complete behavioral validation independently;
5. avoid shared mutable build state;
6. integrate without design-time reconciliation.

---

## Areas to Investigate

### 1. Executable Cross-Boundary Contracts

Experiment 001 found that the domain method:

`findByPriceRange(minPrice, maxPrice)`

did not define enough behavior for independently implemented client and server workers to agree.

Investigate a first-class mechanism such as a:

- query descriptor;
- repository query declaration;
- operation contract;
- transport-independent command/query specification;
- or another design you consider superior.

Determine whether one declaration can define or drive:

- domain arguments;
- operation identity;
- transport encoding;
- server parsing;
- validation;
- inclusive/exclusive semantics;
- pagination behavior;
- result shape;
- result metadata;
- error semantics;
- client adaptation;
- server adaptation;
- contract tests.

Do not assume HTTP must be embedded directly into the domain contract.

Explore whether transport-specific representations can be derived from a transport-neutral executable contract.

Provide concrete Dart API sketches.

Show how the Experiment 001 `findByPriceRange` feature would be expressed.

Explain what parts would be handwritten and what parts, if any, would be generated.

### 2. Independent Extension Surfaces

Experiment 001 found that generated repository transport helpers were library-private, encouraging custom repository implementations to remain physically co-located with the aggregate, interface, annotations, and generated part.

Investigate how dddart could expose a narrow, public extension surface that permits custom repository operations to live in independent libraries without duplicating:

- connection handling;
- serializer access;
- resource URI construction;
- error mapping;
- request execution;
- other generated transport context.

Consider designs such as a public repository context or operation executor, but do not assume that is the correct answer.

The resulting surface should expose only what custom behavior legitimately requires, preserve encapsulation, avoid coupling extension code to generator internals, permit low-context isolated implementation, and support independent testing.

Provide concrete API sketches.

### 3. Physical Change Isolation

Study the current source topology.

Ask:

> **Does the physical organization of dddart maximize independent change, or merely logical/runtime modularity?**

Pay particular attention to files that combine domain types, contracts, annotations, generator directives, generated parts, transport implementations, and composition.

Determine whether these should remain together or be separated.

Do not split files merely for theoretical purity.

For each proposed structural change, explain which independent workers it enables, which Git collision surface it removes, whether it introduces new coordination points, whether the additional structure would be costly for human developers, and whether generation can remove that cost.

Prefer structures that make ownership mechanically obvious.

### 4. Hermetic Worker Builds

Design the development/build contract for an ephemeral worker.

The desired worker lifecycle is conceptually:

`checkout -> prepare -> change -> validate -> produce artifact -> terminate`

The worker should not depend on inherited generated files, inherited `.dart_tool` state, undocumented working-directory conventions, another worker having run generation first, shared mutable builder caches, or commands that report success while leaving unusable output.

Determine the smallest framework/repository changes required to make worker preparation and validation reproducible.

Investigate canonical generation entrypoints, workspace-aware generation, isolated build state, generated-source tracking vs regeneration, deterministic output, build manifests, compile/import checks of generated artifacts, and per-package validation metadata.

The objective is not merely a nicer developer script.

The objective is a **machine-executable environment contract**.

### 5. Independent Proof

Experiment 001 showed that workers could often author code independently but could not prove it independently.

Design a validation model in which a worker can establish:

> **My implementation conforms to Contract X**

without requiring the corresponding peer implementation to exist.

Explore generated conformance tests, contract test suites, fixtures, protocol examples, reference adapters, executable schemas, compile-time proofs where possible, and transport-level simulators or fakes.

Distinguish static validity, local behavioral validity, contract conformance, and end-to-end integration.

The framework should make these validation levels explicit.

Provide a proposal for how the Experiment 001 client worker and server worker could each prove compatibility before integration.

### 6. Mechanical Integration

Study what would be necessary for an integration worker or orchestrator to combine completed work without making new architectural decisions.

Integration should ideally consist of discovering completed artifacts, validating declared compatibility, composing registrations, running integration gates, and reporting failures.

It should not require inventing protocol details or inspecting implementation internals.

Investigate typed resource registration, operation registration, generated composition metadata, duplicate detection, dependency manifests, compatibility/version metadata, route/endpoint declaration, and application composition roots.

Explain which integration decisions must remain centralized and which can be made mechanically.

---

## Design Constraints

Do not optimize primarily for number of agents, maximum code generation, preserving current source layout, preserving every current public API, cleverness, or theoretical purity.

Optimize for safe parallel work, explicit dependencies, reproducibility, change locality, executable contracts, local proof, mechanical composition, and understandable failure modes.

Human usability still matters.

Do not propose an architecture that is technically excellent for agents but intolerable for ordinary developers unless generation/tooling removes most of the ceremony.

---

## Required Design Alternatives

Produce **three coherent alternatives**:

### A. Minimal

The smallest set of changes that could plausibly make Experiment 001 reach practical concurrency 3.

Favor compatibility and incremental evolution.

### B. Moderate

A cleaner model that changes more of dddart where current architecture is actively working against independent development.

Balance migration cost with long-term value.

### C. Radical

What dddart would look like if **safe autonomous parallel development were a primary design goal from the beginning**.

Do not constrain this option unnecessarily by existing APIs.

Keep it grounded in implementable Dart architecture rather than speculative prose.

---

## For Each Alternative

Include:

1. architectural summary;
2. concrete Dart API examples;
3. proposed source/module layout;
4. generated vs handwritten artifacts;
5. machine-readable metadata introduced;
6. worker ownership boundaries;
7. worker validation model;
8. integration flow;
9. compatibility and migration cost;
10. human developer ergonomics;
11. expected effect on Experiment 001;
12. major risks;
13. unresolved questions.

---

## Re-run Experiment 001 on Paper

For each alternative, map the original price-range feature onto the proposed architecture.

Show Worker 1 client-side responsibility, Worker 2 server-side responsibility, Worker 3 application/composition responsibility, any additional workers that become natural, contracts each receives, files/artifacts each owns, validation each can run independently, and what information each does **not** need to know.

Predict the resulting baseline metrics:

- total work items;
- maximum theoretical concurrency;
- maximum practical concurrency;
- worker collisions;
- undocumented cross-boundary assumptions;
- shared modification points;
- integration repairs.

These are predictions, not claims.

Explain the reasoning behind each prediction.

---

## Recommendation

After presenting the three alternatives, recommend one.

The recommendation should answer:

> **What should dddart change first if its new strategic goal is to become a framework for highly parallel autonomous software development?**

Prefer a coherent architectural direction over a grab bag of unrelated fixes.

Identify the first capability to implement, what should deliberately remain unchanged for now, and what should be postponed until evidence from another experiment exists.

---

## Experiment 002

Design, but **do not execute**, the next experiment.

Experiment 002 should validate the recommended architecture against the same core problem.

Its success criterion must be:

> **W1, W2, and W3 can be dispatched concurrently from shared contracts, complete their own behavioral validation in isolation, and integrate without design-time reconciliation.**

Specify:

- exact framework changes Experiment 002 assumes;
- exact representative feature;
- worker specifications;
- ownership boundaries;
- validation gates;
- integration procedure;
- metrics to capture;
- failure taxonomy;
- stop conditions.

Design it so that failure is informative.

Do not bias the experiment to make the proposed architecture look successful.

---

## Deliverable

Create:

`docs/agent-native/architecture-proposal-001.md`

The document should contain:

1. Executive Summary
2. Baseline From Experiment 001
3. Design Principles
4. Minimal Alternative
5. Moderate Alternative
6. Radical Alternative
7. Side-by-Side Comparison
8. Paper Re-run of Experiment 001
9. Recommendation
10. Proposed Experiment 002
11. Open Questions

Use Mermaid diagrams where they improve clarity.

Be specific.

Prefer repository evidence, concrete APIs, and explicit tradeoffs over generic AI-development commentary.

---

## Important Restrictions

Do **not** implement the proposed framework changes.

Do **not** refactor source merely to demonstrate the proposals.

Do **not** run Experiment 002.

Do **not** optimize the repository to improve the previous metrics.

This task is architecture and design work only.

The desired output is a proposal strong enough that implementation decisions can be made after review.

---

## Final Question

End the report by answering:

> **What must become true about dddart for “three independent pieces of work” to mean “three independently completable workers”?**

The answer should be concrete enough to guide the next implementation experiment.
