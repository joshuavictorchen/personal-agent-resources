---
name: map-code
description: Analyzes this codebase and generates a structured map optimized for AI agent navigation. The map enables agents to locate relevant code quickly without exploring the filesystem.
---

# Code Mapping

Analyze this codebase and generate a structured map optimized for AI agent navigation. The map should enable an agent to locate relevant code quickly without exploring the filesystem.

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

## Output Format

Generate a markdown document with these sections. **Omit any section that would be empty or trivial for the codebase.**

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

If a few top-level files are critical for build/runtime or configuration, list them here (e.g., `pyproject.toml`, `package.json`, `go.mod`, `Dockerfile`, CI configs). Keep this short.

### Key Entry Points

List the files where execution begins or where an agent should start reading to understand a feature:

- `path/to/file.py` — what it initializes or controls
- If entry points are framework-driven or dynamic, list the canonical start paths (e.g., framework config, routing, app factory) and note the indirection

### Module Responsibilities

For each major module/package:

- **Purpose**: One sentence describing what this module owns
- **Key files**: The 2-4 most important files and what they do
- **Dependencies**: What other internal modules this one imports from (if clearly inferable; otherwise mark uncertain)
- **Dependents**: What other internal modules import from this one (if clearly inferable; otherwise mark uncertain)

If a module's purpose or role is unclear from code inspection, explicitly mark it as "uncertain" and explain what evidence is missing.

### Domain Concepts → Code Locations

Map domain concepts to their implementation locations. Otherwise, replace this section with **Feature → Code Locations**:

| Concept | Primary Location | Notes |
| ------- | ---------------- | ----- |
| *[Domain concept A]* | *[src/module_a/]* | *[Brief note]* |
| *[Domain concept B]* | *[src/module_b/file.py]* | *[Brief note]* |

Replace these placeholder rows with actual domain concepts from the repository.

### Conventions and Patterns

Recurring patterns an agent should follow:

- Naming conventions (e.g., `*_solver.py` for solver classes)
- Where new features should be added
- How configuration is loaded
- Error handling patterns
- Testing patterns and where tests live relative to source

### Cross-Cutting Concerns

Where to find: logging, shared utilities, type definitions, constants, global configuration.

### Search Anchors

List high-value symbols (functions, classes, config keys, env vars) an agent can search for, with file paths.

### Known Gotchas

List non-obvious things that might trip up an agent:

- Circular import risks
- Files that look similar but serve different purposes
- Legacy code that doesn't follow current conventions
- Environment-specific behavior
- Numerical precision pitfalls (if applicable)
- Multiple services or packages that look like one repo but are separate deployables
- README/architecture docs that conflict with observed code structure

## Guidelines

- Optimize for **navigation**, not documentation. Assume the agent can read the code once it knows where to look.
- Be **concrete**: use actual file paths, not abstract descriptions.
- Be **terse**: one line per item where possible.
- Target size: **be concise yet complete**.
- **Omit** obvious things (e.g., don't document that `__init__.py` makes a directory a package).
- **Prioritize** by importance: put the things an agent is most likely to need first.
- If the codebase has a README or existing architecture docs, incorporate their information but reformat for agent consumption.
- Keep ordering stable (alphabetical within sections where it doesn't fight priority) to reduce churn between updates.
