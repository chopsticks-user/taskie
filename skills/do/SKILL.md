---
name: do
description: Implement an issue in its own worktree, open a pull request, review it with /code-review, fix the in-scope findings and post the review summary, all in one run. On an issue that already has a PR, address the feedback and review again. With no argument, pick the current or most urgent issue.
argument-hint: "[issue number]"
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**) Bash(gh --version*) Bash(git --version*) Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh issue develop --list *) Bash(gh pr list *) Bash(gh pr view *) Bash(gh pr diff *) Bash(gh run view *) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git merge-tree *) Bash(git remote -v*)
---

# taskie do

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and follow its
Precedence section, which says what else to read.

Input: $ARGUMENTS (an issue or PR number, with or without `#`, or empty)

## Pick the issue

1. Run the "before any stage" check from the conventions, and find the
   repo's `verify` and `setup` commands as the conventions describe. Every
   path below needs them. Do not save a detected one yet; that is offered
   once the worktree exists ("Start" step 3, "Address feedback" step 1).
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
   with `/taskie:new`, and leave the worktree in place. Then, if `verify`,
   `setup` or the git remote was detected or given rather than read from the
   taskie section (check the worktree's copy, which an earlier run of this
   issue may have saved into) or from an open PR that saves it, offer to
   save it as the conventions describe:
   a commit of its own in the worktree that holds only that file and passes
   `verify`.

## Implement

1. Read the code the issue touches. When resuming, read the branch's commits
   and any uncommitted changes first, and carry on from there.
2. The issue's Acceptance criteria, Edge cases and Out of scope are the spec
   this PR is derived from and bounded by. If the issue predates those
   sections or leaves one empty, derive what is missing from the issue and
   the code, as the conventions describe, and treat it as an assumption.
   Derive only what follows from the issue's own text and the code; a bound
   or expected outcome with more than one plausible reading is a decision
   the issue does not settle (step 5).
   State in chat how the change fits the system: the parts it changes, and
   the callers, dependents and existing behavior that must keep working.
3. State a short plan in chat: the changes, in order, and a test plan that
   maps every acceptance criterion and every edge case to the test that will
   cover it. Where no automated test can apply (documentation, a config
   value, a manual-only flow), name the check instead: what will be run or
   read, and what result proves it. Then proceed without waiting.
4. Make the change in small commits. Each commit is one logical step, passes
   `verify`, and follows the commit rules in the conventions. Write the tests
   from the test plan with the repo's existing test setup, next to the tests
   already there; keep changes within the issue's scope. For a `type:bug`
   issue, start with a test that reproduces the bug, and run it to see it
   fail before changing the code; note that failure for the PR. A test that
   passes before the fix does not reproduce the bug. Commit the test with
   the fix, so no commit fails `verify`.
5. Stop and ask the user before going on when:
   - the work turns out larger than the issue describes, or needs a decision
     the issue does not settle that would change its scope or acceptance
     criteria. A smaller guess, such as a name or a message's wording, is
     not a stop: make it and list it as an assumption in the PR's Notes
   - the change would touch stored data or migrations, authentication or
     authorization, secrets, or a public API or interface other code depends
     on, and the issue did not say so
   - an acceptance criterion or edge case looks wrong or impossible
   - the change is code that a test runner for its language could check (a
     library, an app, a script) and the repo has no test setup for it
     (`verify` runs no test runner): offer to file an issue for a minimal
     test harness with `/taskie:new`, which can then be done first. Do not
     skip the tests, and do not set up a harness inside this PR. A repo that
     has a test runner but no tests near this code is not this case; add the
     tests. Neither is content no ordinary test runner checks, such as
     documentation, configuration or prompts; it gets named checks
6. A problem found along the way that is outside the issue's scope, or
   listed under its Out of scope: do not fix it here. Note it, and file it
   with the review's out-of-scope findings in "Report" step 1, so the run
   asks the user once. If the run stops before "Report" for any reason, file
   the noted problems with `/taskie:new` before stopping, so none is lost.
7. When every acceptance criterion and edge case has its test or check, run
   `verify` once more on the final state, and run any manual check from the
   test plan. Every changed file must trace back to the spec or to a rule
   of the repo that the change triggers (a version bump, docs kept in sync,
   a lockfile); move anything else out (step 6).
8. Push the branch (never force-push) and open a PR into the base branch with
   the title and body from the conventions. Under Verification, list every
   acceptance criterion and every edge case with the test or check that
   covers it and its result from step 7, and, for a bug, the reproducing
   test's failure before the fix. Under Notes, list every assumption this
   run made (including spec sections it derived for an issue that lacked
   them), anything left out, and any repo setting this run saved. Then go to
   "Review".

## Address feedback

The issue already has an open PR, or the input was a PR that resolves no
issue.

1. Prepare the worktree as in "Start" step 1, reusing it or adding one for
   the PR's branch, and bring it up to date with the remote branch
   (fast-forward only). Then follow "Start" step 2, run `setup` in a
   worktree you just added (unless it is `none`), and offer to save a
   detected or given repo command as in "Start" step 3; a saved setting is
   a point to address, noted in the PR body's Notes.
2. Collect the feedback: comments and reviews on the PR, comments on its
   diff, and anything the user said when running this command. Skip findings
   the latest review summary already marks as fixed or filed: the latest
   `<!-- taskie:review` comment with a findings table (a carried-over marker
   from ship has none and links to the summary it carries).
   Also fetch the base from `<remote>` (the repo's git remote, as the backend
   finds it; if the fetch fails, report it and stop) and check whether the
   branch still merges cleanly with it: `git merge-tree --write-tree HEAD
   <remote>/<base>` exits 0 when it does and 1 on a conflict; report any
   other exit as an error and stop. A conflict is a point to address, since
   `/taskie:ship` stops on it and sends the user here. Read the PR's checks
   too, as the backend describes. Each failing check is a point to address,
   with its log where the backend can read one, unless the log shows the
   failure does not come from the PR (it fails on the base too, or the runner
   or network failed): report that as pre-existing and offer to file it with
   `/taskie:new` instead of changing the PR. A cancelled check needs a
   re-run, not a fix; say so.
3. If there is nothing to address, no check is still running, and the latest
   review marker is current, say the PR is ready for `/taskie:ship <pr>` and
   stop. If checks are still running and nothing else needs addressing, say
   the PR waits on them and stop.
4. List the points you will address, then proceed. Ask first about any point
   you disagree with or that would grow the scope.
5. Fix them as in "Implement": small commits, each passing `verify`. For a
   conflict with the base, merge `<remote>/<base>` into the branch (only into
   a clean worktree: if it has uncommitted changes, stop and show them),
   resolve the conflicts and commit the merge; if `verify` then fails because
   of the base itself, undo the merge, report the failure as pre-existing and
   stop. Push, and update the PR body if Verification or Notes changed. After
   any merge of the base, conflicted or not, they always have: rewrite
   Verification with the result of `verify` on the merged head (the same
   checks, the new numbers, naming that head), and record the merge in
   Changes and Notes (what it resolved, or that it was clean). With review
   fixes still to come, make this one body update after them, covering both.
   New commits make the review stale, so go on to "Review".

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
   6, to `/taskie:new` as review findings of this PR. It shows the drafts and
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
