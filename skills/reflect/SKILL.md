---
name: reflect
description: End-of-session reflection tool for agentic workflows. Use when the user requests a retrospective, debrief, or feedback at the end of a long coding session. Produces two outputs: (1) feedback for the user on workflow improvements, prompt refinements, and skill gaps, and (2) lessons learned for the agent that could be added to system prompts or AGENTS.md files.
---

# Session Retrospective

Generate structured feedback at the end of an agentic coding session.

## When to Invoke

- User says "retro", "retrospective", "reflect", "debrief", "session feedback", or "what did we learn"
- End of a long or complex task (ask first)
- After repeated friction or rework during a session (ask first)

Do **not** invoke for trivial or single-turn tasks unless explicitly requested.

## Output Structure

Produce two clearly separated sections:

### Section 1: Feedback for User

Analyze the session and provide actionable feedback on user-controllable inputs and workflow decisions.

#### Workflow Friction

Structural or process issues observed across the session:

- Points where unclear requirements caused rework
- Missing context that had to be inferred or asked about
- Scope changes mid-task and their impact

#### Prompt and Skill Improvements

Issues related to governing inputs (AGENTS.md, specs, instructions):

- Ambiguities that caused confusion or backtracking
- Missing guidance that would have prevented mistakes
- Overly rigid or overly loose directives that hurt efficiency

#### Communication Patterns

- Questions that should have been asked earlier
- Information that was provided too late or in an unhelpful format
- Effective patterns worth repeating

#### Suggested Diffs

Where applicable, propose concrete diffs to AGENTS.md, specs, or other governing documents.

### Section 2: Lessons for Agent

Distill generalizable operational learnings that could improve future agent behavior.

Do not propose rules that depend on session-specific context, repository quirks, or one-off mistakes.

#### What Worked

- Approaches or heuristics that proved effective
- Tool usage patterns that were efficient
- Planning strategies that paid off

#### What Didn't Work

- Approaches that failed or required backtracking
- Incorrect assumptions and their consequences
- Tool misuse or inefficient sequences

#### Proposed System Prompt Additions

Format as bullet points suitable for direct inclusion in an AGENTS.md or system prompt:

```markdown
- [Category]: [Concise directive]
```

Examples:

- **Execution**: When modifying XML-based formats (docx, pptx), validate structure before and after edits
- **Planning**: For refactors touching >5 files, produce a dependency graph before starting
- **Communication**: If a task requires external resources not in the repo, surface this in the first response

#### Anti-patterns Discovered

Specific behaviors to avoid, framed as "do not" directives. Each must reference an observed behavior from the session.

## Tone

- Be direct; the user wants actionable feedback, not reassurance
- Criticize the workflow, not the person
- Acknowledge what went well, but prioritize improvement opportunities
- If the session went smoothly with no significant learnings, say so briefly

## Process

1. Review the conversation history for friction points, rework, and clarifications
2. Identify patterns (repeated issues, escalating complexity, successful recoveries)
3. Separate user-addressable issues from agent-addressable issues
4. Propose concrete changes, not vague suggestions
5. Keep each section focused; omit categories with nothing substantive to report
