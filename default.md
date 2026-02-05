# Preferences

## Communication

- Be direct and concise; maximize information density
- Prefer clarity over hedging; directness over padding
- Do not agree by default; challenge weak or unsupported assertions

## Reasoning

- State assumptions explicitly when they affect design, behavior, or comments
- If multiple interpretations exist, present them; don't pick silently
- Before committing to an approach, consider whether a simpler alternative exists and prefer it
- If unsure or confused, say so explicitly; surface uncertainty early
- Hold all outputs to the same standard — instructions, docs, and plans deserve the same rigor as code
- When solving problems, ask yourself: am I addressing symptoms or am I addressing the root cause? Solve the root

## Development Philosophy

- Simplicity: Write simple, straightforward code
- Readability: Make code easy to understand
- Performance: Consider performance without sacrificing clarity
- Maintainability: Write code that's easy to update
- Testability: Ensure code is testable

Anti-patterns to avoid:

- Abstractions for single-use code (e.g., creating a base class or factory for a single implementation)
- "Flexibility" or "configurability" that wasn't requested
- Error handling for impossible scenarios
- Clever one-liners that require mental unpacking
- If 200 lines could be 50 without sacrificing clarity, rewrite it

### Demand Elegance

- For non-trivial changes, pause before finalizing and ask: "Is there a more elegant way?"
- If a solution feels hacky or forced, step back: "Knowing everything I know now, what's the clean implementation?" Then build that instead.
- Challenge your own work before presenting it.

**Guardrail:** "Elegance" must reduce objective complexity: fewer moving parts, clearer invariants, reduced coupling, simpler interfaces, or better testability. Avoid aesthetic-only rewrites.

## Codebase Navigation

When `docs/codemap.md` exists, consult it early. Treat it as a guide, not infallible truth. If `docs/field-notes.md` exists, read it for cross-session context.

If documentation conflicts with observed code or structure, trust the code and flag the discrepancy.

When no navigation aids exist, proceed with direct exploration. Do not invent missing documentation.

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
- Prefer pathlib over os.path for filesystem operations
- Prefer f-strings over .format() or % formatting
- Test with pytest and coverage
- Prefer type hints where they improve clarity

## Execution Guardrails

- Never depend on persistent test fixtures outside of the repository for testing; always procedurally create them from tracked inputs
- When creating temporary files or directories outside the repository (e.g., in `/tmp`), place them in a dedicated subdirectory named with a UUID or session identifier (e.g., `/tmp/agent-{uuid}/`) to avoid collisions with parallel processes; clean up after execution when feasible

## Document Authority and Roles

The following documents may exist. If they exist - or if they don't exist but their creation is requested - then use them as described in the remaining sections of these instructions.

| Document | Role | Authority | When to Read | Mutability |
| --- | --- | --- | --- | --- |
| `docs/spec.md` | Normative contract (what MUST be true) | 1 (high) | Before implementation; reference during; verify compliance after | Update explicitly on conflict |
| `docs/plans/*` | Explains *how right now*; slice-specific intent | 2 | Active plan for current work only | Discard/rewrite freely; move to `inactive/` when done |
| `docs/context.md` | User stories, motivation, auxiliary information | 3 | Session start; revisit when spec is silent | Informs spec and motivation behind behavior |
| `docs/codemap.md` | Descriptive map: structure, components, relationships, navigation | — | Session start; navigating code; planning structural changes | Update freely; divergence = stale map |
| `docs/field-notes.md` | Cross-session agent context: lessons learned, gotchas, failed approaches | — | Session start | Append only; do not edit or remove existing entries |

- Specs override plans, code, and assumptions.
- Spec and plan files are not infallible. Challenge invalid or suboptimal directives; propose enhancements or simplifications where warranted.

### Spec Principles

Specs are binding contracts, not narrative. Written for verification (pass/fail). Agent-readable — no inferred ambiguity.

**Must include:**

- Scope boundaries
- Normative requirements (MUST/MUST NOT/SHOULD/MAY)
- Invariants
- Contract surfaces (APIs, schemas, formats)
- Error semantics
- Behavioral examples (illustrative unless marked exhaustive)
- Acceptance criteria

**Must avoid:**

- Implementation details
- Execution plans
- Duplicate truth sources
- Vague terms ("fast", "robust")
- Implicit assumptions

**Recognizing violations:**

- *Implementation detail:* internal module, class, or function names not part of the public contract; file paths; data structures that aren't contract surfaces
- *Presentation leak:* specifying HOW something is displayed rather than WHAT it communicates (unless visual form is itself the requirement)

**Litmus test:** Could two different implementations satisfy this spec? If the spec forces one specific implementation, it's over-specified.

**Undefined behavior:** If behavior is not specified, it is undefined and must not be assumed.

### Plan Principles

Spec, plan, and implementation form a feedback loop — each stage can inform the others. Never treat the plan as a fixed script.

Plans outline how to implement slices of the spec: what to build, in what order, and what depends on what.

**Before writing a plan:**

- Read the spec, active decisions, and codemap
- Grill the user on implementation details, edge cases, and priorities
- Scale plan depth to task complexity

**Plan structure:**

- Break work into phases with clear completion criteria
- Order phases by dependency, then priority
- Identify what's uncertain and what decisions will need to be made during implementation
- Prefer unordered checklists over sequential procedures unless ordering is essential

**Before finalizing a plan:** Does every step have clear completion criteria? Are dependencies between steps explicit? What could go wrong? Does each element make sense?

**As work progresses:**

- When implementation reveals a spec gap or contradiction, update the spec (following the Spec Change Protocol) before proceeding
- After completing a phase, revise remaining phases based on what was learned
- Surface changes to the user and confirm the revised plan
- Move completed plans to `docs/plans/inactive/` (confirm with user first)

#### Task Completion

When implementing plans, always demonstrate that completed work is correct. Apply the same rigor to other tasks when the scope warrants it:

- Run tests; confirm they pass
- Check logs and output for warnings or errors
- Prove correctness; don't just technically complete the checklist

**Before marking done:** "Would a staff engineer approve this?" If not, it's not done.

### Codemap Maintenance

After changes that affect component boundaries, data flow, or project structure, update `docs/codemap.md`. If the codemap conflicts with code, the map is stale — not the code.

### Agent Rules

- If a document is used outside its role, stop and reassess.
- When in doubt, ask before acting.

### Pre-Implementation Check

Before coding: every MUST/MUST NOT is testable, examples match requirements, no blocking open questions. If not met, return to spec iteration.
