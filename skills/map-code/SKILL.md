---
name: map-code
description: Analyzes this codebase and generates a structured map for AI agent navigation and planning. Enables agents to locate code, understand component relationships, and obtain architectural context without exploring the filesystem.
---

# Code Mapping

Analyze this codebase and generate a structured map for AI agent navigation and planning. The map should enable an agent to (1) locate relevant code quickly without exploring the filesystem and (2) understand component relationships and constraints when planning changes.

## Output Location

Write the map to `docs/codemap.md`.

- If the file already exists, update it to reflect the current codebase state.
- If the file does not exist, create it.

After writing the file, provide a brief summary in the chat:

1. Whether this was a creation or update
2. Key structural changes detected (if update). Focus on top-level additions/removals, not cosmetic diffs.
3. Assumptions made about module purposes or architecture (explicitly label uncertainty)

## Discovery and Filtering

- Prefer `git ls-files` to enumerate files (tracked-only). If not a git repo, fall back to `rg --files`
- Ignore common heavy/generated directories: `node_modules`, `dist`, `build`, `vendor`, `.venv`, `.git`, `__pycache__`, `target`, `.next`, `.cache`
- If a directory contains both generated and source content, note that in **Known Gotchas**

## Analysis Process

Understand how the system *works*, not just what files exist. Later findings should revise earlier conclusions.

- Read existing docs (README, docs/, prior codemap) and treat them as hypotheses to verify against code
- Trace core operations end-to-end — from entry point through function calls to output
- Map component boundaries by reading public interfaces, exports, and shared types
- Trace imports between components to build the dependency graph — read source, do not infer from file names
- Read schemas, type definitions, and core data structures
- Check tests for intended behavior, edge cases, and invariants
- Verify your model: does your understanding of component A match how component B uses it? Name remaining uncertainties explicitly. A wrong codemap is worse than an incomplete one.

## Output Format

Generate a markdown document with the sections below. **Omit any section that would be empty or trivial for the codebase.** Include a `Last updated: YYYY-MM-DD` line at the top of the document. If `docs/decisions/` exists, add a link to it below the date.

### Overview (3-5 sentences)

Describe the overall system: what it does, the architectural pattern (monolith, microservices, layered, etc.), and the primary technologies/frameworks.

### Directory Structure

```text
project_root/
├── dir_name/          # one-line purpose
│   ├── subdir/        # one-line purpose
```

Only include directories containing source code, configuration, infrastructure, and architecture-relevant docs. Skip generated files, caches, and vendor directories. Annotate each with its purpose.

### Top-Level Files

List top-level files critical for build, runtime, or configuration (e.g., `pyproject.toml`, `package.json`, `go.mod`, `Dockerfile`, CI configs). Keep this short.

### Key Entry Points

List the files where execution begins or where an agent should start reading to understand a feature:

- `path/to/file.py` — what it initializes or controls
- If entry points are framework-driven or dynamic, list the canonical start paths (e.g., framework config, routing, app factory) and note the indirection

### Component Boundaries

For each major component, module, or package, describe what it owns and how it relates to other components. This section serves both navigation (finding code) and planning (understanding relationships and constraints).

#### \<Component Name>

- **Owns**: what this component is responsible for (one sentence)
- **Key files**: the 2-4 most important files and what they do
- **Interface**: what it exposes to other components (APIs, types, events, CLI surface)
- **Depends on**: internal components this one imports from
- **Depended on by**: internal components that import from this one
- **Invariants**: checkable assumptions this component enforces or relies on (omit if none)

If dependencies or invariants are not clearly inferable from code inspection, mark them as "uncertain" and explain what evidence is missing. If a component's purpose is unclear, explicitly state that.

### Data Flow

Describe how data moves through the system as-built:

- Inputs → processing stages → outputs
- State ownership (in-memory, database, filesystem, external service)
- Key handoff points between components

Keep brief. A simple diagram in a code fence is welcome if it adds clarity.

### Domain Concepts → Code Locations

Map domain concepts to their implementation locations:

| Concept | Primary Location | Notes |
| --- | --- | --- |
| *Domain concept A* | `src/module_a/` | Brief note |

Replace placeholder rows with actual domain concepts. If the codebase is not domain-driven, rename this section to **Feature → Code Locations**.

### Invariants

System-wide rules that hold across components:

- Dependency direction constraints
- State ownership rules
- Concurrency/threading model
- Error handling strategy and boundaries
- Performance constraints (only if measured and enforced)

Only include invariants observable in the current code. Mark any that appear intended but unenforced as "unenforced".

### Cross-Cutting Concerns

Where to find shared mechanisms: logging, configuration loading, error types, shared utilities, type definitions, constants.

### Conventions and Patterns

Recurring patterns an agent should follow when making changes:

- Naming conventions (e.g., `*_solver.py` for solver classes)
- Where new features should be added
- How configuration is loaded
- Error handling patterns
- Testing patterns and where tests live relative to source

### Search Anchors

High-value symbols (functions, classes, config keys, env vars) an agent can search for, with file paths.

### Known Gotchas

Non-obvious things that might trip up an agent:

- Circular import risks
- Files that look similar but serve different purposes
- Legacy code that doesn't follow current conventions
- Environment-specific behavior
- Multiple services or packages that look like one repo but are separate deployables
- Documentation that conflicts with observed code structure

## Guidelines

- This document is **descriptive**: it describes the system as-built, not how it should be. If design rationale is documented in `docs/decisions/`, link to relevant records rather than restating them. If no such directory exists, do not reference it.
- Optimize for **navigation and planning**, not exhaustive documentation. Assume the agent can read the code once it knows where to look.
- Be **concrete**: use actual file paths, not abstract descriptions.
- Be **terse**: one line per item where possible.
- Target size: **be concise yet complete**.
- **Omit** obvious things (e.g., don't document that `__init__.py` makes a directory a package).
- **Prioritize** by importance: put the things an agent is most likely to need first.
- If the codebase has a README or existing architecture docs, incorporate their information but reformat for agent consumption.
- Keep ordering stable (alphabetical within sections where it doesn't fight priority) to reduce churn between updates.
