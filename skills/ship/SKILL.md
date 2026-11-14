---
name: ship
description: Merge a reviewed pull request after updating it with the base branch and verifying it, then close its issues and clean up. Running it is the user's approval to merge.
argument-hint: "[pr number]"
disable-model-invocation: true
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue view *) Bash(gh pr list *) Bash(gh pr view *) Bash(gh pr checks *) Bash(git status*) Bash(git diff*) Bash(git log*) Bash(git rev-list *) Bash(git merge-base *)
---

# taskie ship

Read `${CLAUDE_PLUGIN_ROOT}/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS (a PR number, or empty for the current branch's PR)

The user typing `/taskie:ship` is their approval to merge. Do not ask for a
second confirmation before merging; do stop at every gate below.

## Gate and update

1. Run the "before any stage" check from the conventions.
2. Find the PR: the given number, or the PR of the current branch. Find the
   issues it resolves, as the backend describes.
3. Use `.worktrees/issue-<n>` if it exists, otherwise add a worktree there
   for the PR's branch. Bring it up to date with the remote branch
   (fast-forward only). Run git commands for the branch there.
4. Refuse, saying why and what to run instead, unless all of these hold:
   - the PR is open and not a draft
   - its latest review marker is current: the marker's sha equals the PR's
     head, or the marker's sha is an ancestor of the head and every commit
     after it is a merge (`git rev-list --no-merges <marker sha>..HEAD`
     prints nothing). Otherwise suggest `/taskie:review <pr>`.
   - its checks are green, as the backend defines. If checks are still
     running, say so and stop; do not wait at this step.
5. Merge the base branch into the PR's branch in the worktree (fetch first).
   - Already up to date: continue.
   - Conflicts: abort the merge, stop, and suggest `/taskie:work <n>` to
     resolve them (that adds commits, so the PR needs a new review).
6. Run `verify` in the worktree. If it fails and step 5 made a merge commit,
   undo that merge commit (`git reset --hard ORIG_HEAD`, only after checking
   the worktree had no other changes), report the failure, and stop.
7. If step 5 made a merge commit, push it, then wait for the PR's checks on
   the new head as the backend describes. Stop if any fail.
8. Note the head sha that was just verified, and print a short summary: the
   PR, its title, the issues it closes, the checks, the review result and the
   merge method.
