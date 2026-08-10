# dddart Agent Parallelism Experiment 001

> **Historical experiment brief.** This file preserves the instructions used for
> the August 2026 experiment. It is evidence of the experiment design, not
> current framework guidance; use `skills/dddart-architect/SKILL.md` for current
> planning conventions.

## Purpose

This experiment evaluates **dddart as a development framework for highly parallel autonomous software development**.

The long-term goal is not merely to make dddart easy for an AI agent to understand.

The goal is:

> **Make independently specified changes independently implementable.**

Imagine a development system in which a feature is decomposed into a dependency graph and each independent node may be assigned to a separate ephemeral coding agent. There may eventually be tens, hundreds, or thousands of workers operating concurrently.

The framework should make this safe and practical.

This experiment asks a simpler question:

> **How much parallel development does dddart support today, and what prevents more?**

Do not redesign dddart yet.

First, measure the current architecture.

---

## Hypothesis

A contract-oriented architecture should permit multiple workers to implement different parts of a feature without requiring detailed knowledge of one another's implementations.

If the contracts and boundaries are sufficient, workers should be able to:

1. receive bounded tasks;
2. understand the relevant contracts without exploring the entire application;
3. work independently;
4. modify mostly disjoint files;
5. validate their work independently;
6. combine their changes with little or no reconciliation;
7. rely on contracts rather than assumptions about unfinished work.

Failures in those properties are useful results.

---

## Experiment

### 1. Understand dddart

Inspect the repository sufficiently to understand:

- its architectural model;
- its existing notion of contracts;
- module/component/domain boundaries;
- dependency declaration;
- testing strategy;
- code generation, if any;
- application composition;
- any global registries, configuration, manifests, or other shared modification points.

Do not perform a general architecture review.

Focus specifically on properties affecting **independent concurrent change**.

---

### 2. Choose a Representative Feature

Identify one realistic feature that could reasonably be added to dddart itself, an included example application, or a representative application built with dddart.

The feature must:

- be meaningful enough to cross several architectural boundaries;
- require at least four distinguishable implementation activities;
- not require a wholesale redesign;
- exercise existing dddart patterns rather than bypassing them.

Describe the feature before proceeding.

---

### 3. Decompose the Feature

Pretend an orchestrator must assign the feature to independent workers.

Produce a dependency graph of the smallest sensible work items.

For each work item specify:

- its objective;
- inputs/contracts it depends upon;
- outputs/contracts it provides;
- files or architectural areas it is expected to own;
- tests or other validation that establish completion;
- dependencies on other work items.

Do **not** create artificial parallelism. If two activities genuinely cannot proceed independently, represent that dependency.

Classify every dependency as one of:

- **contract dependency** — the worker needs only a defined contract;
- **implementation dependency** — the worker must know how another component is implemented;
- **sequence dependency** — another change must actually exist before this work can proceed;
- **shared-state dependency** — workers must modify or coordinate through the same artifact.

Implementation and shared-state dependencies are particularly important findings.

---

### 4. Determine Maximum Safe Parallelism

From the dependency graph, determine how many work items could theoretically begin simultaneously.

Then determine how many could **actually** be handed to independent agents today without informal coordination.

These numbers may differ.

Explain why.

---

### 5. Simulate Independent Workers

For each initially parallelizable work item, approach it as though you were an isolated worker.

A worker should receive only:

- its work-item specification;
- the contracts explicitly identified as relevant;
- the portions of the repository reasonably discoverable from those contracts.

Do not assume knowledge gained while analyzing another work item unless that knowledge is represented in an explicit shared contract or artifact.

For each worker, record any occasion where it must escape its expected boundary to answer a question.

Examples:

- reading another module's implementation;
- discovering an undocumented convention;
- finding a dependency by repository-wide search;
- modifying a central registration file;
- guessing a data shape;
- waiting for another implementation before it can compile;
- running the entire application's test suite because no narrower validation exists.

These are experiment results, not inconveniences to hide.

---

### 6. Identify Collision Surfaces

Before integrating any implementation, predict where concurrent workers would collide.

Look specifically for:

- the same source file being edited by multiple workers;
- central registries;
- shared configuration;
- barrel/index files;
- dependency injection setup;
- schemas or migrations;
- generated files;
- package metadata;
- application bootstrap;
- broad tests;
- naming assumptions;
- implicit architectural conventions.

Distinguish:

**Git collision**

Two workers modify the same text.

**Semantic collision**

Changes merge cleanly but make incompatible assumptions.

**Contract collision**

Workers require incompatible changes to a shared contract.

**Integration collision**

Independent implementations work alone but fail when composed.

---

### 7. Implement Only If Useful

If the repository and environment make it practical, implement the decomposed feature as separate logical worker changes.

Preserve worker boundaries as much as possible.

Do not repair architectural weaknesses merely to make the experiment succeed.

If integration requires reconciliation, perform it only after documenting why it was necessary and what information the original workers lacked.

If actual parallel worker execution is available, use it.

If not, simulate isolated workers sequentially while strictly preserving their information boundaries.

The experiment is about architectural independence, not wall-clock speed.

---

## Questions the Experiment Must Answer

At completion, answer these questions.

### A. Decomposition

Could the feature be expressed naturally as independent work?

What prevented finer decomposition?

### B. Context

How much of the repository did each worker need to understand?

Could a worker discover everything it needed starting from explicit contracts?

What knowledge existed only implicitly in the codebase?

### C. Contracts

Which existing dddart contracts successfully allowed workers to proceed independently?

Which contracts were insufficient?

Which necessary contracts did not exist at all?

### D. Change Locality

Could each worker make its change primarily inside an owned architectural area?

Which changes leaked across boundaries?

Which files became coordination hotspots?

### E. Validation

Could each worker prove its work correct independently?

Were contract tests available?

Did workers need unrelated systems running or unrelated tests passing?

### F. Integration

How much human/agent reasoning was required after the independent changes were combined?

Could integration have been mechanical?

If not, why not?

### G. Parallelism

Report:

- number of total work items;
- maximum theoretical concurrent workers;
- maximum practical concurrent workers under today's architecture;
- number of worker collisions;
- number of undocumented cross-boundary assumptions discovered;
- number of shared modification points;
- number of integration repairs required.

Do not treat these numbers as absolute framework metrics yet. They establish a baseline.

---

## Failure Taxonomy

For every obstacle, classify it where possible.

### Missing Boundary

Unrelated implementation knowledge is required because responsibilities are insufficiently isolated.

### Missing Contract

A boundary exists conceptually, but its interaction is not explicitly specified.

### Non-Executable Contract

A contract exists in documentation or convention but cannot automatically validate an implementation.

### Hidden Dependency

A worker discovers a dependency that is not represented in the architecture's declared dependency structure.

### Shared Modification Point

Independent work requires editing the same central artifact.

### Excessive Context

A bounded task requires substantial unrelated repository exploration.

### Validation Coupling

A worker cannot validate its component without exercising a much larger portion of the system.

### Integration Ambiguity

Independently valid components cannot be composed without making an additional design decision.

### Framework Limitation

The desired isolation is known, but dddart currently provides no mechanism to express or enforce it.

Add additional categories if the experiment reveals qualitatively different problems.

---

## Do Not Optimize Yet

This experiment is specifically intended to reveal shortcomings.

Therefore:

- do not add interfaces merely because the experiment wants interfaces;
- do not create metadata solely to make dependencies discoverable;
- do not introduce new module boundaries;
- do not add agent-specific instruction files;
- do not eliminate shared registration points;
- do not redesign tests for isolation;
- do not modify dddart architecture to improve the resulting score.

Document what would need to change instead.

Those changes are candidates for later experiments.

---

## Final Report

Create:

`docs/experiments/agent-parallelism-001-results.md`

The report should contain:

### Feature

What feature was tested and why it was representative.

### Work Graph

The work-item dependency graph, preferably using Mermaid.

### Worker Table

For each worker:

| Worker | Task | Contracts Used | Expected Ownership | Boundary Escapes | Validation | Result |
|---|---|---|---|---|---|---|

### Parallelism

The theoretical and practical concurrency discovered.

### Collisions

Every Git, semantic, contract, and integration collision encountered or predicted.

### What dddart Already Gets Right

Existing framework properties that enabled independent work.

Be specific and cite concrete repository structures.

### What Prevents Greater Parallelism

Rank the discovered limitations by how strongly they constrain safe concurrent development.

### Framework Opportunities

For each major limitation, describe the smallest framework-level capability that could remove or reduce it.

Do not implement these changes yet.

### Conclusion

Answer one question:

> **If this feature were assigned to autonomous workers by an orchestration system today, what would prevent us from safely adding more workers?**

---

## Governing Principle

Throughout the experiment, evaluate architecture against this objective:

> **Maximize safe independent change.**

Do not optimize for the number of agents involved.

Do not optimize for lines of code generated.

Do not optimize for speed of this particular experiment.

We are testing whether dddart can make software development **parallel by construction**.
