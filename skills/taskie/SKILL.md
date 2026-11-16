---
name: taskie
description: Show the taskie board for the current repo, its open issues and pull requests grouped by lifecycle status (needs triage, needs info, backlog, ready, in progress, in review, awaiting approval). Use when the user asks what is open, where things stand, or what to work on next.
argument-hint: "[help]"
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh pr list *)
---

# taskie board

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and follow its
Precedence section, which says what else to read. This skill only reads; it
never changes anything on the backend.

If the argument is `help`, print this table and stop:

| Command | What it does |
|---|---|
| `/taskie` | this board, plus the suggested next action |
| `/taskie:new [text or #n]` | file issues already triaged, or triage untriaged ones |
| `/taskie:plan #n` or `<goal>` | refine an issue, split it, or plan a milestone |
| `/taskie:do [n]` | implement an issue, open a PR, review it and fix findings |
| `/taskie:ship [pr]` | merge an approved PR and clean up |

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

Print the groups in this order, skipping empty ones: Needs triage, Needs info,
Backlog, Ready, In progress, In review, Awaiting approval. For example:

```
Needs triage (2)
  #14       Export fails on empty table
  #15       Add CSV import
Needs info (1)
  #13  P3   Dark mode flickers on start
Backlog (1)
  #9   P2   Slow search on large repos
Ready (1)
  #12  P1   Export button does nothing on Safari
In progress (1)
  #11  P2   Rate-limit login attempts            issue-11-login-rate-limit
In review (1)
  #10  P1   Fix token refresh race               PR #31
```

Within a group, order by priority (P0 first, unprioritized last), then oldest
first. Mark trackers with their progress, for example `#8 P1 Offline mode
(tracker, 2/5 done)`.

If nothing is open, print `Board is empty.` and suggest `/taskie:new`.

## Next action

End with one line suggesting the single most useful next command, taking the
first rule that applies:

1. a PR is awaiting approval: `PR #31 is reviewed: /taskie:ship 31`
2. an issue needs triage: `2 issues need triage: /taskie:new`
3. an issue is in progress with no PR (an interrupted run): `#11 was
   interrupted: /taskie:do 11` to resume it, choosing the highest priority,
   then the oldest
4. an issue is ready: `#12 is ready (P1): /taskie:do 12`, choosing the
   highest priority, then the oldest
5. a PR is in review without a current marker: `PR #31 needs review:
   /taskie:do 31`
6. an issue is in the backlog: `#9 needs planning: /taskie:plan #9`

If no rule applies, say so in one line.
