Last updated: 2026-02-09

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

- **Owns**: User-driven cross-agent peer review with direct CLI invocation and file-handoff fallback
- **Key files**:
  - `SKILL.md` — caller procedure (init → context → invoke → evaluate → iterate → synthesize) + pickup procedure for handoff
  - `README.md` — usage, configuration, session artifacts, known limitations
  - `templates/prompt.md` — reviewer prompt with evaluation criteria, principles, and VERDICT/SUMMARY/FINDINGS output format (MUST_FIX/SHOULD_FIX/SUGGESTION/POSITIVE categories)
  - `scripts/peer-review.sh` — 3 commands: `init` (session creation with label), `invoke` (request assembly + reviewer invocation + transport classification), `cleanup` (safe deletion with path validation)
- **Interface**: Invoked as `/peer-review <target>`, `ask codex`/`ask claude`, or `/peer-review pickup <session-dir>`; script accepts `init|invoke|cleanup` subcommands
- **Depends on**: Local `codex` and/or `claude` CLI binaries; GNU `timeout`
- **Depended on by**: Nothing (consumed by agents at runtime)
- **Invariants**:
  - `context.md` includes structured sections: review scope, task summary, open questions, recent conversation (~100 line cap), file pointers; reviewer inspects repo files directly
  - `.agent-chat/.gitignore` is auto-created with `*` in the active workspace
  - Session dirs under `.agent-chat/<yymmdd>-<hhmm>-<label>[-N]` contain `.workspace_root` marker file; collisions append a numeric suffix via atomic `mkdir`
  - `invoke` and `cleanup` both canonicalize and validate session dir (parent must be `.agent-chat/`, marker must exist and match ancestry)
  - `.workspace_root` value must match session dir ancestry (marker tampering is rejected)
  - `invoke` enforces `PEER_REVIEW_MAX_ROUNDS` (default 3); exceeding the cap exits with an error
  - Default reviewer timeout is 600s (10 min); override with `PEER_REVIEW_TIMEOUT`
  - Retries archive prior `round-N-{request,response,error,invoke.log}` artifacts as `*.prev-*`
  - Codex caller with `target=claude` must invoke with elevated permissions on the first attempt (documented in SKILL.md operational rule)
  - Codex reviewer writes verdict to `round-N-response.md` (via `--output-last-message` when available; falls back to full transcript) and raw output to `round-N-invoke.log`
  - Agents must use fully resolved absolute script paths in all Bash commands (no shell variables) for permission pattern matching
  - Reviewer output is a read-only proposal (VERDICT/SUMMARY/FINDINGS with MUST_FIX/SHOULD_FIX/SUGGESTION/POSITIVE); caller presents to user for accept/reject unless yolo mode
  - Round 2+ requests point reviewers to all session artifacts (`context.md`, `round-N-*` files) for full conversation history
  - Codex `--output-last-message` has transcript fallback: if flag produces empty output on success, full transcript is used; retries without flag on non-timeout failure
  - Claude invocation checks local runtime accessibility (`claude` on PATH, writable `$HOME`) and returns transport-unavailable immediately when blocked
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
| `PEER_REVIEW_TIMEOUT` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Timeout budget per reviewer call (default 600s) |
| `PEER_REVIEW_MAX_ROUNDS` | `skills/peer-review/SKILL.md`, `skills/peer-review/scripts/peer-review.sh` | Maximum round number allowed per session (default 3) |
| `peer-review.sh` | `skills/peer-review/scripts/peer-review.sh` | Session lifecycle: `init`, `invoke`, `cleanup` |
| `prompt.md` | `skills/peer-review/templates/prompt.md` | Shared reviewer prompt template |
| `reflect` | `skills/reflect/SKILL.md` | Skill name (invoked as `/reflect`) |

## Known Gotchas

- **Sync overwrites skills**: `sync.sh` overwrites existing skill files in target directories; manually-added skills in `~/.claude/skills/` or `~/.codex/skills/` with the same name will be replaced
- **No validation**: `sync.sh` does not validate markdown syntax or skill frontmatter before copying
- **Hardcoded source path**: `sync.sh` uses `SOURCE_DIR="$HOME/agent-config"` — will break if the repo is cloned elsewhere
- **Two consumers, one source**: Changes to `default.md` affect both Claude Code and Codex; tool-specific directives would require restructuring
- **Codex→Claude launch context matters**: sandboxed invokes cannot run Claude reliably; caller must launch `invoke claude` with elevated permissions
