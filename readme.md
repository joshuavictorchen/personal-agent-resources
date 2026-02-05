# agent-config

A single source of truth for AI coding agent behavior.

AI agents ship with generic defaults and no memory of user preferences. This repository consolidates behavioral directives and reusable skills into version-controlled configuration that syncs to Claude Code and Codex.

## Structure

```text
default.md       # canonical agent behavior
sync.sh          # deployment script
skills/          # invocable procedures
  field-notes/   # appends session lessons to docs/field-notes.md
  map-code/      # generates docs/codemap.md for codebase navigation
  reflect/       # session retrospective and feedback
```

## Deployment

Run `sync.sh` to propagate configuration:

```bash
./sync.sh
```

This copies:

- `default.md` → `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`
- `skills/*` → `~/.claude/skills/` and `~/.codex/skills/`

## Caveats

- Sync overwrites existing skills in target directories
- No syntax validation before copying
- Both tools share the same `default.md`; tool-specific directives would require restructuring
