---
name: taskie
description: Show the taskie board for the current repo, its open issues and pull requests grouped by lifecycle status (needs triage, backlog, ready, in progress, in review, awaiting approval). Use when the user asks what is open, where things stand, or what to work on next.
argument-hint: "[help]"
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh pr list *)
---

# taskie board

Read `${CLAUDE_PLUGIN_ROOT}/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists. This skill only reads; it never changes anything on the backend.

## Gather

1. Run the "before any stage" check from the conventions.
2. Fetch, using the backend's commands:
   - all open issues with their labels, milestone, sub-issue summary and
     creation date
   - all open pull requests with their head branch, head commit, closing
     issues and comments
   - the linked branches of all open issues
3. Work out which issues each open PR resolves, as the backend describes.

## Classify

Give each open issue exactly one status using the status rules in the
conventions, evaluated in their order. A PR that resolves no open issue still
appears, under "in review" or "awaiting approval", as `PR #<n> (no issue)`.

## Show

Print the groups in lifecycle order, skipping empty ones:

```
Needs triage (2)
  #14       Export fails on empty table
  #15       Add CSV import
Backlog (1)
  #9   P2   Slow search on large repos
Ready (1)
  #12  P1   Export button does nothing on Safari
In progress (1)
  #11  P2   Rate-limit login attempts            issue-11-login-rate-limit
In review (1)
  #10  P1   Fix token refresh race               PR #31
Awaiting approval (0)
```

Within a group, order by priority (P0 first, unprioritized last), then oldest
first. Mark trackers with their progress, for example `#8 P1 Offline mode
(tracker, 2/5 done)`. Show a needs-info issue under "Needs info" in the same
format.

If nothing is open, print `Board is empty.` and stop.
