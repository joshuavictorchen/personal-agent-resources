---
name: field-notes
description: End-of-session knowledge capture. Appends lessons learned to docs/field-notes.md for future agent context.
---

# Field Notes

Capture lessons learned during this session and append them to `docs/field-notes.md`.

## Output Location

Append to `docs/field-notes.md`. If the file does not exist, create it with a `# Field Notes` heading.

## Process

- Read existing field notes to avoid duplicates
- Review the session for insights a future agent would benefit from knowing
- Draft entries and present them to the user for approval before appending
- Append approved entries under today's date heading (`## YYYY-MM-DD`); reuse the heading if it already exists

## Quality Bar

Each entry must pass: **"Would a future agent benefit from knowing this?"**

Worth capturing:

- Runtime surprises, subtle bugs, misleading behavior
- Approaches that were tried and failed, with why
- Non-obvious findings about the codebase or dependencies
- Workarounds and their context

Not worth capturing:

- Routine progress (that's git history)
- Anything already in a decision record
- Anything discoverable from a fresh code scan (that's codemap territory)

## Format

Terse bullets under date headings. Reference files or lines when relevant.

```markdown
# Field Notes

## 2026-02-03

- OAuth token refresh silently fails when clock skew >30s; added tolerance in `auth/token.py`
- Batch inserts bypass FK constraints in SQLAlchemy 2.x — use individual inserts in `db/writers.py`

## 2026-02-01

- Config env var overrides only apply after `Settings.init()` — loading order matters
```
