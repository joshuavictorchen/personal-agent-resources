---
name: peer-review
description: User-driven cross-agent peer review. Use when the user says "ask codex", "ask claude", or requests an independent critique from another agent.
---

# Peer Review

Obtain a constructively critical review from another agent (Codex or Claude) and iterate until agreement or round limit. The calling agent drives the entire process and presents actionable results.

## Trigger Phrases

**Caller role** (you request a review from another agent):
- `ask codex` / `ask claude`
- `/peer-review codex` / `/peer-review claude`

**Reviewer role** (another agent requested your review via file handoff):
- `/peer-review pickup <session-dir>`

## Caller Procedure

### 1. Locate the script

The script is at `scripts/peer-review.sh` relative to this skill directory. Determine your absolute script path from whichever config directory loaded this skill:

| Agent | Script path |
|-------|-------------|
| Claude | `/home/<user>/.claude/skills/peer-review/scripts/peer-review.sh` |
| Codex | `/home/<user>/.codex/skills/peer-review/scripts/peer-review.sh` |

Override with `$PEER_REVIEW_SKILL_DIR/scripts/peer-review.sh` if set.

**Critical**: Use the fully resolved absolute path (with your actual system username, not `<user>`) in every Bash command. Do not use shell variables like `$SCRIPT` or `$HOME` — the permission system matches command strings literally, and variable references will trigger manual approval prompts.
Run `invoke` as a standalone command (no `;`, `&&`, loops, or wrapper scripts) so persisted permission prefixes match reliably.

In the examples below, `<script>` is a placeholder — always substitute your resolved absolute path.

### 2. Create a session

```bash
<script> init "brief label"
```

Pick a short label that identifies the review scope (e.g., "auth-refactor", "plan-review", "perf-claims"). The output is the absolute session directory path — capture it from the command output for use in subsequent steps.

This creates `.agent-chat/<yymmdd>-<hhmm>-<label>[-N]/` in the current repo with a `.workspace_root` marker. The `[-N]` numeric suffix is appended automatically on collision.

### 3. Write context

Write a file called `context.md` inside the session directory. Use your agent's file-writing capability (Claude: Write tool; Codex: shell redirection or heredoc) rather than interactive editing. The reviewer is a fresh process with no access to your chat history — everything it needs must be in this file.

Structure context.md with these sections (use `##` headings — context.md is embedded inside a larger document, so `#` top-level headings break nesting):

**`## Review scope`** (required, first) — One or two sentences stating what to review and what kind of feedback you want. This is the first thing the reviewer reads.

**`## Task summary`** — What the user asked for, what approach was taken, and the current state. Include key decisions and their rationale.

**`## Open questions`** — Anything unresolved that the reviewer should weigh in on.

**`## Recent conversation`** — Quote the last 2-3 user/agent exchanges from your context window, as close to verbatim as possible. These give the reviewer the immediate context leading to the review request. If earlier exchanges are directly relevant to the review scope, include those too. Omit raw tool output (file contents, grep results) — the reviewer can re-inspect files on its own. Truncate long individual turns with `[...truncated...]` and keep this section under ~100 lines total.

Example:
```
**User**: The auth middleware is duplicating token validation — can you refactor it?
**Agent**: I moved the shared validation into `validate_token()` in auth/core.py and updated both middleware paths to call it. [...truncated...]
**User**: Looks good, ask codex to review this before we merge.
```

**`## File pointers`** — Specific locations the reviewer should examine first (e.g., `src/auth.py:45-80`, `docs/plans/auth.md`). Point to content that exists in the repo — the reviewer can inspect files directly.

### 4. Invoke the reviewer

```bash
<script> invoke <target> <session-dir> 1
```

Agent-specific requirements:
- **Claude callers**: both targets work via direct invocation. No special handling needed.
- **Codex callers, target=claude**: run `invoke` with elevated permissions on the first attempt. Codex sandbox blocks Claude CLI runtime access. The script cannot self-escalate; the caller must launch invoke with elevation.
- **Codex callers, target=codex**: normal invoke flow.

Exit codes:
- `0` — success. Read `<session-dir>/round-1-response.md` for the review.
- `2` — transport unavailable. Read `<session-dir>/round-1-error.txt` for details. For `target=claude`, this includes an elevated rerun command. If elevated execution is unavailable, use the pickup command for manual handoff.
- `1` — invocation failed (timeout, empty response). Read error file and report to user.

On retries for the same round, prior artifacts are archived with a `*.prev-*` suffix.

### 5. Evaluate and iterate

You drive iteration autonomously — do not involve the user between rounds. Read the response file. Evaluate each finding by category:

- **MUST_FIX** — accept and fix, reject with strong rationale, or propose an alternative fix.
- **SHOULD_FIX** — same, but rejection is more acceptable if justified.
- **SUGGESTION** — note and decide. No response required unless you disagree.
- **POSITIVE** — acknowledge. Do not break these things during fixes.

If any findings warrant iteration, write `<session-dir>/round-N-followup.md` (where N is the next round number) containing rebuttals, proposed solutions, or both. Repeat critical context from the original review scope if relevant — the round 2+ reviewer is a fresh process that must read files to recover context. Then invoke the next round:

```bash
<script> invoke <target> <session-dir> 2
```

The reviewer validates your proposed solutions and re-evaluates contested points. Continue iterating until converged or the round cap is reached (default: 3, override with `PEER_REVIEW_MAX_ROUNDS`). Do not ask the user whether to continue — use your judgment on whether unresolved findings warrant another round.

**Iteration policy:** iterate on unresolved MUST_FIX and material SHOULD_FIX findings. Do not open new rounds for SUGGESTION-only deltas unless they impact correctness or design risk.

### 6. Present results

After iteration is complete (converged or cap reached), present the consolidated result to the user:

- **Verdict**: final reviewer assessment (AGREE/DISAGREE)
- **Findings**: all MUST_FIX, SHOULD_FIX, and notable SUGGESTION items across all rounds
- **Your position on each**: accepted (with proposed fix), rejected (with rationale), or modified
- **Proposed changes**: specific changes ready for the user to approve or reject

The user sees the end state, not each round. End with the session dir path for artifact inspection.

The user decides what to apply. Do not apply changes without user approval.

**In yolo mode**: apply accepted changes, then report what was done with reasoning. Yolo applies to the results of the iteration process — the caller still iterates normally with the reviewer.

## Reviewer Procedure (Pickup)

When triggered by `/peer-review pickup <session-dir>`:

1. Find the highest-numbered `round-N-request.md` that has no corresponding `round-N-response.md`.
2. Read the request file. It contains the full review prompt, workspace location, and context.
3. Follow the instructions in the request: gather evidence from the repository (Claude: Read, Grep, Glob; Codex: `cat`, `rg`, `find` in read-only sandbox), then evaluate the work.
4. Write your review to the corresponding response file (e.g., `round-1-response.md`) in the same session directory.
5. Tell the user: "Review complete. Response written to `<session-dir>/round-N-response.md`."

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PEER_REVIEW_TIMEOUT` | `600` | Seconds per reviewer CLI call |
| `PEER_REVIEW_MAX_ROUNDS` | `3` | Maximum round number allowed per session |
| `PEER_REVIEW_SKILL_DIR` | auto-detected | Skill directory override (resolved from script location) |
