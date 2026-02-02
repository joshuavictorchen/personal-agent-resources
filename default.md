# Preferences

## Communication

- Do not agree by default; challenge weak or unsupported assertions
- Be direct and concise; maximize information density
- State assumptions explicitly when they affect design, behavior, or comments
- If multiple interpretations exist, present them; don't pick silently
- Push back when a simpler approach exists or when something seems wrong
- Prefer clarity over hedging; directness over padding
- If unsure or confused, say so explicitly; name what's unclear and ask

## Planning

- Produce explicit, ordered plans
- Scale plan depth to task complexity; avoid over-planning trivial changes
- Surface uncertainty early
- End plans with unresolved questions, if any

**Before finalizing a plan:** Does every step have clear completion criteria? Are dependencies between steps explicit? What could go wrong?

## Codebase Navigation

When `docs/codemap.md` exists, consult it early. Treat it as a guide, not infallible truth.

If documentation conflicts with observed code or structure, trust the code and flag the discrepancy.

When no navigation aids exist, proceed with direct exploration. Do not invent missing documentation.

## Development Philosophy

- Simplicity: Write simple, straightforward code
- Readability: Make code easy to understand
- Performance: Consider performance without sacrificing clarity
- Maintainability: Write code that's easy to update
- Testability: Ensure code is testable
- Less Code = Less Debt: Reduce footprint unless doing so harms readability or correctness

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

## Markdown Preferences

- Follow `markdownlint` rules when creating or editing Markdown files

**Before finalizing Markdown:**

- Verify fenced code blocks are surrounded by blank lines (MD031)
- Verify blank lines surround all lists (MD032)
- Verify fenced code blocks have a language specified (MD040)
- Verify tables use `| --- |` column syntax (MD060), and no trailing whitespace exists (MD060)

## Execution Guardrails

- Never depend on persistent test fixtures outside of the repository for testing; always procedurally create them from tracked inputs
- When creating temporary files or directories outside the repository (e.g., in `/tmp`), place them in a dedicated subdirectory named with a UUID or session identifier (e.g., `/tmp/agent-{uuid}/`) to avoid collisions with parallel processes; clean up after execution when feasible

## Task Completion

Never mark a task complete without demonstrating it works:

- Run tests; confirm they pass
- Check logs and output for warnings or errors
- Prove correctness; don't just technically complete the checklist

**Before marking done:** "Would a staff engineer approve this?" If not, it's not done.

## Document Authority and Roles

| Document | Role | Authority | When to Read | Mutability |
| --- | --- | --- | --- | --- |
| `docs/spec.md` | Normative contract (what MUST be true) | 1 (highest) | Before implementation; reference during; verify compliance after | Update explicitly on conflict |
| `docs/decisions/*` | Explains *why*; rationale for constraints | 2 | When a constraint seems wrong or before proposing changes | Revise freely; promote to spec if correctness-critical |
| `docs/plans/*` | Explains *how right now*; slice-specific intent | 3 | Active plan for current work only | Discard/rewrite freely; move to `inactive/` when done |
| `docs/context.md` | User stories, motivation, auxiliary information | 4 | Session start; revisit when spec is silent | Informs spec and motivation behind behavior |
| `docs/architecture.md` | Intentional design: boundaries, data flow, invariants | 5 | Session start; when proposing structural changes | Update on design changes; divergence = known debt or wrong code |
| `docs/codemap.md` | Navigation map: structure, modules, locators | — | Navigating unfamiliar code; locating domain concepts | Regenerate freely; divergence = stale map |

- Specs override plans, code, and assumptions.
- Spec and plan files are not infallible. Challenge invalid or suboptimal directives; propose enhancements or simplifications where warranted.

### When Documents Are Absent

If the repository does not yet contain the documents described above:

1. **Authority fallback:** User instructions are the sole authority source. Do not infer or invent missing specs, plans, or decisions.
2. **Minimal assumptions:** State any assumptions explicitly. If ambiguity affects correctness or externally visible behavior, ask before proceeding.
3. **Inline planning:** For non-trivial tasks, produce a brief inline plan and confirm before execution.

**Bootstrap option:** If work would benefit from persistent documents (e.g., multi-session tasks, complex invariants), propose creating them and explain why.

### Spec Principles

**Framing:** Binding contract, not narrative. Written for verification (pass/fail). Agent-readable—no inferred ambiguity.

**Must include:** Scope boundaries · Normative requirements (MUST/MUST NOT/SHOULD/MAY) · Invariants · Contract surfaces (APIs, schemas, formats) · Error semantics · Behavioral examples (illustrative unless marked exhaustive) · Acceptance criteria

**Must avoid:** Implementation details · Execution plans · Duplicate truth sources · Vague terms ("fast", "robust") · Speculative features · Implicit assumptions

**Recognizing violations:**

- *Implementation detail:* internal module, class, or function names not part of the public contract; file paths; data structures that aren't contract surfaces (API shapes, schemas, formats)
- *Speculative feature:* "could", "might", "potentially", "in the future", "eventually"
- *Presentation leak:* specifying HOW something is displayed rather than WHAT it communicates (unless visual form is itself the requirement)

**Litmus test:** Could two different implementations satisfy this spec? If the spec forces one specific implementation, it's over-specified.

**Undefined behavior:** If behavior is not specified, it is undefined and must not be assumed.

### Spec Change Protocol

1. **Never silently deviate.** Code matches current spec until spec is updated.
2. **Classify:**
   - *Breaking* (removes/weakens behavior) → explicit approval required
   - *Additive* (defines undefined behavior) → proceed provisionally, flag for review
   - *Clarifying* (resolves ambiguity) → proceed, document rationale
3. Propose diff with affected sections and rationale.
4. Document outcome in `docs/decisions/*`.

> Spec is append-mostly. Removing/weakening a requirement is breaking.

### Architecture Doc Maintenance

**Trigger:** Does this change affect how components relate—boundaries, interfaces, data flow, cross-cutting concerns (config/logging/errors), or invariants? If purely internal to one component, no update needed.

**On conflict:** Never silently rewrite. State mismatch → clarify intent → update doc or code. Record design changes in `docs/decisions/*`.

### Agent Rules

- If a document is used outside its role, stop and reassess.
- When in doubt, ask before acting.

### Pre-Implementation Check

Before coding: every MUST/MUST NOT is testable, examples match requirements, no blocking open questions. If not met, return to spec iteration.
