---
name: maintain-architecture
description: Creates or updates docs/architecture.md to capture intentional system design (boundaries, data flow, invariants) without becoming a mirror of current code.
---

# Maintain Architecture

Document the intentional architecture of the system: design intent, component boundaries, data flow, and invariants that code should conform to. This document is prescriptive about intent and descriptive about known drift.

## Output Location

Write to `docs/architecture.md`. Update in place, preserving existing headings/order where possible. Prefer minimal diffs and stable wording.

## When to Use

- Initial project setup (no architecture doc exists)
- After significant design decisions
- When component boundaries, invariants, or data flow change
- When refactors touch cross-cutting concerns (config/logging/errors/types)
- When code has drifted and architecture intent must be clarified

## Inputs to Consider

- `docs/spec.md` (behavioral contract; architecture must not contradict it)
- `docs/context.md` (intent/motivation; non-normative)
- `docs/decisions/*` (rationale; link rather than duplicate)
- `docs/codemap.md` (navigation/current structure; descriptive)
- Current code (as-built reality)

## Non-Goals

- Do not restate the full spec or duplicate decision records
- Do not update architecture intent to match code unless the change is clearly intentional and recorded
- Do not invent invariants; when uncertain, add Open Questions/TODOs

## Process

1. **Read** `docs/architecture.md` if present to understand current intent and structure
2. **Scan** `docs/codemap.md` for current structure; inspect code only where codemap is absent or flagged stale
3. **Classify changes** since the last doc update:
   - **Within intent** (refactor inside boundaries): update only as-built notes if needed; avoid rewriting intent
   - **Intent change** (boundaries/data flow/invariants changed): update intent + record rationale (see protocol)
   - **Drift** (code violates intent): document under Known Debt and propose remediation options
4. **Resolve ambiguity**:
   - If ambiguity affects externally visible behavior or component contracts: ask the user before asserting
   - Otherwise: add items to Open Questions and proceed without guessing
5. **Write** updates with minimal churn and stable ordering

## Architecture Change Protocol (Hard Rules)

- **Intent changes require rationale.** If you change boundaries, invariants, or data flow, you MUST:
  1. Add or update a record in `docs/decisions/*` *or* explicitly mark "TBD decision" in Change History
  2. Update Change History with the decision link or TBD marker
- **Do not silently rewrite intent to match code.** If code contradicts architecture and intent is unclear, treat it as drift and document it.
- **Invariants must be checkable.** If an invariant cannot be verified (by tests, assertions, or inspection), mark it as a goal or move to Open Questions/Known Debt.

## Output Format

**Small projects (≤20 source files or single-component systems):** Use a minimal template with only Overview, Key Invariants (if any), and Known Debt. Omit Component Boundaries, Data Flow, Cross-Cutting Concerns, Open Questions, and Change History unless they provide clear value.

**Larger projects:** Use the full template below.

```markdown
# Architecture

<!-- Intentional design. Code should conform to this. -->
<!-- For navigation and current structure, see docs/codemap.md -->
<!-- For design rationale, see docs/decisions/* -->

## Overview

(2-4 sentences: system purpose, primary technologies, dominant architectural pattern)

## Component Boundaries

(Describe major components/subsystems. Keep stable; update when intent changes.)

### <Component Name>

- **Owns**: what this component is exclusively responsible for
- **Exposes**: public interface (APIs, types, events, CLI surface)
- **Consumes**: allowed dependencies from other components
- **Forbidden**: disallowed dependencies (omit if none)
- **Invariants**: checkable assumptions it enforces or relies on (label uncertain items)

## Data Flow

(How the system moves data by design. Keep brief.)

- Inputs → stages → outputs
- State ownership (in-memory/db/fs/external) and why
- Key handoff points between components

(Optional: simple diagram in a code fence)

## Architectural Invariants

(System-wide rules that must hold. Keep checkable.)

- Dependency direction constraints (A may depend on B, not vice versa)
- State ownership rules
- Concurrency/threading model (if applicable)
- Error handling strategy (boundaries where errors are translated)
- Performance constraints only if measured and enforceable (otherwise list as goals in Open Questions)

## Cross-Cutting Concerns

(How shared mechanisms should be used. For file locations, see `docs/codemap.md`.)

- Configuration
- Logging/telemetry
- Error types and exception taxonomy
- Shared utilities/helpers
- Type definitions/constants

## Open Questions

(Items requiring maintainer input. Prefer TODOs over guessing.)

- Q: ...
  - Why it matters:
  - Options:
  - Default proposal (if any):

## Known Debt

(Mismatches between intent and as-built code. Be explicit.)

- Drift: ...
  - Evidence:
  - Impact:
  - Remediation options:
  - Preferred direction (if known):

## Change History

(Keep recent entries; archive older entries to `docs/decisions/*` if this section exceeds ~20 rows.)

| Date | Change | Rationale / Decision |
| ---- | ------ | -------------------- |
| YYYY-MM-DD | (what changed) | (link to docs/decisions/NNN-*.md or "TBD decision") |
```

## Guidelines

- Write for agents and future humans: boundaries, contracts, and the shape of the system
- Be prescriptive about intent, descriptive about drift
- Prefer links to `docs/decisions/*` over duplicating rationale
- Keep section ordering stable to reduce churn
- Avoid exhaustive file lists (that belongs in `docs/codemap.md`)
- If the project is small, keep this doc short—omit sections that add no value
