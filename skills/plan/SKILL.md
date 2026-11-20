---
name: plan
description: Refine an issue in the current repo until it is ready to implement (final acceptance criteria, clear scope, split into sub-issues when too big), or turn a goal into a milestone with planned issues. Use when the user asks to plan, refine, scope, break down or split an issue, or to plan a milestone, release or larger goal.
argument-hint: "#n | <goal>"
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**) Bash(gh --version*) Bash(git --version*) Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh label list *)
---

# taskie plan

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and follow its
Precedence section, which says what else to read.

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
   comment, if there is one) so the scope is grounded in what exists, and
   note how the change fits there: what calls or depends on that code and
   must keep working.
4. Ask the user, in one message, about anything ambiguous whose answer would
   change the scope or the acceptance criteria, including what done looks
   like when the issue does not say. Skip this step when nothing is
   ambiguous. Every other guess goes under Assumptions; in autonomous mode,
   so do these questions' answers (see the conventions).
5. Draft the new body from the matching template in the conventions:
   - keep everything still true from the current body, and keep Source
   - finalize the acceptance criteria: each item one observable outcome that
     can be checked by reading the code or running something
   - under Context (or Problem, for a bug), say how the change fits the code
     from step 3, and list dependencies as `Depends on #<n>`
   - fill Out of scope, Edge cases and Assumptions as the conventions
     describe, adding them if the body predates them and keeping the
     user's answers and earlier assumptions that still hold
6. Check the draft against the definition of ready. If the only point that
   fails is "fits in one reviewable pull request", split the issue (below)
   instead.
7. Show the proposal and wait for approval: the new body, and the label
   changes (`ready` if the definition holds; a priority, and removal of
   `needs-info`, if the issue has no priority yet), and the milestone, as
   "Milestones" in the conventions describes. If the definition does not
   hold, say which point fails.
8. Apply what the user approved: replace the body, change the labels, then
   set the milestone if one was agreed.
   Suggest `/taskie:do <n>` if the issue is now ready.

## Split an issue

When an issue would not fit in one reviewable pull request, it becomes a
tracker and the work moves to sub-issues.

1. Divide the work into the fewest children that each fit in one reviewable
   pull request and leave the code working when merged on their own. Prefer
   splitting by behavior a user could notice over splitting by layer.
2. Draft each child like a `/taskie:new` draft: a title, the parent's type and
   priority (or its own if clearly different), a body from the matching
   template with the share of the acceptance criteria and edge cases it
   delivers, its own Out of scope (including what its siblings cover) and the
   parent's assumptions that apply to it, and `Depends on #<n>` for any order
   between children. Every edge case of the parent goes to at least one
   child. Source is `Split from #<parent>`.
3. Draft the parent's new body: keep the template, replace its acceptance
   criteria with one item per child ("<child title> is done") and its Edge
   cases with "Covered by the sub-issues", so they are not kept in two
   places, and add a short plan under Context explaining the order.
4. Show the parent's new body, its milestone (proposed as "Milestones" in
   the conventions describes, if it has none) and all child drafts in one
   message, saying which children meet the definition of ready. Ask which
   children to create, as a batch (see "Asking the user" in the
   conventions), and wait for the answer.
5. Apply what the user approved: set the parent's milestone if one was
   agreed, then create each child as a sub-issue of the parent, with the
   parent's milestone and `ready` only if it meets the definition. Then
   replace the parent's body and remove `ready` from it if present; a
   tracker is never ready.
6. Print the children as `#<n> <title>` with their status, and suggest
   `/taskie:do` for the first ready one.

## Plan a milestone

Input is a goal such as `v0.2: offline mode`.

1. Run the "before any stage" check from the conventions.
2. Name the milestone: the text before the first colon is its title and the
   rest its description. Without a colon, propose a short title and confirm
   it. If a milestone with that title exists, plan into it.
3. Read the README, the repo's CLAUDE.md files and the code the goal touches,
   and list open issues that already belong to the goal.
4. Ask the user, in one message, about anything ambiguous whose answer would
   change the scope, including what done looks like for the goal. Skip this
   step when nothing is ambiguous. Every other guess goes under the drafts'
   Assumptions; in autonomous mode, so do these questions' answers (see the
   conventions).
5. Draft the work:
   - new issues in `/taskie:new`'s format, in this milestone rather than a
     proposed one, each with a type and a priority (the goal was triaged by
     planning it), final acceptance criteria, Out of scope,
     Edge cases and Assumptions, and `Depends on #<n>` for any order between
     them
   - an issue that would not fit in one reviewable pull request becomes a
     tracker with sub-issues, drafted as in "Split an issue"
   - existing open issues to add to the milestone
6. Show the milestone, every draft and the existing issues to add in one
   message, saying which drafts meet the definition of ready. Ask which
   drafts to create and which existing issues to add, as one batch (see
   "Asking the user" in the conventions), and wait for the answer.
7. Apply what the user approved: create the milestone if needed, create the
   issues and sub-issues in it (`ready` only where the definition holds),
   and add the existing issues to it.
8. Print the milestone's issues in dependency order with their statuses, and
   suggest `/taskie:do` for the first ready one.
