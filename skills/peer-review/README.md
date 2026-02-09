# peer-review

Cross-agent peer review skill for Claude Code and Codex. When invoked, the calling agent gathers context, sends it to a reviewer agent via CLI, iterates on disagreements, and presents actionable results — all within the same session.

## Requirements

At least one of:
- `claude` CLI (Claude Code)
- `codex` CLI (OpenAI Codex)

GNU `timeout` (from coreutils) for invocation safety.

## Usage

From any Claude Code or Codex session:

| Phrase | Effect |
|--------|--------|
| `ask codex` | Invoke Codex as reviewer |
| `ask claude` | Invoke Claude as reviewer |
| `/peer-review codex` | Same (explicit) |
| `/peer-review claude` | Same (explicit) |
| `/peer-review pickup <path>` | Act as reviewer for a handoff request |

### What can be reviewed

Anything the caller can describe in context: code, plans, architecture decisions, claims, debugging approaches, specs, test strategies, etc. The caller includes conversation history so the reviewer understands intent, and points to repo files so the reviewer can inspect artifacts directly.

## Process flow

### Direct invocation (Claude → Claude, Claude → Codex)

```
caller                          script                          reviewer
  │                               │                               │
  ├─ init "label"────────────────►│                               │
  │◄─ session dir path────────────┤                               │
  │                               │                               │
  ├─ write context.md             │                               │
  │                               │                               │
  ├─ invoke <target> <dir> 1─────►│                               │
  │                               ├─ [probe if enabled] ─────────►│
  │                               ├─ assemble round-1-request.md  │
  │                               ├─ invoke reviewer (300s)──────►│
  │                               │                               ├─ read request
  │                               │                               ├─ inspect repo
  │                               │◄─ response───────────────────┤
  │                               ├─ write round-1-response.md   │
  │◄─ exit 0──────────────────────┤                               │
  │                               │                               │
  ├─ read response                │                               │
  ├─ evaluate verdict             │                               │
  │                               │                               │
  │  [if DISAGREE and rebuttal warranted]                         │
  ├─ write round-2-rebuttal.md    │                               │
  ├─ invoke <target> <dir> 2─────►│               ... repeat ...  │
```

### File handoff (when direct invocation fails)

When the probe fails (exit code 2), direct transport is unavailable:

1. Caller tells user: "Review request ready. Run `/peer-review pickup <path>` in the other agent."
2. User switches to the other agent and triggers pickup.
3. Reviewer reads the request, inspects the repo, writes the response file.
4. User switches back. Caller reads the response and continues.

## One-time approval bootstrap (Codex)

Codex may require elevated permission to run reviewer subprocesses. Do this once, then choose the persistent/always option in the approval UI.

```bash
# from the target repo — use your actual absolute home path
/home/user/.codex/skills/peer-review/scripts/peer-review.sh init "bootstrap"
# capture the session dir from output, then:
printf '- bootstrap transport approval\n' > /path/to/session-dir/context.md
/home/user/.codex/skills/peer-review/scripts/peer-review.sh invoke claude /path/to/session-dir 1
```

Important — use fully resolved absolute paths (no `$HOME`, `$SCRIPT`, or other variables):
- persist approval for the command prefix: the literal path to `peer-review.sh` followed by any subcommand
- this single prefix covers both reviewer targets (`codex` and `claude`)
- set the equivalent permission in Claude sessions via `~/.claude/settings.json`:
  ```json
  {"permissions": {"allow": ["Bash(/home/user/.claude/skills/peer-review/scripts/peer-review.sh *)"]}}
  ```

## Session artifacts

Sessions are stored in `<repo>/.agent-chat/{timestamp}-{label}/`. A `.gitignore` with `*` is auto-created to prevent commits. Each session contains:

- `context.md` — caller's context and review scope
- `round-N-request.md` — assembled request (prompt + context + instructions)
- `round-N-response.md` — reviewer output
- `round-N-rebuttal.md` — caller's counter-arguments (round 2+)
- `round-N-invoke.log` — raw CLI transcript for Codex reviewer calls
- `round-N-error.txt` — only on failure
- `*.prev-*` — archived artifacts from prior retry attempts for the same round

Sessions persist for inspection. Clean up via:

```bash
/home/user/.claude/skills/peer-review/scripts/peer-review.sh cleanup <session-dir>
```

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PEER_REVIEW_TIMEOUT` | `300` | Seconds per reviewer call |
| `PEER_REVIEW_PROBE` | `0` | Set to `1` to enable transport probe before invoke |
| `PEER_REVIEW_PROBE_TIMEOUT` | `45` | Seconds per transport probe (when enabled) |
| `PEER_REVIEW_MAX_ROUNDS` | `2` | Maximum round number allowed per session |
| `PEER_REVIEW_SKILL_DIR` | `$HOME/.claude/skills/peer-review` | Skill directory override |

## Known limitations

- **Codex sandbox may block CLI invocation**: Codex's sandboxed environment may not allow calling `claude -p` or `codex exec` as subprocesses. Enable the transport probe (`PEER_REVIEW_PROBE=1`) to detect this early — it exits with code 2 and provides a pickup command for manual handoff.
- **Reviewer is read-only**: Claude reviewers run with `--tools Read,Grep,Glob` and cannot execute shell commands or modify files.
- **Probe is disabled by default**: The transport probe adds latency and token cost per round. Enable with `PEER_REVIEW_PROBE=1` when working in unfamiliar environments or when CLI availability is uncertain.
