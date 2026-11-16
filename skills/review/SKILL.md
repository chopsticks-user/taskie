---
name: review
description: Review a pull request with /code-review at a level set by the issue's priority, fix the in-scope findings, and post one summary comment.
argument-hint: "[pr number]"
disable-model-invocation: true
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue view *) Bash(gh pr list *) Bash(gh pr view *) Bash(git status*) Bash(git diff*) Bash(git log*)
---

# taskie review

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS (a PR number, or empty for the current branch's PR)

## Review and fix

1. Run the "before any stage" check from the conventions.
2. Find the PR: the given number, or the PR of the current branch. Stop if
   there is none or it is not open.
3. Find the issue the PR resolves, as the backend describes, and its
   priority. Pick the review level: `high` for `P0` and `P1`, `medium`
   otherwise. A review level in `.taskie.md` overrides this.
4. Use `.worktrees/issue-<n>` if it exists, otherwise add a worktree there
   for the PR's branch. Bring it up to date with the remote branch
   (fast-forward only). Run every command there and edit files only under
   that path.
5. Run Claude Code's built-in `/code-review` through the Skill tool with the
   arguments `<level> <pr number>`. Do not pass `--comment` or `--fix`;
   taskie posts its own summary and makes its own fixes.
   - If `/code-review` does not exist, stop and tell the user that
     `/taskie:review` needs a Claude Code version with the built-in
     `/code-review` skill.
   - If the Skill tool refuses to run it, ask the user to run
     `/code-review <level> <pr number>` themselves, and continue from step 6
     once its findings are in the conversation.
6. Sort the findings:
   - in scope: in code this PR changed or behavior its issue covers, and
     fixable without growing the PR's scope
   - out of scope: real problems elsewhere, such as pre-existing bugs in
     untouched code
   - left: findings you disagree with after checking the code; note why
7. Fix the in-scope findings in small commits, each passing `verify`, then
   push. Review runs once: do not run `/code-review` again on the fixes.

## Report

1. Hand the out-of-scope findings to `/taskie:new` as review findings of
   this PR. Intake shows the drafts and asks the user to confirm; record the
   issue numbers it creates.
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
3. Print the same table in chat and suggest `/taskie:ship <pr>`, reminding
   the user that running it is their approval to merge.
