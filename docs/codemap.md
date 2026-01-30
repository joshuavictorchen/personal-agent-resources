# Codemap

## Architecture Overview

This repository is a configuration hub for AI coding agents (Claude Code and OpenAI Codex). It contains shared behavioral directives and reusable skill definitions that get synced to each tool's config directory. The architecture is flat—a collection of markdown files with a single shell script for deployment. No runtime code; purely declarative configuration.

## Directory Structure

```text
agent-config/
├── docs/              # documentation (this file)
├── skills/            # reusable skill definitions
│   ├── map-code/      # codebase mapping skill
│   └── reflect/       # session retrospective skill
```

## Top-Level Files

| File | Purpose |
| ---- | ------- |
| `default.md` | Shared base instructions for all agents (synced to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`) |
| `readme.md` | Repository overview |
| `sync.sh` | Deployment script—copies config to Claude Code and Codex directories |

## Key Entry Points

- `default.md` — the canonical source for agent behavior; start here to understand what directives agents receive
- `sync.sh` — understand how configuration reaches target tools
- `skills/*/SKILL.md` — each skill's definition and trigger conditions

## Module Responsibilities

### `skills/map-code/`

- **Purpose**: Defines a skill that generates `docs/codemap.md` files for any codebase
- **Key files**: `SKILL.md` — skill metadata and full prompt template
- **Dependencies**: None
- **Dependents**: None (consumed by agents at runtime)

### `skills/reflect/`

- **Purpose**: Defines a session retrospective skill for post-task debriefs
- **Key files**: `SKILL.md` — skill metadata and structured output template
- **Dependencies**: None
- **Dependents**: None (consumed by agents at runtime)

## Feature → Code Locations

| Feature | Primary Location | Notes |
| ------- | ---------------- | ----- |
| Agent behavior directives | `default.md` | Communication, planning, execution, coding rules |
| Skill definitions | `skills/*/SKILL.md` | YAML frontmatter + markdown body |
| Config deployment | `sync.sh` | Copies to `~/.claude/` and `~/.codex/` |
| Codebase mapping | `skills/map-code/SKILL.md` | Generates navigation maps for repos |
| Session retrospectives | `skills/reflect/SKILL.md` | Structured feedback at session end |

## Conventions and Patterns

- **Skill structure**: Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) followed by the skill prompt
- **Naming**: Skill directories use lowercase kebab-case
- **Adding new skills**: Create `skills/<name>/SKILL.md` with frontmatter; `sync.sh` will deploy it
- **Config changes**: Edit `default.md`, then run `sync.sh` to propagate

## Cross-Cutting Concerns

- **Global configuration**: `default.md` defines all shared agent behavior
- **Deployment**: `sync.sh` is the single source of truth for how config reaches tools

## Search Anchors

| Symbol | File | Purpose |
| ------ | ---- | ------- |
| `CLAUDE_DIR` | `sync.sh` | Target path for Claude Code config |
| `CODEX_DIR` | `sync.sh` | Target path for Codex config |
| `docs/codemap.md` | `default.md`, `skills/map-code/SKILL.md` | Expected codemap output location |
| `docs/spec.md` | `default.md` | Spec file convention referenced in authority hierarchy |

## Known Gotchas

- **Sync is destructive for skills**: `sync.sh` overwrites existing skill files in target directories; manually-added skills in `~/.claude/skills/` or `~/.codex/skills/` with the same name will be replaced
- **No validation**: `sync.sh` does not validate markdown syntax or skill frontmatter before copying
- **Two consumers, one source**: Changes to `default.md` affect both Claude Code and Codex; tool-specific directives would require restructuring
- **Skill invocation**: Skills are invoked by their frontmatter `name`, not directory name (e.g., `/reflect`, `/map-code`)
