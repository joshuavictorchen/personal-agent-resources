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

If `docs/codemap.md` exists, it is the authoritative navigation source for this repository and describes:

- Directory structure with purpose annotations
- Module responsibilities and internal dependencies
- Domain concept → code location mappings
- Conventions and known gotchas

When present: before exploring unfamiliar code, consult the relevant sections of `docs/codemap.md` to locate the correct files on the first attempt.
If any referenced path does not exist or conflicts with observed structure, treat the codemap as potentially stale and fall back to direct exploration.

When absent: proceed with direct code exploration. Do not attempt to infer, reconstruct, or require a codemap.

If a codemap exists but appears stale or incomplete, state that explicitly before continuing.

## Development Philosophy

- Simplicity: Write simple, straightforward code
- Readability: Make code easy to understand
- Performance: Consider performance without sacrificing readability
- Maintainability: Write code that's easy to update
- Testability: Ensure code is testable
- Less Code = Less Debt: Minimize code footprint unless the reduction sacrifices readability

Anti-patterns to avoid:

- Abstractions for single-use code (e.g., creating a base class or factory for a single implementation)
- "Flexibility" or "configurability" that wasn't requested
- Error handling for impossible scenarios
- If 200 lines could be 50 without sacrificing clarity, rewrite it

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
- Sort imports with isort
- Perfer pathlib over os.path for filesystem operations
- Prefer f-strings over .format() or % formatting
- Test with pytest and coverage
- Prefer type hints where they improve clarity

## Markdown Preferences

- Use `markdownlint` rules when creating or editing Markdown files

## Document Authority & Agent Rules

### Authority (Highest → Lowest)

1. **`docs/spec.md`** — normative contract (what MUST be true)
2. **`docs/decisions/*`** — rationale for constraints (non-normative)
3. **`docs/plans/*`** — slice-specific implementation intent (ephemeral)
4. **`docs/context.md`** — user stories, motivation (non-normative)
5. **`docs/architecture.md`** — as-built description (descriptive, not prescriptive)

### Spec Principles

**Framing:** Binding contract, not narrative. Authority-first. Written for verification (pass/fail). Agent-readable—no inferred ambiguity.

**Must include:** Scope boundaries · Normative requirements (MUST/MUST NOT/SHOULD/MAY) · Invariants · Contract surfaces (APIs, schemas, formats) · Error semantics · Behavioral examples (illustrative unless marked exhaustive) · Acceptance criteria

**Must avoid:** Implementation details · Execution plans · Duplicate truth sources · Vague terms ("fast", "robust") · Speculative features · Implicit assumptions

**Litmus test:** Two independent implementations from the spec alone must behave identically.

**Undefined behavior:** If behavior is not specified, it is undefined and must not be assumed.

### Document Roles

| Document | Role | Mutability |
| -------- | ---- | ---------- |
| `spec.md` | Defines behavior | Update explicitly on conflict |
| `decisions/*` | Explains *why* | Revise freely; promote to spec if correctness-critical |
| `plans/*` | Explains *how right now* | Discard/rewrite freely; move to `inactive/` when done |
| `context.md` | Explains *who/why exists* | Informs spec, never defines behavior |
| `architecture.md` | Explains *what exists* | Descriptive only; divergence = outdated doc or wrong code |

### Spec Change Protocol

1. **Never silently deviate.** Code matches current spec until spec is updated.
2. **Classify:**
   - *Breaking* (removes/weakens behavior) → explicit approval required
   - *Additive* (defines undefined behavior) → proceed provisionally, flag for review
   - *Clarifying* (resolves ambiguity) → proceed, document rationale
3. Propose diff with affected sections and rationale.
4. Document outcome in `docs/decisions/*`.

> Spec is append-mostly. Removing/weakening a requirement is breaking.

### Agent Rules

- Specs override plans, code, and assumptions.
- If a document is used outside its role, stop and reassess.
- When in doubt, ask before acting.

### Pre-Implementation Check

Before coding: every MUST/MUST NOT is testable, examples match requirements, no blocking open questions. If not met, return to spec iteration.
