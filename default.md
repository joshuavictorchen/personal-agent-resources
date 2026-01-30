# Preferences

## Communication

- Do not agree by default; challenge weak or unsupported assertions
- Be direct and concise; maximize information density
- State assumptions explicitly when they affect design, behavior, or comments
- If multiple interpretations exist, present them; don't pick silently
- Push back when a simpler approach exists or when something seems wrong
- Prefer technical accuracy over politeness
- If unsure or confused, say so explicitly; name what's unclear and ask

## Planning

- Produce explicit, ordered plans
- Scale plan depth to task complexity; avoid over-planning trivial changes
- Surface uncertainty early
- End plans with unresolved questions, if any

## Plan and Spec Files

- Plan and spec files (usually in `docs/plan.md` and `docs/spec.md`) are not infallible
- Challenge invalid or suboptimal directives; propose enhancements or simplifications where warranted

## Execution

- Never depend on persistent test fixtures outside of the repository for testing; always procedurally create them from tracked inputs
- When creating temporary files or directories outside the repository (e.g., in `/tmp`), place them in a dedicated subdirectory named with a UUID or session identifier (e.g., `/tmp/agent-{uuid}/`) to avoid collisions with parallel processes; clean up after execution when feasible

## Codebase Navigation

If this repository has code in it, then a structural map is maintained at `docs/codemap.md`. This file contains:

- Directory structure with purpose annotations
- Module responsibilities and internal dependencies
- Domain concept to code location mappings
- Conventions and known gotchas

Treat `docs/codemap.md` as the authoritative navigation source.

**Before exploring unfamiliar code**, read the relevant sections of `docs/codemap.md` to locate the right files on the first attempt.

If the map appears missing or stale, state that explicitly before exploring the repository.

## Development Philosophy

- Simplicity: Write simple, straightforward code
- Readability: Make code easy to understand
- Performance: Consider performance without sacrificing readability
- Maintainability: Write code that's easy to update
- Testability: Ensure code is testable
- Less Code = Less Debt: Minimize code footprint

Anti-patterns to avoid:

- Abstractions for single-use code
- "Flexibility" or "configurability" that wasn't requested
- Error handling for impossible scenarios
- If 200 lines could be 50, rewrite it

## Coding Rules (All Languages)

- Use clear variable and function names; avoid abbreviations (i.e., use "dataset" instead of "ds")
- Define high-level functions before helpers
- Test your code frequently with realistic inputs and validate outputs
- Keep core logic clean and push implementation details to the edges
- Add inline comments that explain the "why" as well as comments that explain the "what"
  - Prefer enough comments to guide newer developers through program flow
  - Comments start with lowercase letters and have no trailing punctuation

## Python Preferences

- Use Google-style docstrings for Python functions
- Format with black
- Test with pytest and coverage
- Prefer type hints where they improve clarity

## Markdown Preferences

- Use `markdownlint` rules when formatting markdown files

---

## Agent Guidance: Specifications, Plans, and Project Documents

This repository uses multiple document types with **explicitly different roles and authority**.
Agents must respect these boundaries to avoid drift, duplication, or misimplementation.

### Authority Model (Highest → Lowest)

1. **`docs/spec.md`** - normative contract
2. **`docs/decisions/*`** - rationale for constraints (non-normative)
3. **`docs/plans/*`** - slice-specific implementation intent (ephemeral)
4. **`docs/context.md`** - user stories, motivation, background (non-normative)

Finally, `docs/architecture.md` describes the as-built code (descriptive).

### Specification Principles (Foundational Guardrails)

These principles apply whenever an agent is **creating, modifying, or interpreting a specification**.

#### How a Good Spec Should Be Framed

- **A binding contract, not a narrative**: specs define *what must be true*, not intent, motivation, or process.
- **Authority-first**: the spec overrides plans, code, comments, and prior assumptions.
- **Written for verification**: every requirement can be evaluated as pass/fail.
- **Designed to survive change**: capture invariants and interfaces that are costly to change.
- **Agent-readable**: assume no shared context; ambiguity must be removed, not inferred.

#### What a Good Spec Should Include

- **Clear scope and boundaries**: what is in scope, out of scope, or deferred.
- **Normative requirements**: MUST / MUST NOT / SHOULD / MAY language; atomic and testable.
- **Invariants**: global truths that always hold (e.g., consistency, determinism, idempotency).
- **Contract surfaces**: data models, schemas, APIs, CLIs, file formats, message shapes.
- **Explicit error semantics**: error conditions and required observable behavior.
- **Behavioral examples**: concrete input → output for normal, edge, and failure cases.
  - Examples are illustrative unless explicitly marked as exhaustive; requirements always dominate examples.
- **Acceptance criteria**: how compliance is verified.
- **Open questions**: only those that block correctness.

#### What a Good Spec Must Avoid

- **Implementation details**: languages, frameworks, algorithms, internal structure.
- **Execution plans or sequencing**: step-by-step implementation plans belong in plans, not specs.
- **Duplicate sources of truth**: user stories or success metrics restating requirements.
- **Vague language**: "fast", "robust", "secure", "graceful" without definition.
- **Speculative or future features**: "might", "could", "later".
- **Implicit assumptions**: if it’s not written, it’s undefined.
- **Unspecified security claims**: security requires explicit, required behavior.

#### Validation Litmus Test

> If two independent implementations built from the spec alone do not behave the same way, the spec is incomplete.

### `docs/spec.md` - Normative Specification

#### Purpose

Defines **what must be true**. This is the binding contract for behavior and correctness.

#### Rules

- All normative behavior must live here.
- Requirements must be precise, observable, and testable.
- If behavior is not written, it is undefined.
- If conflict exists, stop and ask.
- If implementation reality forces change, update the spec explicitly.

#### Spec Change Protocol During Implementation

When an agent identifies that the spec must change while implementing code:

1. **Do not silently deviate.** Code must match the current spec until the spec is updated.
2. **Classify the change:**
   - **Breaking** - Removes, weakens, or alters observable behavior. Requires explicit approval before proceeding.
   - **Additive** - Defines previously undefined behavior without changing existing requirements. Proceed provisionally, marking the change as `proposed` and flagging for review.
   - **Clarifying** - Resolves ambiguity without changing intended behavior. Proceed, documenting rationale.
3. **Propose a diff** with affected sections, new language, and rationale.
4. **For provisional changes:** Implementation may continue, but affected code must be marked as dependent on pending spec approval. If the proposal is rejected, the agent must revert or revise.
5. **Document the decision** in `docs/decisions/*` after approval (or rejection, with outcome noted).

> **Principle:** The spec is append-mostly. Removing or weakening a requirement is a breaking change and must be justified.

### `docs/decisions/*` - Decision Records (Non-Normative)

#### Purpose

Explain **why** a particular choice was made instead of alternatives.

#### Characteristics

- Non-normative by default.
- May be referenced by `docs/spec.md` but do not define behavior on their own.
- Can be revised or superseded without changing the spec.

#### Promotion Rule

If changing a decision would break correctness or compatibility:

1. Promote it into `docs/spec.md` as a requirement or invariant.
2. Keep the decision record as historical rationale.

---

### `docs/architecture.md` - As-Built Description

#### Purpose

Describe **what the code looks like today**.

#### Characteristics

- Descriptive, not prescriptive.
- Explains structure, data flow, and extension points.

#### Rules

- Must not redefine requirements.
- If architecture diverges from `docs/spec.md`, either the document is outdated, the code is wrong, or the spec must be updated.

### `docs/plans/*` - Implementation Plans (Ephemeral)

#### Purpose

Describe **how a specific slice of the spec will be implemented right now**.

Plans that have been completed, abandoned, or have otherwised been rendered inactive are moved to `docs/plans/inactive/*`.

#### Characteristics

- Narrow in scope.
- Short-lived and disposable.
- Tied to a single slice or increment.

#### Rules

- Plans may be discarded or rewritten freely.
- Plans must be moved to `docs/plans/inactive/` when complete.

### `docs/context.md` - User Stories & Motivation (Non-Normative)

#### Purpose

Provide **human and agent context**: why the system exists and who it serves.

#### What Belongs Here

- User stories.
- Personas or actors.
- Problem statements.
- High-level goals and motivation.
- Constraints that are *not yet* hardened into requirements.

#### Rules

- Context informs specs but never defines behavior.
- If a user story implies behavior not stated in `docs/spec.md`, that behavior is undefined.
- Do not use context to justify deviating from the spec.

### Cross-Cutting Agent Rules

- Specs override plans, code, and assumptions.
- Decisions explain *why*; specs define *what*.
- Plans explain *how right now*; architecture explains *what exists*.
- If a document is being used outside its role, stop and reassess.
- When in doubt, ask before acting.

### Pre-Implementation Check

Before planning or coding begins, confirm:

- Every MUST / MUST NOT in `docs/spec.md` is testable.
- Examples and requirements are consistent.
- No open questions remain that affect correctness.

If these conditions are not met, return to spec iteration.

#### Guiding Principle

> **A good spec allows independent implementations to converge on the same behavior without coordination.**
