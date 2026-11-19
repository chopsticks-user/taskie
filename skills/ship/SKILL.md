---
name: ship
description: Merge a reviewed pull request after updating it with the base branch and verifying it, then close its issues and clean up. Running it is the user's approval to merge.
argument-hint: "[pr number]"
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**) Bash(gh --version*) Bash(git --version*) Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue view *) Bash(gh pr list *) Bash(gh pr view *) Bash(gh pr diff *) Bash(gh pr checks *) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git rev-list *) Bash(git rev-parse *) Bash(git merge-base *) Bash(git merge-tree *) Bash(git remote -v*)
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
   backend finds it), and note the base's sha; if the fetch fails, report it
   and stop. Then refuse,
   saying why and what to run instead, unless all of these hold:
   - the PR is open and not a draft
   - its latest review marker is current, judged against the worktree's
     `HEAD` (which can hold a merge an earlier run did not push): the
     marker's sha equals `HEAD`, or it is an ancestor of `HEAD` and every
     commit after it that is not on the base is a clean merge:
     - `git rev-list --no-merges <marker sha>..HEAD ^<remote>/<base>` prints
       nothing, and
     - for each commit `git rev-list --merges <marker sha>..HEAD ^<remote>/<base>`
       prints, `git merge-tree --write-tree <commit>^1 <commit>^2` exits 0
       and prints exactly the commit's own tree (`git rev-parse
       <commit>^{tree}`); on a conflict it exits 1.

     The base's own commits arrive with ship's earlier merge and were
     reviewed in their own PRs. A merge that resolved conflicts or changed
     code by hand was not reviewed, so it fails. Otherwise suggest
     `/taskie:do <pr>`.
   - the worktree has no unpushed commits of its own:
     `git rev-list --no-merges HEAD ^<PR head sha> ^<remote>/<base>`
     prints nothing. Merge commits, and base commits brought in by ship's own
     earlier merge, do not count. Otherwise list them and suggest pushing
     them, then `/taskie:do <pr>`, since they were never reviewed. The
     merge below deletes the local branch, so they would be lost.
   - its checks are green, as the backend defines. If checks are still
     running, say so and stop; do not wait at this step.
5. Merge `<remote>/<base>`, as fetched in step 4, into the PR's branch in the
   worktree.
   - Already up to date: continue.
   - Conflicts: abort the merge, stop, and suggest `/taskie:do <pr>` to
     resolve them (that adds commits, so the PR needs a new review).
6. Run `verify` in the worktree. If it fails and step 5 made a merge commit,
   undo that merge commit (`git reset --hard ORIG_HEAD`, only after checking
   the worktree had no other changes), report the failure, and stop.
7. If `HEAD` is not the PR's head (step 5 made a merge commit, or an earlier
   run left one unpushed), push it; if the push is rejected, report it and
   stop. Then wait for the PR's checks on the new head as the backend
   describes, and stop if any fail.
8. If the latest review marker does not record the head (this run or an
   earlier one pushed a merge), comment on the PR to carry the review over,
   so its status stays "awaiting approval" if a later step stops. The first
   line is the review marker from the conventions with the head's sha; the
   second is `Review carried over by /taskie:ship after a clean merge of
   <base>; findings: <link to the review summary it carries>`, linking the
   comment with the findings table, not an earlier carried-over one. Step 4
   checked that nothing after the old marker is an unreviewed change.
9. Note the head sha that was just verified, and print a short summary: the
   PR, its title, the issues it closes, the checks, the review result and the
   merge method.

## Merge and clean up

1. Go back to the main checkout and remove the worktree with
   `git worktree remove .worktrees/issue-<n>` (or `.worktrees/pr-<pr>`).
   Everything is pushed, and the
   backend cannot delete a branch a worktree still has checked out. If git
   refuses because the worktree has changes, stop and show them.
2. Read the PR's mergeability as the backend describes, waiting while it is
   still being computed (right after a push, with no checks to wait on, it
   is, and a merge then is refused). If it stays uncomputed past the wait,
   say so and stop. If it is conflicting, stop and suggest `/taskie:do <pr>`.
3. Merge the PR as the backend describes, passing the verified head sha, with
   the merge method from the taskie section, or a merge commit by default. If
   the merge is refused, fetch the base again and compare it with the base
   sha noted in "Gate and update" step 4. If the base moved, report that and
   stop. If it did not and the refusal says the base was modified, repeat
   step 2 and retry the merge once; if that is refused too, report it and
   stop. Any other refusal (the head moved, branch protection) is reported,
   and the run stops.
4. Close what the merge did not:
   - each issue the PR resolves that is still open: close it as done with
     the comment `Fixed by #<pr>.` (the backend closes issues automatically
     only for merges into the default branch)
   - each parent of those issues whose sub-issues are now all closed: close
     it as done with the comment `All sub-issues are done.`
5. Update the main checkout: if it is on the base branch with no uncommitted
   changes, pull with fast-forward only. If it is on the base branch but has
   changes, or is on another branch, only fetch, and tell the user why their
   checkout was left as it is.
6. Print what was merged and closed.

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
