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
- When the user says "yolo", make decisions autonomously for the current task. For each question (whether already asked or yet to be identified): (1) propose an answer with justification, (2) steel-man good alternatives (including the original answer), (3) commit to the strongest position. Proceed without waiting. Document all decisions with reasoning — in the current document if writing one, otherwise in chat

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
- Do not write to memory files automatically; at the end of substantive work, propose memory updates for approval before writing

## Document Authority and Roles

The following documents may exist. If they exist - or if they don't exist but their creation is requested - then use them as described in the remaining sections of these instructions.

| Document | Role | Authority | When to Read | Mutability |
| --- | --- | --- | --- | --- |
| `docs/spec.md` | Normative contract (what MUST be true) | 1 (high) | Before implementation; reference during; verify compliance after | Update explicitly on conflict |
| `docs/plans/*` | Explains *how right now*; slice-specific intent | 2 | Active plan for current work only | Discard/rewrite freely; move to `inactive/` when done |
| `docs/context.md` | User stories, motivation, auxiliary information | 3 | Session start; revisit when spec is silent | Informs spec and motivation behind behavior |
| `docs/codemap.md` | Descriptive map: structure, components, relationships, navigation, requirements traceability | — | Session start; navigating code; planning structural changes | Update freely; divergence = stale map |
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
- Requirement anchors on normative statements (see Requirement Anchors below)

**Must avoid:**

- Implementation details
- Execution plans
- Duplicate truth sources
- Vague terms ("fast", "robust")
- Implicit assumptions

**Recognizing violations:**

- *Implementation detail:* internal module, class, or function names not part of the public contract; file paths; data structures that aren't contract surfaces
- *Presentation leak:* specifying HOW something is displayed rather than WHAT it communicates (unless visual form is itself the requirement)

**Undefined behavior:** If behavior is not specified, it is undefined and must not be assumed.

#### Spec Editing

- Before adding a new MUST, check whether an existing requirement already covers the concern. Redundant MUSTs create maintenance burden and can contradict each other when one is updated.

#### Requirement Anchors

Each normative statement (MUST/MUST NOT/SHOULD/MAY) in a spec MUST carry a
stable anchor in the format `[SCOPE-N]` (e.g., `[TH-1]`, `[FP-3]`). SCOPE is
a 2–5 character mnemonic for the section topic, not tied to section numbers.
When extending an existing spec, reuse its established SCOPE prefixes.
Permissive statements and definitional prose do not receive anchors. Deferred
or future items MUST NOT use normative keywords and do not receive anchors — if
it is not in scope, it is a note, not a requirement.

- **Atomicity**: one anchor per independently verifiable assertion. Don't
  decompose beyond what's independently testable; don't group claims under one
  anchor if they'd be verified separately. When a MUST introduces a list of
  sub-requirements, anchor each verifiable sub-item; the umbrella statement is
  structural and does not receive an anchor
- **Stability**: never reuse a retired anchor. When a requirement is removed
  from the spec, remove its row from the RTM; the anchor ID is retired. Gaps in
  numbering are acceptable; broken cross-references are not
- **Test linkage**: tests MUST reference the anchor they verify in the test
  name, docstring, or comment

### Plan Principles

Spec, plan, and implementation form a feedback loop — each stage can inform the others. Never treat the plan as a fixed script.

Plans outline how to implement slices of the spec: what to build, in what order, and what depends on what.

**Before writing a plan:**

- Read the spec, codemap, and context
- Grill the user on implementation details, edge cases, and priorities
- Scale plan depth to task complexity

**Plan structure:**

- Break work into phases with clear completion criteria
- Order phases by dependency, then priority
- Prefer vertical slices: each phase delivers a narrow feature end-to-end with a demo-able result
- When shared infrastructure is prerequisite, isolate it as a minimal foundation phase gated on "first feature slice can begin"
- Identify what's uncertain and what decisions will need to be made during implementation
- Prefer unordered checklists over sequential procedures unless ordering is essential
- Each phase MUST list the requirement anchors it addresses. The plan SHOULD
  note anchors deferred to future work

**Before finalizing a plan:** Does every step have clear completion criteria? Are dependencies between steps explicit? What could go wrong? Does each element make sense?

**As work progresses:**

- When implementation reveals a spec gap or contradiction, consult with the user to update the spec before proceeding (unless yolo mode is active — then update the spec and present a clear summary of the changes and justification upon task completion)
- After completing a phase, revise remaining phases based on what was learned
- Surface changes to the user and confirm the revised plan
- Move completed plans to `docs/plans/inactive/` (confirm with user first)
- When a phase completes, verify each anchor it addresses (implementation location + passing test) and update the traceability section in `docs/codemap.md`

### Pre-Plan Interview

Before drafting any implementation plan, you MUST ask the user clarifying questions.
Do not skip this step even if the spec appears comprehensive — the goal is to surface
assumptions, resolve ambiguities, and align on priorities before committing to a design.

At minimum, address:
- Priorities and ordering preferences (what matters most? what can be deferred?)
- Dependency and tooling preferences (acceptable libraries, build systems, test frameworks)
- Known constraints not in the spec (performance targets, deployment environment, team context)
- Ambiguities or underspecified areas you noticed while reading
- Design trade-offs where multiple valid approaches exist

Only proceed to plan drafting after the user has responded (unless yolo mode is active).

### Task Completion

When implementing plans, always demonstrate that completed work is correct. Apply the same rigor to other tasks when the scope warrants it:

- Run tests; confirm they pass
- Check logs and output for warnings or errors
- Prove correctness; don't just technically complete the checklist
- Verify the requirements traceability section in `docs/codemap.md` is current
  and complete: all spec anchors present, status reflects passing tests.
  Unsatisfied MUST/MUST NOT anchors block completion; SHOULD/MAY anchors are
  tracked but non-blocking. The user may explicitly defer any anchor

**Before marking done:** "Would a staff engineer approve this?" If not, it's not done.

### Codemap Maintenance

After changes that affect component boundaries, data flow, or project structure, update `docs/codemap.md`. If the codemap conflicts with code, the map is stale — not the code.

The codemap MUST include a requirements traceability section mapping each spec
anchor to its implementation location and verifying test:

| Anchor | Requirement | Impl | Test | Status |
|--------|-------------|------|------|--------|
| [TH-1] | Lumped-parameter modeling | core.py::LumpedComponent | test_core.py::test_lumped_th1 | ✓ |
| [TH-2] | Energy conservation balance | | | |
| [TH-8] | Replaceable component interface | | | deferred |

At session start, verify RTM alignment with the current spec. New or removed
anchors indicate a stale table.

### Agent Rules

- If a document is used outside its role, stop and reassess.
- When in doubt, ask before acting.

### Pre-Implementation Check

Before coding: every MUST/MUST NOT is testable, examples match requirements, no blocking open questions. If not met, return to spec iteration.
