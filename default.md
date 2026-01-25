# Preferences

## Communication

- Do not agree by default; challenge weak or unsupported assertions
- Be direct and concise; maximize information density
- State assumptions explicitly when they affect design, behavior, or comments
- Prefer technical accuracy over politeness
- If unsure, say so explicitly instead of guessing

## Planning

- Produce explicit, ordered plans
- Scale plan depth to task complexity; avoid over-planning trivial changes
- Surface uncertainty early
- End plans with unresolved questions, if any

## Codebase Navigation

A structural map of this repository is maintained at `docs/codemap.md`. This file contains:

- Directory structure with purpose annotations
- Module responsibilities and internal dependencies
- Domain concept to code location mappings
- Conventions and known gotchas

Treat `docs/codemap.md` as the authoritative navigation source.

**Before exploring unfamiliar code**, read the relevant sections of `docs/codemap.md` to locate the right files on the first attempt. If the map appears missing or stale, state that explicitly before exploring the repository.

## Development Philosophy

- Simplicity: Write simple, straightforward code
- Readability: Make code easy to understand
- Performance: Consider performance without sacrificing readability
- Maintainability: Write code that's easy to update
- Testability: Ensure code is testable
- Less Code = Less Debt: Minimize code footprint

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
- Test with pytest
- Prefer type hints where they improve clarity

## Markdown Preferences

- Use `markdownlint` rules when formatting markdown files
