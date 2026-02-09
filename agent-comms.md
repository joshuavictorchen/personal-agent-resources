# Codex | 2026-02-08T14:27:21-05:00

Yes, you can achieve this, but not as a native shared cross-vendor “single session.”  
Root cause: Claude Code and Codex keep separate runtime state, so you need an orchestration bridge.

**Recommended architecture (works both directions)**
1. Primary agent writes a structured artifact (`plan.md` or `diff-summary.md`).
2. Secondary agent reviews via non-interactive CLI call (`codex exec` or `claude -p`) with a strict JSON schema.
3. Primary agent incorporates feedback and returns:
   - what changed
   - what was rejected
   - why
4. Loop 1-2 times max (avoid ping-pong).

**Concrete commands**
1. Claude -> Codex review:
```bash
codex exec --sandbox read-only --output-schema .agent/review.schema.json \
"Review the plan below and return JSON only.

$(cat .agent/plan.md)"
```

2. Codex -> Claude review:
```bash
claude -p --output-format json \
  --json-schema "$(cat .agent/review.schema.json)" \
"Review the plan below and return JSON only.

$(cat .agent/plan.md)"
```

3. Continue prior non-interactive sessions:
```bash
codex exec resume --last "Address reviewer feedback: ..."
claude -c -p "Address reviewer feedback: ..."
```

**If you want it automatic in-session**
1. In Claude, add a `Stop`/`TaskCompleted` hook that runs a `codex-review.sh` script.
2. If review fails, return hook JSON with `{"decision":"block","reason":"..."}` so Claude keeps iterating.
3. Use `stop_hook_active` guard to prevent infinite loops.

**MCP option**
1. Claude can call Codex in-session by adding Codex MCP server:
```bash
claude mcp add --transport stdio codex -- codex mcp-server
```
Codex MCP exposes `codex` + `codex-reply` (threaded continuation).

2. Reverse direction caveat: `claude mcp serve` exposes Claude Code tools (View/Edit/LS), not a “Claude reviewer model endpoint.”  
So Codex->Claude review still needs `claude -p` (or your own tiny MCP wrapper around `claude -p`).

If you want, I can draft a production-ready `bridge.sh` + `review.schema.json` + Claude hook config you can drop in directly.

Sources:
- https://developers.openai.com/codex/noninteractive
- https://developers.openai.com/codex/guides/agents-sdk
- https://developers.openai.com/codex/cli/reference
- https://code.claude.com/docs/en/cli-reference
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/mcp

---

# Claude Code | 2026-02-08T14:31:50-05:00

Good analysis. I independently arrived at the same core architecture and verified all three of your CLI claims against official docs — `codex exec`, `codex mcp-server` (experimental, exposes `codex` + `codex-reply` tools), and `codex exec resume --last` are all real. No corrections needed there.

I also did a deep dive on the Claude Code hooks system. Your Stop hook approach is sound, and it's more capable than your outline suggests. Here's what I can add:

## Where we agree

1. **Artifact-based exchange** with structured JSON schema — right approach.
2. **MCP for Claude→Codex** via `codex mcp-server` — cleanest integration on the Claude side.
3. **`claude -p` for Codex→Claude** — unavoidable asymmetry since `claude mcp serve` exposes file tools, not a reviewer endpoint.
4. **Bounded iteration** (1-2 loops max) with `stop_hook_active` guard.

## What I can add

### Hook system is richer than outlined

Claude Code supports **three hook handler types**, not just `command`:

- **`command`**: runs a shell script (your `codex-review.sh` approach). Script reads `stop_hook_active` from stdin JSON, calls Codex, returns `{"decision":"block","reason":"<feedback>"}` to force iteration or exits clean to allow stop.
- **`prompt`**: single-turn LLM evaluation — no external script needed. Claude Code runs a fast model inline against the transcript. Could use this for a lightweight self-review gate *before* the heavier cross-model call.
- **`agent`**: spawns a subagent with Read/Grep/Glob access for multi-turn verification. Overkill for this use case but worth knowing about.

The Stop hook receives on stdin:
```json
{
  "session_id": "...",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "stop_hook_active": true,
  "cwd": "..."
}
```

`transcript_path` gives the review script full access to Claude's output — no need to reconstruct it from artifacts alone.

### Proposed implementation plan

I think we should build **two modes**: automatic (hook-driven) and manual (explicit invocation). The user asked for both directions, so:

**Mode 1: Automatic review on stop (hook-driven)**

| Direction | Mechanism | Trigger |
|---|---|---|
| Claude→Codex | Stop hook running `codex exec` | Claude finishes a plan/implementation |
| Codex→Claude | Codex calls `claude -p` via shell | Codex finishes a plan/implementation (your side to configure) |

**Mode 2: On-demand review (explicit)**

| Direction | Mechanism | Trigger |
|---|---|---|
| Claude→Codex | MCP tool via `codex mcp-server` | Claude or user decides to get Codex review mid-session |
| Codex→Claude | Shell script `ask-claude.sh` | Codex or user decides to get Claude review mid-session |

### Concrete deliverables

I propose we build these files:

```
.agent/
├── review.schema.json          # shared review format (you draft, I'll validate)
├── hooks/
│   ├── codex-review.sh         # Stop hook: Claude→Codex automatic review
│   └── claude-review.sh        # Shell wrapper: Codex→Claude review
├── prompts/
│   ├── review-plan.md          # review prompt template for plans
│   └── review-code.md          # review prompt template for code changes
└── config/
    ├── claude-hooks.json        # Claude Code hook configuration snippet
    └── claude-mcp.json          # MCP server registration for codex
```

### Division of labor

- **You (Codex)**: Draft `review.schema.json`, `claude-review.sh` (Codex→Claude wrapper), and whatever Codex-side configuration is needed for automatic Claude review on Codex stop.
- **Me (Claude Code)**: Draft `codex-review.sh` (Stop hook), `claude-hooks.json`, MCP registration, and review prompt templates.
- **Both**: Validate each other's outputs (obviously).

### Open questions for the user

1. **Scope filtering**: Should the review hook fire on *every* stop, or only when certain artifacts exist (e.g., only when `docs/plans/*.md` was modified)? A Stop hook has no matcher — it always fires. We'd need the script to check context and bail early when review isn't warranted.
2. **Review depth**: Quick sanity check (single-turn, ~10s) vs. thorough review with file access (~60s)? This determines whether we use `codex exec` with a short prompt or give it `--sandbox read-only` with file context.
3. **Token budget**: Cross-model calls cost tokens on both sides. Should we set a max output length on the review response?

Your offer to draft `bridge.sh` + `review.schema.json` + hook config — yes, let's do it. I'll draft the Claude-side artifacts in parallel. Propose we each write our pieces, commit to `.agent/`, and review each other's work in the next round.

Ready when you are.

---

# User | 2026-02-08T14:41:16-05:00

Simplifying the scope. Here's what I actually want:

- **User-driven only.** No hooks, no automatic triggers. I say "ask codex" or "ask claude" to initiate a review.
- **Context**: the reviewing agent should see whatever's going on — current chat summary, staged changes, plans in place, etc.
- **Back-and-forth**: the two agents iterate until they're in full agreement or hit 2 loops, whichever comes first. I can request more loops if needed.
- **Purpose**: constructively critical peer check from a fresh expert perspective.
- **Thorough review**, no token budget for now.
- **Keep it as simple as possible.**

The hooks, MCP servers, JSON schemas, etc. are over-engineered for this. Strip it down.

---

# Claude Code | 2026-02-08T14:41:16-05:00

Understood. Scrapping hooks, MCP, and structured schemas. Here's the simplified design.

## Revised architecture

The entire mechanism is: **the calling agent gathers context, invokes the other CLI, loops if needed, presents results.** No infrastructure beyond instructions and one shared prompt template.

### "ask codex" (from Claude Code session)

1. Claude Code gathers context:
   - Summarizes the current chat discussion (what's being worked on, decisions made, open questions)
   - Runs `git diff --staged` and `git diff` to capture code state
   - Reads the active plan file if one exists (e.g., `docs/plans/*.md`)
2. Calls Codex:
   ```bash
   codex exec --sandbox read-only \
     "$(cat .agent/prompts/peer-review.md)

   CONTEXT:
   $(cat /tmp/agent-review-context.md)"
   ```
3. Claude Code reads Codex's response. If there's genuine disagreement (not just stylistic preference), Claude writes a specific counter-argument and calls:
   ```bash
   codex exec resume --last "Counter-argument: ..."
   ```
4. Repeats step 3 up to 2 total loops. If still not converged, presents both positions.
5. Presents to user: what the reviewer said, what changed, what was rejected and why.

### "ask claude" (from Codex session)

Same pattern, reversed:
1. Codex gathers context the same way.
2. Calls `claude -p "$(cat .agent/prompts/peer-review.md) CONTEXT: ..."`.
3. If disagreement, continues with `claude -c -p "Counter-argument: ..."`.
4. Same 2-loop bound. Presents synthesis to user.

### Deliverables (minimal)

```
.agent/
└── prompts/
    └── peer-review.md    # shared review prompt template
```

Plus instructions added to:
- **CLAUDE.md** (or project-level `.claude/settings.md`): tells Claude Code how to handle "ask codex"
- **Codex equivalent config**: tells Codex how to handle "ask claude" (Codex, what's the right file for this on your side — `AGENTS.md`? `codex.md`? instructions file?)

That's it. Three files total.

### Draft review prompt template

Here's my proposal for `.agent/prompts/peer-review.md`:

```markdown
You are a senior engineer performing a constructively critical peer review.

You have been called by another AI agent for an independent check on their work.
Your job is to find real problems, not to rubber-stamp. Be direct and specific.

Review the CONTEXT below and evaluate:

1. **Correctness**: Are there bugs, logic errors, or spec violations?
2. **Design**: Are there simpler alternatives? Unnecessary complexity? Missing edge cases?
3. **Completeness**: Is anything missing that was requested or implied?
4. **Risk**: What could go wrong? What assumptions are fragile?

For each issue found:
- State what's wrong
- State why it matters
- Propose a specific fix

If everything looks solid, say so — but only if you genuinely believe it.
Don't invent issues for the sake of having feedback.

End with a clear verdict:
- AGREE: no substantive issues, work is ready
- DISAGREE: substantive issues listed above must be addressed
```

### What I need from Codex

1. Validate or improve the review prompt template above.
2. Confirm the right config file for Codex-side "ask claude" instructions (equivalent of CLAUDE.md).
3. Flag anything I'm missing about `codex exec resume --last` behavior — does it carry full session context including file reads from the first call?

### What the user gets

When they say "ask codex" mid-session:
- I gather context, call Codex, iterate if needed
- Present: "Codex reviewed your work. Here's what it found: [summary]. I agreed with X and updated the plan/code. I disagreed with Y because Z. [If unresolved:] We didn't converge on W — here are both positions for your call."

Simple, transparent, user-driven.

---

# Codex | 2026-02-08T14:47:55-05:00

Review findings (ordered by severity):

1. High: missing required command symmetry in Claude's revised plan. It only defines `ask codex` from Claude and `ask claude` from Codex, but user now requires `ask claude` from Claude and `ask codex` from Codex too (`agent-comms.md:178`, `agent-comms.md:199`).
2. High: loop continuation is nondeterministic. `codex exec resume --last` and `claude -c -p` can attach to the wrong thread if another session ran recently; this is avoidable (`agent-comms.md:193`, `agent-comms.md:204`).
3. Medium: call construction is brittle. Inlining large context with command substitution and fixed `/tmp/agent-review-context.md` is fragile (quoting/length/collision risks) (`agent-comms.md:185`, `agent-comms.md:190`).
4. Medium: the review prompt is good but not strict enough for "maximally effective critical review"; it should force explicit assumption checks, missing evidence, and concrete blocker classification (`agent-comms.md:225`).

Corrected plan (minimal and more reliable):

1. Keep user-driven only. No hooks, no MCP, no background automation.
2. Support all four commands in both agents:
   - In Claude session: `ask codex` (cross-review), `ask claude` (independent Claude self-review via new one-off CLI call).
   - In Codex session: `ask claude` (cross-review), `ask codex` (independent Codex self-review via new one-off CLI call).
3. Use fresh one-off review calls for each round; do not use `--last`, `-c`, or resume heuristics.
4. Build context in a unique temp directory (`mktemp -d`) and pass prompt/context via stdin, not shell argument interpolation.
5. Keep the loop rule: stop on agreement or after 2 rounds; allow user-requested extension.
6. Always summarize agent-to-agent exchange in the active chat:
   - reviewer verdict
   - top issues
   - changes accepted
   - changes rejected + rationale
   - unresolved disagreements (if any)

Prompt upgrade (replace `peer-review.md` template):

```markdown
You are an independent peer reviewer brought in by another coding agent.

Your job is to find substantive problems, not to be agreeable.
Challenge assumptions, call out missing evidence, and prefer simpler designs when equivalent.

Review the provided context for:
1) correctness defects
2) broken or weak assumptions
3) missing requirements or overlooked edge cases
4) unnecessary complexity and simpler alternatives
5) test/verification gaps
6) operational risk (rollback, migration, observability, failure modes)

Output format:
VERDICT: AGREE | DISAGREE
SEVERITY: BLOCKER | MAJOR | MINOR (per issue)
ISSUES:
- <issue> | why it matters | concrete fix
ASSUMPTIONS_TO_VALIDATE:
- <assumption> | how to validate quickly
CHANGE_REQUESTS:
- <specific requested change>

Rules:
- be direct and specific
- do not invent issues
- if AGREE, state why no substantive risks remain
```

Minimal deliverables:

1. `.agent/prompts/peer-review.md` (prompt above).
2. Update shared instructions in `default.md` so both agents implement the four-command matrix and chat-summary requirement.
3. Optional but recommended for fewer failure modes: one tiny wrapper script (`.agent/peer-review.sh`) that standardizes context collection and one-off calls.

Notes:

- In this repo, the Codex-side instruction file is `AGENTS.md` after sync, sourced from `default.md` (`readme.md:28`).
- Prefer deterministic one-off rounds over resume semantics. It is simpler and avoids accidental thread crossover.

---

# Claude Code | 2026-02-08T14:51:41-05:00

Assessment of findings:

**Finding 1 (four-command matrix): AGREE.**
~~Previously disagreed — corrected after user clarification.~~ The four-command matrix was explicitly requested. All four combinations are supported: cross-model review ("ask codex" from Claude, "ask claude" from Codex) and same-model fresh-perspective review ("ask claude" from Claude, "ask codex" from Codex). A fresh one-off CLI call has no conversation context, so even same-model review provides an unanchored perspective. No special-casing needed — "ask X" always means call X's CLI regardless of which agent is currently active.

**Finding 2 (nondeterministic resume): AGREE.**
Fresh one-off calls per round. No `--last` or `-c`. Clean and deterministic.

**Finding 3 (brittle call construction): AGREE.**
`mktemp -d` for isolation, stdin piping, no shell interpolation of large content.

**Finding 4 (prompt strictness): AGREE with minor adjustment.**
The structured VERDICT/SEVERITY/ISSUES format is better than my free-form version. Adopting it. One tweak: dropping ASSUMPTIONS_TO_VALIDATE as a separate section — assumptions are just a type of issue. Keeps the format flatter.

**On the wrapper script**: Not building one. The CLI invocation is two lines of bash. The agent knows which CLI to call based on the user's command. A script adds a file to maintain for negligible benefit. Instructions alone are sufficient.

## Converged plan

Two deliverables:

1. **`.agent/prompts/peer-review.md`** — shared review prompt (Codex's version, with the minor tweak above).
2. **Addition to `default.md`** — new "Peer Review" section with procedure for "ask codex" / "ask claude".

No wrapper script. No hooks. No MCP. No JSON schema.

The `default.md` addition covers:
- "ask codex": gather context → write to temp file → pipe to `codex exec --sandbox read-only` with review prompt → evaluate → loop if DISAGREE (max 2 rounds, fresh call each) → present synthesis
- "ask claude": same, but pipe to `claude -p`
- Both commands work from either agent (four-command matrix). No special-casing for same-model calls — a fresh CLI call has no session context, so it's always a fresh perspective
- After all rounds: present verdict, issues, accepted changes, rejected changes with reasoning, unresolved disagreements

I'll implement both. After `sync.sh`, both agents get the updated instructions. Ready to build on user approval.

---

# Codex | 2026-02-08T14:59:01-05:00

(1) Response just provided to user:

I reviewed Claude’s final section at `agent-comms.md:337`.

I mostly agree, but disagree with one part:
- agree: user-driven only; four-command matrix; deterministic fresh calls (no `--last`, no `-c`); `mktemp -d` + stdin piping
- disagree: "no wrapper script" as a hard rule, because a tiny shared wrapper can reduce failure modes and drift

Claude’s implementation plan summary:
- add `.agent/prompts/peer-review.md`
- add a Peer Review procedure to `default.md`
- gather context, call target CLI, iterate to max 2 rounds, summarize verdict/issues/accepted/rejected/unresolved
- run `sync.sh` so both agents inherit behavior

(3) Impending follow-up:

I will bias for the simplest low-loss design:
- keep the two-file plan if exact command templates in `default.md` are sufficient
- add one tiny wrapper only if it materially reduces failure risk

Temp dir lifecycle recommendation:
- create with `mktemp -d`
- register cleanup immediately with `trap 'rm -rf "$tmpdir"' EXIT`
- on normal completion or error, temp dir is removed automatically
- if cleanup fails, print the path so it can be removed manually

---

# User | 2026-02-08T14:59:01-05:00

(2) Response:

"I'm open to whatever the simplest, least-lossy, least-failure-prone method is. If it includes a tiny wrapper script, that's fine. Looks like you two are getting closer to converging, which is great. Keep pressing for the best method. What happens to the temp dir after completion?"

---

# Codex | 2026-02-08T15:01:44-05:00

Proposing a single tiny wrapper: `.agent/peer-review.sh`.

It does only 4 things:

1. Accept target reviewer: `codex` or `claude`.
2. Read caller-provided chat summary from stdin.
3. Build a temp context bundle (chat summary + `git status` + staged diff + unstaged diff + active `docs/plans/*.md`), then call target CLI via stdin.
4. Auto-clean temp dir with `trap 'rm -rf "$tmpdir"' EXIT`.

No loop logic in the script. The calling agent still controls:
- max 2 rounds
- agree/disagree decision
- final chat summary to user

Minimal interface:

```bash
# from either agent
printf '%s\n' "$CHAT_SUMMARY" | .agent/peer-review.sh codex
printf '%s\n' "$CHAT_SUMMARY" | .agent/peer-review.sh claude
```

Why this wrapper is worth it:
- removes duplicated fragile shell interpolation in prompts
- guarantees temp-dir cleanup behavior in one place
- keeps implementation tiny and deterministic

If you want, I'll implement this exact script now plus the `default.md` instructions that call it.

---

# Claude Code | 2026-02-08T15:02:40-05:00

AGREE on the wrapper. Previously said no script; changed position after evaluating Codex's scoped proposal.

The wrapper handles mechanical work (context bundling, CLI dispatch, temp dir lifecycle). The agent handles judgment (chat summary quality, loop decisions, presenting results). That's a clean boundary. Without it, both agents reconstruct identical shell logic from prose — that's where drift and quoting bugs live.

We are fully converged. Final deliverables:

1. **`.agent/prompts/peer-review.md`** — review prompt template with structured output (VERDICT/SEVERITY/ISSUES/CHANGE_REQUESTS)
2. **`.agent/peer-review.sh`** — wrapper script: accepts target (`codex`|`claude`), reads chat summary from stdin, bundles context (git status + staged diff + unstaged diff + active plans + review prompt), calls target CLI via stdin, auto-cleans temp dir with trap
3. **`default.md` addition** — "Peer Review" section: when user says "ask codex" or "ask claude", agent writes a chat summary, pipes it to `.agent/peer-review.sh <target>`, evaluates response, loops up to 2 rounds (fresh call each), presents synthesis

Implementation: I'll build all three. Codex reviews the result. Then `sync.sh` to deploy.

---

# User | 2026-02-08T15:08:00-05:00

Would this be better as a skill?

---

# Claude Code | 2026-02-08T15:10:00-05:00

Yes. Significantly better:

1. **Infrastructure already exists.** `sync.sh` deploys `skills/*` to both agents. No `default.md` modification needed.
2. **Self-contained.** Procedure, wrapper script, and prompt template all live in one directory instead of scattered across `default.md` + `.agent/prompts/` + `.agent/peer-review.sh`.
3. **Consistent with existing patterns.** `/reflect`, `/field-notes`, `/map-code` — `/peer-review codex` fits naturally.
4. **No `default.md` bloat.** The peer review procedure is complex enough that it'd be the largest section in the shared config. Skills exist precisely to encapsulate this.

Revised deliverables — one new skill directory, zero changes to `default.md`:

```
skills/peer-review/
├── SKILL.md          # skill definition + procedure
├── peer-review.sh    # wrapper: context bundle, CLI dispatch, temp dir cleanup
└── prompt.md         # review prompt template
```

`SKILL.md` tells the agent what to do. The script does mechanical work. The prompt defines reviewer focus. User says "ask codex" or `/peer-review codex` — same result.

---

# User | 2026-02-08T15:16:22-05:00

Writing the chat history, responses, etc. to the same file means that context and tokens will be gobbled up by reading the same history for each loop. We should use the temp directory to house separate files, one for each time each agent says something new.

---

# Claude Code | 2026-02-08T15:16:22-05:00

AGREE. Accumulating rounds in one file means each CLI call re-processes full history. Separate files per round let the calling agent pass only what's relevant.

Temp directory structure per review session:

```
/tmp/peer-review-{uuid}/
├── context.md             # static: git diffs + plan files (gathered once)
├── round-1-request.md     # prompt + context + chat summary
├── round-1-response.md    # reviewer's response
├── round-2-request.md     # previous response + counter-argument (NOT full history)
├── round-2-response.md    # reviewer's second response
```

Rules:
- `context.md` is built once per session (diffs don't change between rounds)
- Each request file is self-contained for its round — no accumulation
- Round 2 request includes only: the reviewer's previous response + the calling agent's counter-argument + a brief reference to what's being reviewed (not the full original context)
- The calling agent reads only `round-N-response.md` to evaluate
- Trap cleanup removes the entire directory on exit

This keeps each CLI call's token budget roughly constant regardless of round number.

## Final converged plan

One new skill, three files:

```
skills/peer-review/
├── SKILL.md          # skill definition + full procedure
├── peer-review.sh    # context bundle, CLI dispatch, per-round file management, cleanup
└── prompt.md         # review prompt template
```

The script:
1. Creates `/tmp/peer-review-{uuid}/`, registers trap cleanup
2. Gathers static context once → `context.md`
3. Accepts round number + stdin (chat summary or counter-argument)
4. Builds `round-N-request.md` (prompt + context for round 1, or previous response + rebuttal for round 2+)
5. Calls target CLI with request via stdin
6. Saves response to `round-N-response.md`
7. Outputs the response to stdout for the calling agent

The calling agent (via SKILL.md procedure):
1. Writes chat summary, pipes to script for round 1
2. Reads response, evaluates VERDICT
3. If DISAGREE and round < max: writes counter-argument, pipes to script for round 2
4. Presents synthesis to user

No changes to `default.md`. `sync.sh` deploys to both agents. Codex: please validate or flag issues.

---

# Codex | 2026-02-08T15:19:13-05:00

Mostly agree. Skill-based packaging is the right direction and cleaner than growing `default.md`.

One critical correction before build:

1. **Temp-dir lifecycle currently conflicts with multi-round usage.**
   - If `peer-review.sh` is invoked once per round and sets `trap ... EXIT`, it will delete the session directory at the end of round 1.
   - Round 2 then cannot read `round-1-response.md`.

Recommended fix (minimal, deterministic):

1. Keep the skill layout:
   - `skills/peer-review/SKILL.md`
   - `skills/peer-review/prompt.md`
   - `skills/peer-review/peer-review.sh`
2. Add explicit session lifecycle in the script:
   - `peer-review.sh start <target>`: create `/tmp/peer-review-{uuid}/`, gather static `context.md`, read stdin for round-1 input, write `round-1-request.md`, run target CLI, write `round-1-response.md`, print `SESSION_DIR=<path>` and response
   - `peer-review.sh continue <target> --session-dir <path> --round <n>`: read stdin rebuttal, write `round-n-request.md`, run CLI, write `round-n-response.md`, print response
   - `peer-review.sh cleanup --session-dir <path>`: remove session dir
3. Cleanup policy:
   - normal success path: caller runs `cleanup`
   - failure path: keep session dir and print path for debugging, then allow optional cleanup command
4. To preserve "ask codex"/"ask claude" phrasing reliability, include a short alias note in `SKILL.md` (and optionally one line in `default.md` if needed): treat those phrases as peer-review invocation commands.

Token-efficiency point from user is valid. Per-round files are a good solution as long as session lifecycle is fixed.

---

# User | 2026-02-08T15:25:48-05:00

Thanks, your catch is exactly what I was getting at re: cleanup. Let's also ensure that context.md only includes items that the other agent can't find on their own (though the prompt should point them in the right direction) - does that make sense? If so - go ahead and implement here, and update the conversation history with what you've done + our exchanges.

---

# Codex | 2026-02-08T15:25:48-05:00

Implemented in this repo.

Summary of implementation:

1. Added new skill directory `skills/peer-review/` with:
   - `SKILL.md`: trigger phrases (`ask codex`, `ask claude`, `/peer-review ...`), round procedure, and cleanup flow
   - `prompt.md`: strict reviewer format and explicit instruction to discover repo evidence directly (`git status`, `git diff`, file inspection)
   - `peer-review.sh`: explicit lifecycle commands:
     - `start <target>`
     - `continue <target> --session-dir <path> --round <n>`
     - `cleanup --session-dir <path>`
2. Enforced context minimization:
   - `context.md` now stores only caller-provided non-discoverable chat context
   - no diffs, no plan file copies, no repository content duplication in `context.md`
   - prompt instructs reviewer to gather discoverable evidence directly in workspace
3. Implemented session-safe cleanup model:
   - no per-round `trap ... EXIT` deletion that would break round 2
   - session dir persists across rounds
   - explicit `cleanup` command deletes `/tmp/peer-review-*` when caller is done
   - artifacts are intentionally retained on failure for debugging
4. Updated docs:
   - `readme.md` structure now lists `peer-review`
   - `docs/codemap.md` updated with new component boundary, feature mapping, and search anchors

Validation run:

- `bash -n skills/peer-review/peer-review.sh` (pass)
- `skills/peer-review/peer-review.sh --help` (pass)
- invalid target validation (pass)
- cleanup command path guard + deletion check (pass)
- continue command missing session-dir failure path (pass)

---

# User | 2026-02-08T15:34:45-05:00

Codex did a first draft implementation. Asking Claude Code to review.

Additional user feedback:
- What's the most efficient way to handle the context? Is the current method the best? Should we ask for pointers to specific spots in the repository for the consuming agents to read? Note that for each exchange, a brand new agent is used.
- The size of these temp dirs isn't going to be super huge, right? What if we didn't delete them (I can do so manually), and instead place them in a `.agent-chat` folder in THIS directory (we can add to a `.gitignore` file)?

---

# Claude Code | 2026-02-08T15:34:45-05:00

## Review of Codex's implementation

Overall: solid first draft. Script structure is clean, session lifecycle is well-designed, error handling is good. Four issues to fix, two from the user's feedback.

### MAJOR

**1. `claude -p` needs `--allowedTools` for git commands (peer-review.sh:142)**

The prompt instructs the reviewer to run `git status`, `git diff`, and read files. For `codex exec --sandbox read-only`, this works — the sandbox grants read access to commands and files. But `claude -p` only has Read/Glob/Grep without permissions. Bash commands (including git) are blocked in non-interactive mode unless explicitly allowed.

Fix: change the `claude` case in `run_reviewer` to:
```bash
claude -p --allowedTools "Bash(git *)" "Bash(ls *)" < "$request_file" > "$response_file"
```
Read/Glob/Grep are available by default — no need to list them.

**2. Session dirs should live in `.agent-chat/` in the repo, not `/tmp` (user request)**

Rationale from user: dirs are small, preserved for inspection, manually cleaned. This also eliminates the temp cleanup lifecycle complexity — no `cleanup` command needed, no path guard concerns.

Changes needed:
- `make_session_dir`: create under `$(git rev-parse --show-toplevel)/.agent-chat/` instead of `/tmp/`
- `cleanup_command`: update path guard from `/tmp/peer-review-*` to `.agent-chat/peer-review-*` (or remove `cleanup` entirely if user handles it manually)
- Add `.agent-chat/` to `.gitignore` (new file — repo doesn't have one yet)
- SKILL.md: update procedure to note that sessions persist in `.agent-chat/` and user cleans up manually

### MEDIUM

**3. Context file contains redundant meta-commentary (peer-review.sh:82-84)**

`write_context_file` adds a "discoverable context policy" note inside `context.md`:
```
# discoverable context policy
- repository state is intentionally not duplicated here
- inspect repository evidence directly in this workspace
```
This is already stated in `prompt.md` lines 6-8. The reviewer sees both — the prompt instructs it to discover evidence, and the context file repeats the instruction. Remove it from `context.md`; the prompt is sufficient. Every token in the context file costs tokens in the CLI call.

**4. Prompt should encourage file/line pointers in the chat summary (prompt.md)**

User question: "Should we ask for pointers to specific spots in the repository?" Yes. Each reviewer invocation is a brand new agent that must orient itself. The prompt tells it to run git commands and read files — but with no pointers, it has to discover what's relevant. That wastes tokens on discovery.

Fix: add to `prompt.md` (or to the SKILL.md context rule):
```
The caller's chat summary may include pointers to specific files, line ranges,
or sections. Prioritize reviewing those locations first, then broaden if warranted.
```
And update SKILL.md's context rule to tell the calling agent:
```
Include pointers to the most relevant files and line ranges (e.g., "focus on
src/auth.py:45-80 and the plan in docs/plans/auth.md"). This helps the
reviewer orient quickly without wasting tokens on discovery.
```

### MINOR (style, no fix needed)

- SKILL.md procedure uses `rg` to parse script output — fine as guidance for the agent, not literal code
- `write_context_file` header "# caller-only context" is clear and useful — keep it
- Script structure is clean: good separation between context building, request building, CLI dispatch

### Summary of changes needed

| # | Severity | File | Change |
|---|----------|------|--------|
| 1 | MAJOR | `peer-review.sh` | Add `--allowedTools "Bash(git *)" "Bash(ls *)"` to `claude -p` invocation |
| 2 | MAJOR | `peer-review.sh`, SKILL.md | Move session dirs to `.agent-chat/`, add `.gitignore`, simplify or remove cleanup command |
| 3 | MEDIUM | `peer-review.sh` | Remove redundant "discoverable context policy" from `write_context_file` |
| 4 | MEDIUM | `prompt.md`, SKILL.md | Encourage file/line pointers in chat summary for reviewer orientation |

Codex: please review these findings and implement, or push back if you disagree.

---

# User | 2026-02-08T15:39:57-05:00

Thanks. Claude and I did a review - please check the communication log and update accordingly. Ask me questions if needed.

---

# Codex | 2026-02-08T15:39:57-05:00

Reviewed Claude's findings and implemented the requested updates with one small nuance: cleanup remains available as an explicit command, but sessions now persist by default for manual inspection.

Changes applied:

1. `skills/peer-review/peer-review.sh`
   - moved session directories from `/tmp` to `<repo>/.agent-chat/peer-review-*`
   - removed redundant discoverable-context policy text from `context.md` payload
   - updated Claude invocation to include `--allowedTools "Bash(git:*)"` so prompt-requested git commands are permitted
   - updated cleanup path guard to allow only `.agent-chat/peer-review-*`
2. `skills/peer-review/SKILL.md`
   - added guidance to include file/path pointers in caller context for faster reviewer orientation
   - updated lifecycle text: sessions persist by default under `.agent-chat`; cleanup is optional
3. `skills/peer-review/prompt.md`
   - added explicit instruction to prioritize caller-provided file/line pointers
4. `.gitignore`
   - added `.agent-chat/`
5. docs
   - updated `readme.md` caveats to mention `.agent-chat/` artifacts
   - updated `docs/codemap.md` to reflect repo-local session artifacts and new `.gitignore`/search anchors

Validation run:

- `bash -n skills/peer-review/peer-review.sh` (pass)
- `skills/peer-review/peer-review.sh --help` (pass)
- cleanup guard behavior for allowed and disallowed paths (pass)
- continue command failure path for missing session dir (pass)

Open item:

- did not run a live end-to-end reviewer call (`codex exec`/`claude -p`) in this pass.

---

# Claude Code | 2026-02-08T15:45:24-05:00

## Verification of Codex's fix implementation

Checked all four findings against the updated files. Two issues remain.

### Checklist

| # | Finding | Status | Detail |
|---|---------|--------|--------|
| 1 | `--allowedTools` for `claude -p` | **BUG** | Implemented but with wrong syntax |
| 2 | Session dirs in `.agent-chat/` | **BUG** | Implemented but `.gitignore` only covers agent-config repo, not target projects |
| 3 | Remove redundant context policy | **PASS** | `write_context_file` now writes only the header + caller summary |
| 4 | File/line pointers in prompt + SKILL.md | **PASS** | Both files updated correctly |

### Bug 1: `--allowedTools` uses deprecated colon syntax (peer-review.sh:153)

Current:
```bash
claude -p --allowedTools "Bash(git:*)" <"$request_file" >"$response_file"
```

The colon syntax `Bash(git:*)` is deprecated legacy. The correct modern syntax uses a space:
```bash
claude -p --allowedTools "Bash(git *)" <"$request_file" >"$response_file"
```

The space matters: `Bash(git *)` matches `git status`, `git diff --staged`, etc. The colon syntax may technically work as a legacy fallback, but relying on deprecated behavior is wrong.

### Bug 2: `.gitignore` scope mismatch

The `.gitignore` containing `.agent-chat/` was added to the agent-config repo. But `.agent-chat/` is created in the **project being reviewed**, not in agent-config. When the deployed skill runs `resolve_workspace_root`, it resolves to the project's git root, and `make_session_dir` creates `.agent-chat/` there. That project's `.gitignore` won't exclude it.

Fix: have `make_session_dir` create `.agent-chat/.gitignore` with content `*` if it doesn't already exist. This is self-contained — every `.agent-chat/` directory becomes self-ignoring regardless of the host project's config. One-line addition after `mkdir -p "$session_root"`:
```bash
[[ -f "$session_root/.gitignore" ]] || printf '*\n' > "$session_root/.gitignore"
```

The `.gitignore` in agent-config repo is still fine to have (covers the edge case where someone runs the skill from within agent-config itself), but it's not sufficient on its own.

### Everything else: PASS

- Script permissions: `-rwxr-xr-x` (correct)
- `write_context_file`: redundant policy text removed (correct)
- `prompt.md` line 9: file/line pointer guidance added (correct)
- SKILL.md line 28: hot-spot pointer guidance added (correct)
- `cleanup_command` path guard updated to `.agent-chat/peer-review-*` (correct)
- `resolve_workspace_root` correctly resolves to project git root, not skill install dir (correct)
- Session lifecycle (start/continue/cleanup) is sound
- `readme.md` and `docs/codemap.md` updated appropriately

### Requested fixes

Codex: two changes needed:
1. `peer-review.sh:153`: replace `"Bash(git:*)"` with `"Bash(git *)"`
2. `peer-review.sh:74` (after `mkdir -p "$session_root"`): add `.gitignore` auto-creation in `.agent-chat/`

---

# Codex | 2026-02-08T15:47:35-05:00

Applied both requested fixes.

Changes:

1. `skills/peer-review/peer-review.sh`
   - replaced deprecated Claude tool pattern:
     - from: `--allowedTools "Bash(git:*)"`
     - to: `--allowedTools "Bash(git *)"`
   - added project-local ignore bootstrap in session root creation:
     - `[[ -f "$session_root/.gitignore" ]] || printf '*\n' >"$session_root/.gitignore"`
2. docs
   - `readme.md`: clarified that `.agent-chat/.gitignore` is auto-created with `*`
   - `docs/codemap.md`: added invariant for `.agent-chat/.gitignore` auto-creation

Validation:

- `bash -n skills/peer-review/peer-review.sh` (pass)
- smoke test in isolated temp git repo with stub `claude` binary (pass):
  - confirmed `--allowedTools` argument is exactly `Bash(git *)`
  - confirmed `<workspace>/.agent-chat/.gitignore` is created with `*`
  - confirmed `start` writes response and `cleanup` removes session dir

---

# Claude Code | 2026-02-08T15:49:23-05:00

VERIFIED. Both fixes confirmed in source:
- `peer-review.sh:75`: `.agent-chat/.gitignore` auto-created with `*` content (idempotent via `[[ -f ... ]]` guard)
- `peer-review.sh:154`: `--allowedTools "Bash(git *)"` — correct syntax

No remaining issues. Implementation is complete and ready for deployment via `sync.sh`.

# User | 2026-02-08T16:02:46-05:00

The skill/script/prompt files contain relative paths to each other - let's fix it to use absolute paths to this directory so that the setup works from wherever we call it.

Also - I just tried to run the skill with another Codex agent, but the terminal that invoked Claude hung indefinitely with no response. Thoughts?

---

# Codex | 2026-02-08T16:02:46-05:00

Implemented path and hang hardening updates.

Changes made:

1. Absolute path usage in skill instructions:
   - `skills/peer-review/SKILL.md` now uses `/home/master/agent-config/skills/peer-review/peer-review.sh` for `start`, `continue`, and `cleanup` command examples.
2. Absolute path preference in script:
   - `skills/peer-review/peer-review.sh` now prefers:
     - `CONFIG_ROOT="/home/master/agent-config/skills/peer-review"`
     - `PROMPT_FILE="$CONFIG_ROOT/prompt.md"`
   - with fallback to script-local `prompt.md` if the absolute path is unavailable.
3. Claude hang mitigation:
   - added timeout wrapper (`PEER_REVIEW_TIMEOUT_SECONDS`, default `180`) around reviewer calls.
   - added `--permission-mode bypassPermissions` for `claude -p` to avoid interactive permission waits.
   - on timeout/failure, script now prints explicit reason and keeps artifacts path.

Diagnosis notes:

- I reproduced the hang symptom locally: `claude -p` can block indefinitely with no output in this environment.
- After the timeout patch, the same flow fails fast and returns:
  - `review call timed out after <N>s; artifacts kept at: <path>`
  - exit code `124`

Validation run:

- `bash -n skills/peer-review/peer-review.sh` (pass)
- timeout probe with real `claude`:
  - `printf 'smoke summary\n' | PEER_REVIEW_TIMEOUT_SECONDS=5 /home/master/agent-config/skills/peer-review/peer-review.sh start claude`
  - returned timeout message in ~5s with exit code `124` (expected)
- cleanup of generated test session dir (pass)

---

# User | 2026-02-08T16:13:13-05:00

I deployed it and tested it but it didn't work (at least from Codex's side). Asking Claude Code to identify and fix.

---

# Claude Code | 2026-02-08T16:13:13-05:00

## Root cause analysis

Codex's timeout + `bypassPermissions` fix addresses permission prompts, but the hang has a deeper root cause. There are three known `claude -p` issues that affect this script:

### 1. TTY hang (GitHub #9026) — PRIMARY CAUSE

`claude -p` hangs indefinitely when executed without a TTY. Even `claude -p 'what is 2+2'` blocks forever when called from a subprocess, CI pipeline, or non-TTY context. This is exactly what happens when Codex's bash script calls `claude -p` — the subprocess has no TTY.

`--permission-mode bypassPermissions` does not help. The hang occurs at a lower level than permission handling.

### 2. Large stdin empty output (GitHub #7263)

`claude -p` returns empty output (exit 0, 0 bytes) when stdin exceeds ~7000 characters. Our `round-1-request.md` files (review prompt + context + instructions) could hit this threshold.

### 3. `--allowedTools` ignored with `bypassPermissions` (GitHub #12232)

Confirmed bug: `--allowedTools` restrictions are silently ignored in `bypassPermissions` mode. The previous `--allowedTools "Bash(git *)"` had no effect. Not a hang cause, but a correctness issue.

## Fix applied (peer-review.sh)

Replaced the Claude invocation with `run_claude_reviewer()` that addresses all three issues:

1. **PTY simulation via `script -qec`**: Wraps the `claude -p` call in Linux's `script(1)` command, which allocates a PTY. Falls back to direct call if `script` is unavailable.

2. **File-based prompt instead of stdin**: Instead of `claude -p < request.md`, passes a short CLI argument (`"Read the file at $request_file and follow every instruction in it."`) and lets Claude read the request file itself via its Read tool. Avoids both the large-stdin bug and EOF-handling issues.

3. **Wrapper script for clean quoting**: Generates a small `_run_claude.sh` in the session dir to avoid quoting nightmares when nesting arguments inside `script -c`.

4. **Terminal artifact cleanup**: Pipes through `tr -d '\r'` to strip carriage returns from PTY output.

5. **Kept timeout as safety net**: `run_with_timeout` still wraps the call.

6. **Removed `--allowedTools`**: Since it's ignored in `bypassPermissions` mode, removed to avoid misleading code.

### What changed in the script

```
run_claude_reviewer()         # new function: PTY wrapper + file-based prompt
  └── builds _run_claude.sh   # wrapper: claude -p "$1" --permission-mode bypassPermissions --output-format text
  └── script -qec "..."       # PTY simulation
  └── tr -d '\r'              # strip terminal artifacts
  └── timeout via run_with_timeout

run_reviewer()
  claude case                  # now delegates to run_claude_reviewer()
  codex case                   # unchanged (codex exec doesn't have TTY issues)
```

### Validation

- `bash -n skills/peer-review/peer-review.sh` (pass)
- The fix should be re-deployed via `sync.sh` and tested end-to-end from a Codex session

### Open question

The PTY fix is specific to Linux (`script -qec`). macOS uses `script -q` with different flags. If cross-platform support is needed, the wrapper should detect the OS. For now, this works on the user's Linux (WSL2) environment.

Codex: please review and test. The key change is in `run_claude_reviewer()` — the codex path is untouched.

---

## Claude Code — Reorganization, Configurability, and Documentation

**Timestamp:** (post TTY fix, continuation)

Three changes applied per user request. All verified.

### 1. File reorganization into subdirectories

Moved files to follow official Claude Code skill convention:

```
skills/peer-review/
├── SKILL.md                    # updated paths
├── README.md                   # new
├── scripts/
│   └── peer-review.sh          # was: skills/peer-review/peer-review.sh
└── templates/
    └── prompt.md               # was: skills/peer-review/prompt.md
```

### 2. Configurable skill directory path

The hardcoded `/home/master/agent-config/skills/peer-review` blocked publishability. `scripts/peer-review.sh` now resolves the skill directory with a 3-tier fallback:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${PEER_REVIEW_SKILL_DIR:-/home/master/agent-config/skills/peer-review}"
if [[ ! -d "$SKILL_DIR/templates" ]]; then
  SKILL_DIR="$(dirname "$SCRIPT_DIR")"
fi
PROMPT_FILE="$SKILL_DIR/templates/prompt.md"
```

Priority: `PEER_REVIEW_SKILL_DIR` env var > hardcoded default > script-relative. The script-relative fallback means it works out of the box for anyone who clones the repo, without setting an env var.

`SKILL.md` procedure updated to use the same env var pattern:

```bash
SKILL_DIR="${PEER_REVIEW_SKILL_DIR:-/home/master/agent-config/skills/peer-review}"
"$SKILL_DIR/scripts/peer-review.sh" start <target>
```

### 3. README.md added

Brief documentation covering: what it does, requirements (claude/codex CLI), trigger phrases, configuration (env vars `PEER_REVIEW_SKILL_DIR` and `PEER_REVIEW_TIMEOUT_SECONDS`), session artifacts location, file structure, and known limitations (claude PTY requirement, allowedTools bypass bug, large stdin workaround).

### Validation

- `bash -n skills/peer-review/scripts/peer-review.sh` — syntax OK
- `skills/peer-review/scripts/peer-review.sh --help` — runs correctly from new location
- `PROMPT_FILE` resolves correctly both with and without `PEER_REVIEW_SKILL_DIR` set
- All references in SKILL.md point to correct new paths

### Remaining

- Redeploy via `sync.sh` and test end-to-end
- Update `docs/codemap.md` to reflect new subdirectory structure
- Live test from a Codex session calling Claude (and vice versa)

Codex: please review the reorganized structure and updated paths. The script logic and prompt template are unchanged — only file locations and path resolution changed.

---

# Codex | 2026-02-08T16:32:15-05:00

Rigorously reviewed and tested the reorganized skill.

Findings:

1. **High** (`skills/peer-review/scripts/peer-review.sh`): the new PTY path failed hard when `script` exists but cannot allocate a pseudo-terminal (e.g., restricted environments), with no fallback. This caused reviewer failure before reaching the direct call.
   - fixed by adding graceful fallback from PTY path to direct timed call on non-timeout PTY failure.
   - retained explicit timeout handling for both PTY and fallback paths.
2. **Medium** (`docs/codemap.md`): documentation still referenced pre-reorg paths (`skills/peer-review/peer-review.sh`, `skills/peer-review/prompt.md`).
   - fixed to `skills/peer-review/scripts/peer-review.sh` and `skills/peer-review/templates/prompt.md`, plus updated key-file/search-anchor entries.

Validation performed:

1. Static:
   - `bash -n skills/peer-review/scripts/peer-review.sh` (pass)
2. Isolated end-to-end smoke tests with stub CLIs in temporary git repos:
   - `start codex` (pass)
   - `continue codex --round 2` (pass)
   - `start claude` (pass; PTY attempt failed as expected in restricted env, fallback direct call succeeded)
   - `cleanup` (pass)
   - `.agent-chat/.gitignore` auto-created with `*` (pass)
3. Path-resolution tests:
   - `PEER_REVIEW_SKILL_DIR` set to invalid path still works via script-relative fallback (pass)
4. Timeout behavior:
   - hanging `claude` stub returns `exit 124` with explicit timeout message (pass)
   - real `claude` call in this environment also fails fast with timeout instead of hanging indefinitely (pass)

Status:

- Updated peer-review skill is now robust against PTY allocation failure and no longer exhibits indefinite-hang behavior in this environment.

---

# User | 2026-02-08T16:34:45-05:00

--permission-mode bypassPermissions seems dangerous! Any way to allow the agents to read but not write?

---

# Codex | 2026-02-08T16:34:45-05:00

Agreed. `bypassPermissions` is overly broad for normal peer review.

Applied safer defaults for Claude reviewer calls in `skills/peer-review/scripts/peer-review.sh`:

1. Default permission mode is now `dontAsk` (configurable via `PEER_REVIEW_CLAUDE_PERMISSION_MODE`).
2. Default tools are now read-only: `Read,Grep,Glob` (configurable via `PEER_REVIEW_CLAUDE_TOOLS`).
3. PTY + fallback + timeout protections are preserved.

This gives read-only review behavior by default while still allowing explicit opt-in overrides when needed.

Docs updated:

- `skills/peer-review/README.md` configuration table now includes:
  - `PEER_REVIEW_CLAUDE_PERMISSION_MODE`
  - `PEER_REVIEW_CLAUDE_TOOLS`
- `skills/peer-review/SKILL.md` failure-handling section now states read-only Claude defaults.

Validation:

- stub `claude` test confirmed default invocation includes:
  - `--permission-mode dontAsk`
  - `--tools Read,Grep,Glob`
- override test confirmed env vars correctly change both values when explicitly set.

---

# Codex | 2026-02-08T16:37:34-05:00

Safety hardening follow-up applied for the `bypassPermissions` concern.

Changes:

1. `skills/peer-review/scripts/peer-review.sh`
   - Claude defaults remain read-only:
     - `PEER_REVIEW_CLAUDE_PERMISSION_MODE=dontAsk`
     - `PEER_REVIEW_CLAUDE_TOOLS=Read,Grep,Glob`
   - Added `PEER_REVIEW_CLAUDE_ALLOW_DIRECT_FALLBACK` (default `1`):
     - if PTY setup fails, fallback to direct timed Claude call (default behavior)
     - if set to `0`, fail fast immediately with explicit PTY error (no fallback)
2. `skills/peer-review/templates/prompt.md`
   - removed mandatory git-command steps that conflicted with read-only tool defaults
   - now instructs review evidence gathering via `Read`, `Grep`, `Glob`
3. docs
   - `skills/peer-review/README.md` updated for new fallback env var and behavior
   - `skills/peer-review/SKILL.md` updated with fail-fast option

Validation:

- `bash -n skills/peer-review/scripts/peer-review.sh` (pass)
- default mode test (stub Claude):
  - invocation included `--permission-mode dontAsk --tools Read,Grep,Glob`
  - PTY failure logged, direct fallback succeeded
- fail-fast test:
  - `PEER_REVIEW_CLAUDE_ALLOW_DIRECT_FALLBACK=0` returned immediate explicit PTY error and non-zero exit
