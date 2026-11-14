---
name: work
description: Implement a ready issue in its own worktree and open a pull request, or address review feedback on an issue that already has one.
argument-hint: "<issue number>"
disable-model-invocation: true
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue view *) Bash(gh issue develop --list *) Bash(gh pr list *) Bash(gh pr view *) Bash(git status*) Bash(git diff*) Bash(git log*)
---

# taskie work

Read `${CLAUDE_PLUGIN_ROOT}/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS (an issue number, with or without `#`)

## Start

1. Run the "before any stage" check from the conventions.
2. Read the issue. Decide how to continue:
   - it has an open PR: go to "Address review feedback"
   - it has a linked branch but no PR: it is in progress, probably an
     interrupted run. Ask whether to resume it; if yes, continue from step 4
     reusing that branch
   - it is a tracker: stop and list its ready sub-issues
   - it is closed, or not labelled `ready`: stop, and suggest
     `/taskie:plan #<n>`
3. Find the repo's `verify` and `setup` commands as the conventions describe.
4. Prepare the worktree:
   - make sure `.worktrees/` is listed in the repository's `info/exclude`
     file (`$(git rev-parse --git-common-dir)/info/exclude`), adding it if
     missing
   - if `.worktrees/issue-<n>` already exists, use it
   - otherwise create the linked branch and its worktree from the base
     branch, as the backend describes (or, when resuming, add a worktree for
     the existing branch)
5. From here on, work only inside `.worktrees/issue-<n>`: run every command
   there and read and edit files only under that path. Never change the main
   checkout.
6. Run `setup` (unless it is `none`), then `verify`. If verify fails before
   any change, stop: report the failure as pre-existing, offer to file it
   with `/taskie:intake`, and leave the worktree in place.

## Implement

1. Read the code the issue touches. When resuming, read the branch's commits
   and any uncommitted changes first, and carry on from there.
2. State a short plan in chat: the changes, in order, and how each acceptance
   criterion will be checked. Then proceed without waiting.
3. Make the change in small commits. Each commit is one logical step, passes
   `verify`, and follows the commit rules in the conventions. Add or update
   tests for new behavior; keep changes within the issue's scope.
4. Stop and ask the user before going on when:
   - the work turns out larger than the issue describes, or needs a decision
     the issue does not settle
   - the change would touch stored data or migrations, authentication or
     authorization, secrets, or a public API or interface other code depends
     on, and the issue did not say so
   - an acceptance criterion looks wrong or impossible
5. A problem found along the way that is outside the issue's scope: do not
   fix it here. Hand it to `/taskie:intake` (it will ask the user to
   confirm), note the new issue for the PR's Notes, and continue.
6. When every acceptance criterion is met, run `verify` once more on the
   final state.
