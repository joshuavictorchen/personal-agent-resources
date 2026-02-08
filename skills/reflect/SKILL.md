---
name: reflect
description: End-of-session reflection that produces (1) actionable feedback for the user and (2) proposed updates to agent instructions. Use when the user requests a retrospective, debrief, or feedback at the end of a coding session.
---

# Session Reflection

Analyze the current session and produce two deliverables: feedback for the user and proposed directive updates for the agent's system prompt instructions.

## When to Invoke

- User says "retro", "retrospective", "reflect", "debrief", or "what did we learn"
- End of a long or complex task (ask first)

Do **not** invoke for trivial or single-turn tasks unless explicitly requested.

## Process

Review the session for:

- Your own mistakes (wrong assumptions, bad approaches, failed attempts, misread code)
- User corrections (anything the user told you to do differently)
- Friction points (rework, confusion, scope changes)
- Patterns that worked well, especially non-obvious ones

Then produce the two output sections below. Omit either section if there's nothing substantive to report.

## Output

### Feedback for User

What the user could do differently — unclear requirements, missing context, scope changes, communication patterns that caused friction or worked well. Be direct; criticize the workflow, not the person.

### Proposed Directives

For each insight, draft a proposed change to the agent's system prompt — additions, refinements, consolidations, or removals:

- Specify where it belongs in the existing instruction structure
- Check if an existing directive already covers the concern — propose a refinement rather than a new bullet
- Flag directives that caused friction, went unused, or have been superseded — propose removal or consolidation
- Match the style and voice of existing instructions

Present all proposed changes to the user for approval. Do not modify instructions directly.

Each proposed directive must pass all three:

- **Specific**: "Check function signatures before calling" beats "be more careful"
- **Actionable**: An agent reading this would change its behavior
- **Non-redundant**: Not already covered by an existing directive

## Tone

- Be direct; prioritize improvement over reassurance
- Criticize your own behavior honestly — your mistakes matter more than the user's, because you're the one proposing rules for yourself
- If the session went smoothly with no learnings, say so
