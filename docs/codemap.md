Last updated: 2026-02-08

# Codemap

## Overview

This repository is a configuration hub for AI coding agents (Claude Code and OpenAI Codex). It stores shared behavioral directives in a single markdown file, reusable skill definitions, and lightweight helper scripts that skills can execute. A shell script deploys everything to each tool's config directory. Most content is declarative markdown, with minimal shell automation for deployment and skill execution.

## Directory Structure

```text
agent-config/
├── docs/              # documentation (codemap lives here)
├── skills/            # reusable skill definitions
│   ├── field-notes/   # session knowledge capture skill
│   ├── map-code/      # codebase mapping skill
│   ├── peer-review/   # bounded cross-agent review workflow
│   └── reflect/       # session retrospective skill
```

## Top-Level Files

| File | Purpose |
| ---- | ------- |
| `.gitignore` | Excludes local peer-review artifacts in `.agent-chat/` from version control |
| `default.md` | Shared base instructions for all agents (synced to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`) |
| `readme.md` | Repository overview |
| `sync.sh` | Deployment script — copies config to Claude Code and Codex directories |

## Key Entry Points

- `default.md` — canonical source for agent behavior; start here to understand what directives agents receive
- `sync.sh` — understand how configuration reaches target tools
- `skills/*/SKILL.md` — each skill's definition and trigger conditions

## Component Boundaries

### `default.md` (Agent Directives)

- **Owns**: All shared behavioral rules — communication style, reasoning approach, development philosophy, coding rules, document authority hierarchy, spec/plan/decision protocols
- **Key files**: `default.md`
- **Interface**: Consumed by Claude Code (as `~/.claude/CLAUDE.md`) and Codex (as `~/.codex/AGENTS.md`)
- **Depends on**: Nothing
- **Depended on by**: `sync.sh` (copies it to targets)
- **Invariants**: References document conventions (`docs/spec.md`, `docs/decisions/`, `docs/codemap.md`, `docs/field-notes.md`) that exist in consuming projects, not in this repo

### `sync.sh` (Deployment)

- **Owns**: Copying config files from this repo to `~/.claude/` and `~/.codex/`
- **Key files**: `sync.sh`
- **Interface**: Run manually; copies `default.md` and `skills/*` to target directories
- **Depends on**: `default.md`, `skills/`
- **Depended on by**: Nothing (manual invocation only)
- **Invariants**: Expects `$HOME/agent-config` as source path (hardcoded in `SOURCE_DIR`)

### `skills/field-notes/`

- **Owns**: Skill definition for appending session lessons to `docs/field-notes.md` in consuming projects
- **Key files**: `SKILL.md` — YAML frontmatter (`name: field-notes`) + prompt body
- **Interface**: Invoked as `/field-notes` by agents
- **Depends on**: Nothing
- **Depended on by**: Nothing (consumed by agents at runtime)

### `skills/map-code/`

- **Owns**: Skill definition for generating `docs/codemap.md` files in any codebase
- **Key files**: `SKILL.md` — YAML frontmatter (`name: map-code`) + prompt body
- **Interface**: Invoked as `/map-code` by agents
- **Depends on**: Nothing
- **Depended on by**: Nothing (consumed by agents at runtime)

### `skills/reflect/`

- **Owns**: Skill definition for end-of-session retrospectives
- **Key files**: `SKILL.md` — YAML frontmatter (`name: reflect`) + prompt body
- **Interface**: Invoked as `/reflect` by agents
- **Depends on**: Nothing
- **Depended on by**: Nothing (consumed by agents at runtime)

### `skills/peer-review/`

- **Owns**: User-driven cross-agent peer review with transport probe, direct invocation, and file-handoff fallback
- **Key files**:
  - `SKILL.md` — caller procedure (init → context → invoke → evaluate → iterate → synthesize) + pickup procedure for handoff
  - `README.md` — usage, configuration, session artifacts, known limitations
  - `templates/prompt.md` — reviewer prompt with flexible evaluation criteria and VERDICT/ISSUES/CHANGE_REQUESTS output format
  - `scripts/peer-review.sh` — 3 commands: `init` (session creation with label), `invoke` (probe + CLI invocation + response capture), `cleanup` (safe deletion with path validation)
- **Interface**: Invoked as `/peer-review <target>`, `ask codex`/`ask claude`, or `/peer-review pickup <session-dir>`; script accepts `init|invoke|cleanup` subcommands
- **Depends on**: Local `codex` and/or `claude` CLI binaries; GNU `timeout`; `mktemp`
- **Depended on by**: Nothing (consumed by agents at runtime)
- **Invariants**:
  - `context.md` includes conversation log (user messages verbatim, key agent decisions) plus file pointers; reviewer inspects repo files directly
  - `.agent-chat/.gitignore` is auto-created with `*` in the active workspace
  - Session dirs under `.agent-chat/{timestamp}-{label}-XXXXXX` contain `.workspace_root` marker file; created via `mktemp -d` for collision safety
  - `invoke` and `cleanup` both canonicalize and validate session dir (parent must be `.agent-chat/`, marker must exist and match ancestry)
  - `.workspace_root` value must match session dir ancestry (marker tampering is rejected)
  - `invoke` enforces `PEER_REVIEW_MAX_ROUNDS` (default 2); exceeding the cap exits with an error
  - Retries archive prior `round-N-{request,response,error,invoke.log}` artifacts as `*.prev-*`
  - Codex reviewer writes final verdict text to `round-N-response.md` and raw transcript to `round-N-invoke.log`
  - Agents must use fully resolved absolute script paths in all Bash commands (no shell variables) for permission pattern matching
  - `claude -p` invoked with `< /dev/null` to prevent stdin hang
  - Exit code 0 = success, 1 = invocation failure, 2 = transport unavailable

## Data Flow

```text
default.md ──┐
             ├── sync.sh ──┬── ~/.claude/CLAUDE.md
skills/*/ ───┘             ├── ~/.claude/skills/*/
                           ├── ~/.codex/AGENTS.md
                           └── ~/.codex/skills/*/
```

- All state is on the filesystem — no databases, no external services
- `sync.sh` is a one-way copy; no feedback from targets to source

## Feature → Code Locations

| Feature | Primary Location | Notes |
| ------- | ---------------- | ----- |
| Agent behavior directives | `default.md` | Communication, reasoning, coding rules, doc authority |
| Codebase mapping | `skills/map-code/SKILL.md` | Generates navigation maps for repos |
| Config deployment | `sync.sh` | Copies to `~/.claude/` and `~/.codex/` |
| Cross-agent peer review | `skills/peer-review/` | Bounded review loop with explicit session lifecycle and repo-local artifacts |
| Session knowledge capture | `skills/field-notes/SKILL.md` | Appends lessons to `docs/field-notes.md` |
| Session retrospectives | `skills/reflect/SKILL.md` | Structured feedback at session end |

## Conventions and Patterns

- **Skill structure**: Each skill must include `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`); skills may optionally include helper scripts or prompt templates in the same directory
- **Naming**: Skill directories use lowercase kebab-case; directory name matches frontmatter `name`
- **Adding new skills**: Create `skills/<name>/SKILL.md` with frontmatter; run `sync.sh` to deploy
- **Config changes**: Edit `default.md`, then run `sync.sh` to propagate

## Search Anchors

| Symbol | File | Purpose |
| ------ | ---- | ------- |
| `CLAUDE_DIR` | `sync.sh` | Target path for Claude Code config |
| `CODEX_DIR` | `sync.sh` | Target path for Codex config |
| `SOURCE_DIR` | `sync.sh` | Source path (hardcoded to `$HOME/agent-config`) |
| `docs/codemap.md` | `default.md`, `skills/map-code/SKILL.md` | Expected codemap output location |
| `docs/field-notes.md` | `default.md`, `skills/field-notes/SKILL.md` | Expected field notes location |
| `docs/spec.md` | `default.md` | Spec file convention referenced in authority hierarchy |
| `field-notes` | `skills/field-notes/SKILL.md` | Skill name (invoked as `/field-notes`) |
| `map-code` | `skills/map-code/SKILL.md` | Skill name (invoked as `/map-code`) |
| `.agent-chat` | runtime workspace directory | Stores local peer-review session artifacts; excluded by `.gitignore` |
| `peer-review` | `skills/peer-review/SKILL.md` | Skill name (invoked as `/peer-review`) |
| `PEER_REVIEW_SKILL_DIR` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Configurable absolute base path for skill assets |
| `PEER_REVIEW_TIMEOUT` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Timeout budget per reviewer call (default 300s) |
| `PEER_REVIEW_PROBE` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Enable transport probe before invoke (default 0, set 1 to enable) |
| `PEER_REVIEW_PROBE_TIMEOUT` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Timeout budget per transport probe when enabled (default 45s) |
| `PEER_REVIEW_MAX_ROUNDS` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Maximum round number allowed per session (default 2) |
| `peer-review.sh` | `skills/peer-review/scripts/peer-review.sh` | Session lifecycle: `init`, `invoke`, `cleanup` |
| `prompt.md` | `skills/peer-review/templates/prompt.md` | Shared reviewer prompt template |
| `reflect` | `skills/reflect/SKILL.md` | Skill name (invoked as `/reflect`) |

## Known Gotchas

- **Sync overwrites skills**: `sync.sh` overwrites existing skill files in target directories; manually-added skills in `~/.claude/skills/` or `~/.codex/skills/` with the same name will be replaced
- **No validation**: `sync.sh` does not validate markdown syntax or skill frontmatter before copying
- **Hardcoded source path**: `sync.sh` uses `SOURCE_DIR="$HOME/agent-config"` — will break if the repo is cloned elsewhere
- **Two consumers, one source**: Changes to `default.md` affect both Claude Code and Codex; tool-specific directives would require restructuring
