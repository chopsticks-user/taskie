---
name: plan
description: Refine an issue in the current repo until it is ready to implement (final acceptance criteria, clear scope, split into sub-issues when too big), or turn a goal into a milestone with planned issues. Use when the user asks to plan, refine, scope, break down or split an issue, or to plan a milestone, release or larger goal.
argument-hint: "#n | <goal>"
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh label list *)
---

# taskie plan

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS

An issue number (with or without `#`) means refine that issue. Anything else
is a goal to plan as a milestone.

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
6. Check the draft against the definition of ready. If the only point that
   fails is "fits in one reviewable pull request", split the issue (below)
   instead.
7. Show the proposal and wait for approval: the new body, and the label
   changes (`ready` if the definition holds; a priority, and removal of
   `needs-triage` and `needs-info`, if the issue has no priority yet). If the
   definition does not hold, say which point fails.
8. Apply what the user approved: replace the body, then change the labels.
   Suggest `/taskie:work <n>` if the issue is now ready.

## Split an issue

When an issue would not fit in one reviewable pull request, it becomes a
tracker and the work moves to sub-issues.

1. Divide the work into the fewest children that each fit in one reviewable
   pull request and leave the code working when merged on their own. Prefer
   splitting by behavior a user could notice over splitting by layer.
2. Draft each child like an intake draft: a title, the parent's type and
   priority (or its own if clearly different), a body from the matching
   template with the share of the acceptance criteria it delivers, and
   `Depends on #<n>` for any order between children. Source is `Split from
   #<parent>`.
3. Draft the parent's new body: keep the template, replace its acceptance
   criteria with one item per child ("<child title> is done"), and add a
   short plan under Context explaining the order.
4. Show the parent's new body and all child drafts in one message, saying
   which children meet the definition of ready, and wait for approval.
5. Apply what the user approved: create each child as a sub-issue of the
   parent, with the parent's milestone, `ready` only if it meets the
   definition, and no `needs-triage` (it was triaged as part of the parent).
   Then replace the parent's body and remove `ready` from it if present; a
   tracker is never ready.
6. Print the children as `#<n> <title>` with their status, and suggest
   `/taskie:work` for the first ready one.

## Plan a milestone

Input is a goal such as `v0.2: offline mode`.

1. Run the "before any stage" check from the conventions.
2. Name the milestone: the text before the first colon is its title and the
   rest its description. Without a colon, propose a short title and confirm
   it. If a milestone with that title exists, plan into it.
3. Read the README, `.taskie.md` and the code the goal touches, and list
   open issues that already belong to the goal.
4. Ask the user, in one message, about anything ambiguous whose answer would
   change the scope. Skip this step when nothing is ambiguous.
5. Draft the work:
   - new issues in intake's format, each with a type and a priority (the goal
     was triaged by planning it, so no `needs-triage`), final acceptance
     criteria, and `Depends on #<n>` for any order between them
   - an issue that would not fit in one reviewable pull request becomes a
     tracker with sub-issues, drafted as in "Split an issue"
   - existing open issues to add to the milestone
6. Show the milestone, every draft and the existing issues to add in one
   message, saying which drafts meet the definition of ready, and wait for
   approval.
7. Apply what the user approved: create the milestone if needed, create the
   issues and sub-issues in it (`ready` only where the definition holds),
   and add the existing issues to it.
8. Print the milestone's issues in dependency order with their statuses, and
   suggest `/taskie:work` for the first ready one.
