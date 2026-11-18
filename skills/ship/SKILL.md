---
name: ship
description: Merge a reviewed pull request after updating it with the base branch and verifying it, then close its issues and clean up. Running it is the user's approval to merge.
argument-hint: "[pr number]"
disable-model-invocation: true
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue view *) Bash(gh pr list *) Bash(gh pr view *) Bash(gh pr checks *) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git rev-list *) Bash(git merge-base *) Bash(git remote -v*)
---

# taskie ship

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and follow its
Precedence section, which says what else to read.

Input: $ARGUMENTS (a PR number, or empty to pick the current PR or one awaiting approval)

The user typing `/taskie:ship` is their approval to merge. Do not ask for a
second confirmation before merging; do stop at every gate below.

## Gate and update

1. Run the "before any stage" check from the conventions.
2. Find the PR: the given number; with no argument, the PR of the current
   branch or of the `.worktrees/issue-<n>` the session is in, otherwise the
   open PRs awaiting approval (derive status as the conventions describe).
   One is used (say which); several: ask which to ship, offering at most
   four, oldest first; none: say so and suggest `/taskie:do`. Find the
   issues it resolves, as the backend describes.
3. Use `.worktrees/issue-<n>` (or `.worktrees/pr-<pr>` for a PR that resolves
   no issue) if it exists, otherwise add a worktree there
   for the PR's branch. Bring it up to date with the remote branch
   (fast-forward only). Run git commands for the branch there.
4. Fetch the base branch from `<remote>` (the repo's git remote, as the
   backend finds it). Then refuse, saying why and what to run instead, unless
   all of these hold:
   - the PR is open and not a draft
   - its latest review marker is current: the marker's sha equals the PR's
     head, or the marker's sha is an ancestor of the head and every commit
     after it that is not on the base is a merge (`git rev-list --no-merges
     <marker sha>..HEAD ^<remote>/<base>` prints nothing; the base's own
     commits arrive with ship's earlier merge and were reviewed in their own
     PRs). Otherwise suggest `/taskie:do <pr>`.
   - the worktree has no unpushed commits of its own:
     `git rev-list --no-merges HEAD ^<PR head sha> ^<remote>/<base>`
     prints nothing. Merge commits, and base commits brought in by ship's own
     earlier merge, do not count. Otherwise list them and suggest pushing
     them, then `/taskie:do <pr>`, since they were never reviewed. The
     merge below deletes the local branch, so they would be lost.
   - its checks are green, as the backend defines. If checks are still
     running, say so and stop; do not wait at this step.
5. Fetch the base branch from `<remote>` and merge `<remote>/<base>` into the
   PR's branch in the worktree.
   - Already up to date: continue.
   - Conflicts: abort the merge, stop, and suggest `/taskie:do <pr>` to
     resolve them (that adds commits, so the PR needs a new review).
6. Run `verify` in the worktree. If it fails and step 5 made a merge commit,
   undo that merge commit (`git reset --hard ORIG_HEAD`, only after checking
   the worktree had no other changes), report the failure, and stop.
7. If step 5 made a merge commit, push it, then wait for the PR's checks on
   the new head as the backend describes. Stop if any fail.
8. Note the head sha that was just verified, and print a short summary: the
   PR, its title, the issues it closes, the checks, the review result and the
   merge method.

## Merge and clean up

1. Go back to the main checkout and remove the worktree with
   `git worktree remove .worktrees/issue-<n>` (or `.worktrees/pr-<pr>`).
   Everything is pushed, and the
   backend cannot delete a branch a worktree still has checked out. If git
   refuses because the worktree has changes, stop and show them.
2. Merge the PR as the backend describes, passing the verified head sha, with
   the merge method from `.taskie.md` or a merge commit by default. If the
   merge is refused (the head moved, or branch protection blocks it), report
   the reason and stop.
3. Close what the merge did not:
   - each issue the PR resolves that is still open: close it as done with
     the comment `Fixed by #<pr>.` (the backend closes issues automatically
     only for merges into the default branch)
   - each parent of those issues whose sub-issues are now all closed: close
     it as done with the comment `All sub-issues are done.`
4. Update the main checkout: if it is on the base branch with no uncommitted
   changes, pull with fast-forward only. If it is on the base branch but has
   changes, or is on another branch, only fetch, and tell the user why their
   checkout was left as it is.
5. Print what was merged and closed.

## Offer a release

For each milestone of the issues just closed, check whether it now has no
open issues. If so, offer a release; the merge approval does not cover it, so
ask before creating anything.

1. Tag: the milestone title if it looks like a version (`v1.2`, `1.2.0`,
   `v0.3.1`); otherwise ask for one. Check the tag is not already used.
2. Notes: the milestone's closed issues, grouped under `Features`,
   `Bug fixes`, `Chores` and `Documentation` by their `type:*` label (skip
   empty groups, put unlabelled ones under `Other`), one line each as
   `- <title> (#<n>)`. Skip issues closed as not planned or duplicate.
3. Show the tag, the target (the base branch) and the notes, and ask whether
   to create the release.
4. If the user agrees, create the release, then close the milestone. If they
   decline, ask whether to close the milestone anyway.
