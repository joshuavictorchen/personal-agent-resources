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

In the examples below, `<script>` is a placeholder — always substitute your resolved absolute path.

### 2. Create a session

```bash
<script> init "brief label"
```

Pick a short label that identifies the review scope (e.g., "auth-refactor", "plan-review", "perf-claims"). The output is the absolute session directory path — capture it from the command output for use in subsequent steps.

This creates `.agent-chat/{timestamp}-{label}/` in the current repo with a `.workspace_root` marker.

### 3. Write context

Write a file called `context.md` inside the session directory (use the Write tool, not Bash). The reviewer is a fresh process with no access to your chat history — everything it needs must be in this file.

Structure context.md with these sections (use `##` headings — context.md is embedded inside a larger document, so `#` top-level headings break nesting):

**`## Review scope`** (required, first) — One or two sentences stating what to review and what kind of feedback you want. This is the first thing the reviewer reads.

**`## Task summary`** — What the user asked for, what approach was taken, and the current state. Include key decisions and their rationale.

**`## Open questions`** — Anything unresolved that the reviewer should weigh in on.

**`## Recent conversation`** — Quote the last 2-3 user/agent exchanges from your context window, as close to verbatim as possible. These give the reviewer the immediate context leading to the review request. If earlier exchanges are directly relevant to the review scope, include those too. Omit raw tool output (file contents, grep results) — the reviewer can re-inspect files on its own. Truncate long individual turns with `[...truncated...]` and keep this section under ~100 lines total.

**`## File pointers`** — Specific locations the reviewer should examine first (e.g., `src/auth.py:45-80`, `docs/plans/auth.md`). Point to content that exists in the repo — the reviewer can inspect files directly.

### 4. Invoke the reviewer

```bash
<script> invoke <target> <session-dir> 1
```

Exit codes:
- `0` — success. Read `<session-dir>/round-1-response.md` for the review.
- `2` — transport unavailable. Read `<session-dir>/round-1-error.txt` for details and the pickup command. Report to user: the target CLI is not reachable from this environment. Provide the pickup command so the user can ask the other agent directly.
- `1` — invocation failed (timeout, empty response). Read error file and report to user.

On retries for the same round, prior artifacts are archived with a `*.prev-*` suffix.

### 5. Evaluate and iterate

Read the response file. Evaluate each finding — including observations on AGREE verdicts:

- **Accept** — you agree. Write your proposed fix or implementation plan.
- **Reject** — you disagree. State specific rationale.
- **Modify** — you accept the diagnosis but propose a different solution.

If any findings warrant iteration, write `<session-dir>/round-N-followup.md` (where N is the next round number) containing any combination of rebuttals (for rejected findings) and proposed solutions (for accepted findings). Then invoke the next round:

```bash
<script> invoke <target> <session-dir> 2
```

The reviewer validates your proposed solutions and re-evaluates contested points. Iterate until converged or the round cap is reached (default: 2, set `PEER_REVIEW_MAX_ROUNDS` to increase).

**In yolo mode**: for each finding, follow the yolo protocol — (1) propose your response with justification, (2) steel-man alternatives including the reviewer's suggestion, (3) commit to the strongest position. Iterate autonomously with the reviewer. Document all decisions with reasoning.

### 6. Present proposal

Present the consolidated result to the user — always, regardless of verdict:

- **Verdict**: final reviewer assessment
- **Issues found**: with severity (even minor observations from AGREE verdicts)
- **Your position on each**: accepted (with proposed fix), rejected (with rationale), or modified
- **Proposed changes**: specific changes ready for the user to approve or reject

The user decides what to apply. Do not apply changes without user approval. End with the session dir path for artifact inspection.

In yolo mode: apply accepted changes and report what was done with reasoning.

## Reviewer Procedure (Pickup)

When triggered by `/peer-review pickup <session-dir>`:

1. Find the highest-numbered `round-N-request.md` that has no corresponding `round-N-response.md`.
2. Read the request file. It contains the full review prompt, workspace location, and context.
3. Follow the instructions in the request: gather evidence from the repository using Read, Grep, and Glob, then evaluate the work.
4. Write your review to the corresponding response file (e.g., `round-1-response.md`) in the same session directory.
5. Tell the user: "Review complete. Response written to `<session-dir>/round-N-response.md`."

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PEER_REVIEW_TIMEOUT` | `300` | Seconds per reviewer CLI call |
| `PEER_REVIEW_PROBE` | `0` | Set to `1` to enable transport probe before invoke |
| `PEER_REVIEW_PROBE_TIMEOUT` | `45` | Seconds per transport probe (when enabled) |
| `PEER_REVIEW_MAX_ROUNDS` | `2` | Maximum round number allowed per session |
| `PEER_REVIEW_SKILL_DIR` | `$HOME/.<agent>/skills/peer-review` | Skill directory override (auto-detected from script location) |
