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

The peer-review script is at one of these paths:
- `~/.claude/skills/peer-review/scripts/peer-review.sh` (Claude sessions)
- `~/.codex/skills/peer-review/scripts/peer-review.sh` (Codex sessions)

Override with `$PEER_REVIEW_SKILL_DIR/scripts/peer-review.sh` if set.

**Critical**: Always expand to the full absolute path in every Bash command (e.g., `/home/user/.claude/skills/peer-review/scripts/peer-review.sh`). Do not use shell variables like `$SCRIPT` — the permission system matches command strings literally, and variable references will trigger manual approval prompts.

### 2. Create a session

```bash
/home/user/.claude/skills/peer-review/scripts/peer-review.sh init "brief label"
```

Pick a short label that identifies the review scope (e.g., "auth-refactor", "plan-review", "perf-claims"). The output is the absolute session directory path — capture it from the command output for use in subsequent steps.

This creates `.agent-chat/{timestamp}-{label}/` in the current repo with a `.workspace_root` marker.

### 3. Write context

Write a file called `context.md` inside the session directory (use the Write tool, not Bash). The reviewer is a fresh process with no access to your chat history — everything it needs must be in this file.

Include the **full conversation verbatim**, from the start of the session up to the review request. Include all user messages and all of your responses exactly as they occurred. Omit raw tool output (file contents, grep results, directory listings) unless the output is directly relevant to what's being reviewed — the reviewer can re-inspect files on its own. The goal is a complete record of intent, reasoning, and decisions with no editorial filtering.

After the conversation log, add:

**File/line pointers** — Specific locations the reviewer should examine first (e.g., `src/auth.py:45-80`, `docs/plans/auth.md`). Point to content that exists in the repo — the reviewer can inspect files directly.

### 4. Invoke the reviewer

```bash
/home/user/.claude/skills/peer-review/scripts/peer-review.sh invoke <target> <session-dir> 1
```

Exit codes:
- `0` — success. Read `<session-dir>/round-1-response.md` for the review.
- `2` — transport unavailable. Read `<session-dir>/round-1-error.txt` for details and the pickup command. Report to user: the target CLI is not reachable from this environment. Provide the pickup command so the user can ask the other agent directly.
- `1` — invocation failed (timeout, empty response). Read error file and report to user.

On retries for the same round, prior artifacts are archived with a `*.prev-*` suffix.

### 5. Evaluate and iterate

Read the response file. Look for the `VERDICT:` line.

**If AGREE** — the reviewer found no substantive issues. Present the verdict and any minor observations to the user.

**If DISAGREE** — the reviewer found issues. For each issue:
- Decide whether to accept (incorporate the fix) or reject (with specific rationale).
- If any issues warrant a rebuttal, write `<session-dir>/round-2-rebuttal.md` with your counter-arguments, then:

```bash
/home/user/.claude/skills/peer-review/scripts/peer-review.sh invoke <target> <session-dir> 2
```

Read `round-2-response.md` and evaluate again.

The default round cap is 2 (enforced by the script via `PEER_REVIEW_MAX_ROUNDS`). If more rounds are needed, the user can raise the cap or the caller can set the env var before invoking.

### 6. Present synthesis

Report to the user:
- **Verdict**: final AGREE/DISAGREE from the reviewer
- **Issues found**: with severity (BLOCKER/MAJOR/MINOR)
- **Accepted changes**: what you're incorporating and why
- **Rejected changes**: what you're not incorporating and why
- **Unresolved disagreements**: if any remain after iteration

End with the session dir path so the user can inspect artifacts.

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
| `PEER_REVIEW_SKILL_DIR` | `$HOME/.claude/skills/peer-review` | Skill directory override |
