# peer-review

Cross-agent peer review skill. When invoked, the calling agent gathers context, sends it to a reviewer agent (Claude or Codex) via CLI, iterates on disagreements, and presents actionable results — all within the same session.

## Requirements

At least one of:
- `claude` CLI (Claude Code)
- `codex` CLI (OpenAI Codex)

GNU `timeout` (from coreutils) for invocation safety.

## Usage

From any agent session:

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

### Direct invocation

```
caller                          script                          reviewer
  │                               │                               │
  ├─ init "label"────────────────►│                               │
  │◄─ session dir path────────────┤                               │
  │                               │                               │
  ├─ write context.md             │                               │
  │                               │                               │
  ├─ invoke <target> <dir> 1─────►│                               │
  │                               ├─ assemble round-1-request.md  │
  │                               ├─ invoke reviewer (600s)──────►│
  │                               │                               ├─ read request
  │                               │                               ├─ inspect repo
  │                               │◄─ response────────────────────┤
  │                               ├─ write round-1-response.md    │
  │◄─ exit 0──────────────────────┤                               │
  │                               │                               │
  ├─ read response                │                               │
  ├─ evaluate findings            │                               │
  │                               │                               │
  │  [if any findings warrant iteration]                          │
  ├─ write round-2-followup.md    │                               │
  ├─ invoke <target> <dir> 2─────►│               ... repeat ...  │
```

#### Agent-specific invocation notes

| Caller | Target | Behavior |
|--------|--------|----------|
| Claude | Claude | Works directly |
| Claude | Codex  | Works directly |
| Codex  | Claude | Requires elevated permissions (sandbox blocks Claude CLI) |
| Codex  | Codex  | Works directly |

### File handoff (when direct invocation fails)

When `invoke` exits with code `2`, direct transport is unavailable:

1. Caller tells user: "Review request ready. Run `/peer-review pickup <path>` in the other agent."
2. User switches to the other agent and triggers pickup.
3. Reviewer reads the request, inspects the repo, writes the response file.
4. User switches back. Caller reads the response and continues.

## One-time permission setup

Both agents need a one-time setup so `invoke` runs without manual approval prompts.

### Claude Code

Add the script to allowed commands in `~/.claude/settings.json`:

```json
{"permissions": {"allow": ["Bash(/home/<user>/.claude/skills/peer-review/scripts/peer-review.sh *)"]}}
```

Replace `<user>` with your system username.

### Codex

Run a bootstrap invoke and persist approval for the command prefix:

```bash
/home/<user>/.codex/skills/peer-review/scripts/peer-review.sh init "bootstrap"
# write context.md in the printed session dir, then:
/home/<user>/.codex/skills/peer-review/scripts/peer-review.sh invoke claude <session-dir> 1
```

In the approval UI, persist the prefix: `/home/<user>/.codex/skills/peer-review/scripts/peer-review.sh invoke`

One prefix covers both `invoke claude` and `invoke codex`.

### Important for both agents

- Use fully resolved absolute paths (no `$HOME`, `$SCRIPT`, or other variables) — permission systems match command strings literally
- Run `invoke` as a standalone command (no `;`, `&&`, loops) so prefix matching stays deterministic

## Session artifacts

Sessions are stored in `<repo>/.agent-chat/<yymmdd>-<hhmm>-<label>[-N]/` (numeric suffix on collision). A `.gitignore` with `*` is auto-created to prevent commits. Each session contains:

- `context.md` — caller's structured context: review scope, task summary, open questions, recent conversation, file pointers
- `round-N-request.md` — assembled request (prompt + context + instructions)
- `round-N-response.md` — reviewer output
- `round-N-followup.md` — caller's rebuttals, proposed solutions, or both (round 2+)
- `round-N-invoke.log` — CLI diagnostic output
- `round-N-error.txt` — only on failure

Sessions persist for inspection. Clean up via:

```bash
<script> cleanup <session-dir>
```

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PEER_REVIEW_TIMEOUT` | `600` | Seconds per reviewer call |
| `PEER_REVIEW_MAX_ROUNDS` | `3` | Maximum round number allowed per session |
| `PEER_REVIEW_SKILL_DIR` | auto-detected | Skill directory override (resolved from script location) |

## Known limitations

- **Codex sandbox blocks Claude CLI**: Codex callers targeting Claude must use elevated permissions. The script detects this and exits with code `2`, printing the elevated rerun command.
- **Reviewer is read-only**: Claude reviewers use `Read,Grep,Glob` only. Codex reviewers run in read-only sandbox. Neither modifies files.
- **No cross-agent RPC**: When direct CLI invocation fails, the fallback is user-mediated file handoff.
