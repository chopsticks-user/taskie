---
name: do
description: Implement an issue in its own worktree, open a pull request, review it with /code-review, fix the in-scope findings and post the review summary, all in one run. On an issue that already has a PR, address the feedback and review again. With no argument, pick the current or most urgent issue.
argument-hint: "[issue number]"
disable-model-invocation: true
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh issue develop --list *) Bash(gh pr list *) Bash(gh pr view *) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git merge-tree *) Bash(git remote -v*)
---

# taskie do

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and follow its
Precedence section, which says what else to read.

Input: $ARGUMENTS (an issue or PR number, with or without `#`, or empty)

## Pick the issue

1. Run the "before any stage" check from the conventions, and find the
   repo's `verify` and `setup` commands as the conventions describe. Every
   path below needs them.
2. With a number: GitHub numbers issues and PRs in one sequence, so it names
   one or the other. An issue is used as is. A PR is taken with the issue it
   resolves (as the backend describes); if it resolves several, use the one
   whose number is in the branch name, else the highest-priority one; if it
   resolves none, go to "Address feedback" with the PR alone, using the
   worktree `.worktrees/pr-<pr>`, a review level of `medium`, and skipping
   anything that needs an issue.
3. With no argument:
   - the issue of the current branch (its `issue-<n>-` prefix) or of the
     `.worktrees/issue-<n>` the session is in, if that issue is open
   - otherwise derive the status of every open issue as the conventions
     describe and collect the candidates: issues in review (an open PR with
     no current review marker), then in progress (an interrupted run), then
     ready, each group ordered by priority (P0 first), then oldest first
   - one candidate: use it and say which. Several: ask which to take,
     offering at most four, in that order. None: say so and suggest
     `/taskie:new` or `/taskie:plan #<n>`
4. Read the issue. Decide how to continue:
   - it has an open PR: go to "Address feedback"
   - it has a linked branch but no PR: it is in progress, probably an
     interrupted run. Unless the user just picked it, ask whether to resume
     it; if yes, continue with "Start", reusing that branch
   - it is a tracker: stop and list its ready sub-issues
   - it is closed, or not labelled `ready`: stop, and suggest
     `/taskie:plan #<n>`

## Start

1. Prepare the worktree:
   - make sure `.worktrees/` is listed in the repository's `info/exclude`
     file (`$(git rev-parse --git-common-dir)/info/exclude`), adding it if
     missing
   - if `.worktrees/issue-<n>` already exists, use it
   - otherwise create the linked branch and its worktree from the base
     branch, as the backend describes (or, when resuming, add a worktree for
     the existing branch)
2. From here on, work only inside `.worktrees/issue-<n>`: run every command
   there and read and edit files only under that path. Never change the main
   checkout.
3. Run `setup` (unless it is `none`), then `verify`. If verify fails before
   any change, stop: report the failure as pre-existing, offer to file it
   with `/taskie:new`, and leave the worktree in place.

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
   fix it here. Note it, and file it with the review's out-of-scope findings
   in "Report" step 1, so the run asks the user once. If the run stops before
   "Report" for any reason, file the noted problems with `/taskie:new` before
   stopping, so none is lost.
6. When every acceptance criterion is met, run `verify` once more on the
   final state.
7. Push the branch (never force-push) and open a PR into the base branch with
   the title and body from the conventions. Under Verification, list every
   acceptance criterion with how it was checked; under Notes, anything left
   out. Then go to "Review".

## Address feedback

The issue already has an open PR, or the input was a PR that resolves no
issue.

1. Prepare the worktree as in "Start" step 1, reusing it or adding one for
   the PR's branch, and bring it up to date with the remote branch
   (fast-forward only). Then follow "Start" step 2, and run `setup` in a
   worktree you just added (unless it is `none`).
2. Collect the feedback: comments and reviews on the PR, comments on its
   diff, and anything the user said when running this command. Skip findings
   the latest `<!-- taskie:review` comment already marks as fixed or filed.
   Also fetch the base from `<remote>` (the repo's git remote, as the backend
   finds it; if the fetch fails, report it and stop) and check whether the
   branch still merges cleanly with it: `git merge-tree --write-tree HEAD
   <remote>/<base>` exits 0 when it does and 1 on a conflict; report any
   other exit as an error and stop. A conflict is a point to address, since
   `/taskie:ship` stops on it and sends the user here.
3. If there is nothing to address and the latest review marker is current,
   say the PR is ready for `/taskie:ship <pr>` and stop.
4. List the points you will address, then proceed. Ask first about any point
   you disagree with or that would grow the scope.
5. Fix them as in "Implement": small commits, each passing `verify`. For a
   conflict with the base, merge `<remote>/<base>` into the branch (only into
   a clean worktree: if it has uncommitted changes, stop and show them),
   resolve the conflicts and commit the merge; if `verify` then fails because
   of the base itself, undo the merge, report the failure as pre-existing and
   stop. Push, and update the PR body if Verification or Notes changed. New
   commits make the review stale, so go on to "Review".

## Review

1. Pick the review level from the issue's priority: `high` for `P0` and
   `P1`, `medium` otherwise. A review level in the taskie section overrides
   this.
2. Run Claude Code's built-in `/code-review` through the Skill tool with the
   arguments `<level> <pr number>`. Do not pass `--comment` or `--fix`;
   taskie posts its own summary and makes its own fixes. It runs as a
   separate reviewer, so it does not share this run's view of the change.
   - If `/code-review` does not exist, stop and tell the user that
     `/taskie:do` needs a Claude Code version with the built-in
     `/code-review` skill. The PR stays open; re-run `/taskie:do <n>` later.
   - If the Skill tool refuses to run it, ask the user to run
     `/code-review <level> <pr number>` themselves, and continue from step 3
     once its findings are in the conversation.
3. Sort the findings:
   - in scope: in code this PR changed or behavior its issue covers, and
     fixable without growing the PR's scope
   - out of scope: real problems elsewhere, such as pre-existing bugs in
     untouched code
   - left: findings you disagree with after checking the code; note why
4. Fix the in-scope findings in small commits, each passing `verify`, then
   push. Review runs once per run: do not run `/code-review` again on the
   fixes.

## Report

1. Hand the out-of-scope findings, and any problems noted in "Implement" step
   5, to `/taskie:new` as review findings of this PR. It shows the drafts and
   asks the user to confirm; wait for that answer in this run, and record the
   issue numbers it creates. Add them to the PR body's Notes.
2. Post one summary comment on the PR. Its first line is the review marker
   from the conventions, with the PR's head commit after your fixes were
   pushed (that state, fixes included, is what the user approves at ship):

   ```
   <!-- taskie:review sha=<full head sha> -->
   ## taskie review

   Reviewed with `/code-review` at <level>.

   | # | Finding | Result |
   |---|---|---|
   | 1 | <one-line summary> (`path:line`) | fixed in <short sha> |
   | 2 | <one-line summary> (`path:line`) | left: <reason> |
   | 3 | <one-line summary> (`path:line`) | filed as #<n> |
   ```

   With no findings, replace the table with `No findings.` A finding the user
   declined to file is listed as `left: not filed`.
3. Print the PR's URL and the same table, and suggest `/taskie:ship <pr>`,
   reminding the user that running it is their approval to merge. Leave the
   worktree in place; ship and further feedback use it.
