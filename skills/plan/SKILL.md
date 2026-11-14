---
name: plan
description: Refine an issue in the current repo until it is ready to implement, with final acceptance criteria, clear scope and known dependencies. Use when the user asks to plan, refine, scope or flesh out an issue.
argument-hint: "#n"
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh label list *)
---

# taskie plan

Read `${CLAUDE_PLUGIN_ROOT}/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS

## Refine an issue

Input is an issue number, with or without `#`.

1. Run the "before any stage" check from the conventions.
2. Read the issue, its comments and its sub-issues. Stop if it is closed. If
   it is a tracker, show its sub-issues with their statuses and ask which one
   to refine.
3. Read the code the issue touches (start from the likely files in a triage
   comment, if there is one) so the scope is grounded in what exists.
4. Ask the user, in one message, about anything ambiguous whose answer would
   change the scope or the acceptance criteria. Skip this step when nothing
   is ambiguous.
5. Draft the new body from the matching template in the conventions:
   - keep everything still true from the current body, and keep Source
   - finalize the acceptance criteria: each item one observable outcome that
     can be checked by reading the code or running something
   - under Context (or Problem, for a bug), state what is out of scope when
     that is not obvious, and list dependencies as `Depends on #<n>`
6. Check the draft against the definition of ready.
7. Show the proposal and wait for approval: the new body, and the label
   changes (`ready` if the definition holds; a priority, and removal of
   `needs-triage` and `needs-info`, if the issue has no priority yet). If the
   definition does not hold, say which point fails.
8. Apply what the user approved: replace the body, then change the labels.
   Suggest `/taskie:work <n>` if the issue is now ready.
