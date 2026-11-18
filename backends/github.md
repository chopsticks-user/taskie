# GitHub backend

How to carry out each taskie action on GitHub with the `gh` CLI (minimum
versions are under Prerequisites). This is the only file that names `gh`
commands; stages describe actions, and this file maps them.

## Rules for every command

- Pass multi-line text (issue bodies, comments, PR bodies, release notes)
  through standard input with a quoted heredoc, so the shell does not expand
  backticks or `$` inside it:

  ```bash
  gh issue comment 12 --body-file - <<'TASKIE_EOF'
  text
  TASKIE_EOF
  ```

- Ask for JSON (`--json ...`) when reading, and use `--jq` to keep output
  small.
- `{owner}` and `{repo}` in `gh api` arguments are filled in by `gh` from the
  current repository; leave them as written.
- If a command fails, show its error to the user and stop the current step.
  Do not retry a write with different flags to get around an error.

## Prerequisites

| Action | Command |
|---|---|
| gh version | `gh --version` |
| git version | `git --version` |
| check authentication | `gh auth status` |
| repo name, default branch and whether it accepts issues | `gh repo view --json nameWithOwner,defaultBranchRef,hasIssuesEnabled --jq '{repo: .nameWithOwner, base: .defaultBranchRef.name, issues: .hasIssuesEnabled}'` |
| current user | `gh api user --jq .login` |
| git remote of the repo | `git remote -v` (see below) |

Minimum versions: gh 2.103 (sub-issues, `--duplicate-of` and the
`subIssuesSummary` field; the version taskie is tested with, older ones may
lack these) and git 2.38 (`git merge-tree --write-tree`, checked only by do
and ship). The version is the
first `<major>.<minor>` or `<major>.<minor>.<patch>` in the command's first
line, so `gh version 2.103.3 (2026-10-26)` is 2.103.3 and `git version
2.39.3 (Apple Git-146)` is 2.39.3; compare it number by number, so 2.103 is
newer than 2.45. A version exactly at the minimum passes. If the command is
not found, the tool is missing.

A repo with no remote on GitHub, a missing or too old gh or git, a `gh`
that is not authenticated, or a repo whose `issues` is `false` (enable them
under the repository's Settings, General, Features) fails the "before any
stage" check in `shared/conventions.md`.

The git remote of the repo, written `<remote>` below, is often but not always
`origin`. Use a `remote:` line in the repo's taskie section (see
`shared/conventions.md`) if there is one. Otherwise take the remote whose
fetch URL ends in `<nameWithOwner>` or `<nameWithOwner>.git`, right after `/`
or `:`, compared case-insensitively. If no remote or more than one matches,
ask the user which to use. `/taskie:do` then offers to save it as `remote:` in
the taskie section, the way the conventions save repo commands. Only git
commands need it; `gh` resolves the repo itself.

## Labels

Colors and descriptions used when a label is missing:

| Label | Color | Description |
|---|---|---|
| `type:bug` | `d73a4a` | Something is broken |
| `type:feature` | `a2eeef` | New behavior |
| `type:chore` | `cfd3d7` | Maintenance, refactors, tooling |
| `type:docs` | `0075ca` | Documentation only |
| `P0` | `b60205` | Outage, data loss or security hole |
| `P1` | `d93f0b` | Major feature broken, no workaround |
| `P2` | `fbca04` | Degraded, workaround exists |
| `P3` | `c5def5` | Minor or cosmetic |
| `needs-info` | `d876e3` | Waiting on answers from the reporter |
| `ready` | `0e8a16` | Meets the definition of ready |

| Action | Command |
|---|---|
| list existing labels | `gh label list --limit 500 --json name --jq '.[].name'` |
| create a missing label | `gh label create '<name>' --color <color> --description '<description>'` |

Create only labels missing from the list. Never pass `--force`, which would
overwrite a label the repo already customized.

## Issues

| Action | Command |
|---|---|
| search for duplicates | `gh issue list --state all --search '<keywords>' --limit 10 --json number,title,state,stateReason,url` (`stateReason` tells a declined issue, `NOT_PLANNED`, from a finished one) |
| list open issues | `gh issue list --state open --limit 500 --json number,title,labels,milestone,subIssuesSummary,createdAt` |
| list issues with a label | `gh issue list --state open --label '<label>' --limit 500 --json number,title,labels,createdAt` |
| read one issue | `gh issue view <n> --json number,title,body,state,labels,milestone,parent,subIssues,subIssuesSummary,comments,url` |
| create an issue | `gh issue create --title '<title>' --label '<a>' --label '<b>' --body-file -` (add `--milestone '<title>'` and `--parent <n>` as needed) |
| replace an issue body | `gh issue edit <n> --body-file -` |
| add and remove labels | `gh issue edit <n> --add-label '<a>' --remove-label '<b>'` |
| set a milestone | `gh issue edit <n> --milestone '<title>'` |
| make an issue a sub-issue | `gh issue edit <parent> --add-sub-issue <child>` |
| comment | `gh issue comment <n> --body-file -` |
| close as done | `gh issue close <n> --reason completed` |
| close as won't fix | `gh issue close <n> --reason 'not planned' --comment '<reason>'` |
| close as duplicate | `gh issue close <n> --duplicate-of <original> --comment 'Duplicate of #<original>.'` |

An issue is a tracker when `subIssuesSummary.total` is greater than 0.

## Linked branches

| Action | Command |
|---|---|
| linked branches of one issue | `gh issue develop --list <n>` |
| create the linked branch and its worktree | `gh issue develop <n> --name issue-<n>-<slug> --base <base> --checkout --worktree .worktrees/issue-<n>` |

Run both from the repo's top-level directory, so `.worktrees/` lands at the
root where the other stages look for it.

If that fails (for example with a `gh` that has no `--worktree`), list the
issue's linked branches. Create the linked branch without `--checkout
--worktree` only if it is not listed (the failed command may already have
created it), then add the worktree with git:

```bash
gh issue develop <n> --name issue-<n>-<slug> --base <base>   # only if not linked yet
git fetch <remote> issue-<n>-<slug>:refs/remotes/<remote>/issue-<n>-<slug>
git worktree add --track -b issue-<n>-<slug> .worktrees/issue-<n> <remote>/issue-<n>-<slug>
```

Linked branches of all open issues in one call (for the board):

```bash
gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, first: 100) {
      nodes { number linkedBranches(first: 5) { nodes { ref { name } } } }
    }
  }
}' --jq '.data.repository.issues.nodes[] | select(.linkedBranches.nodes | length > 0) | {number, branches: [.linkedBranches.nodes[].ref.name]}'
```

## Pull requests

| Action | Command |
|---|---|
| list open PRs | `gh pr list --state open --limit 200 --json number,title,headRefName,headRefOid,baseRefName,isDraft,closingIssuesReferences,comments` |
| read one PR | `gh pr view <n> --json number,title,body,state,isDraft,baseRefName,headRefName,headRefOid,closingIssuesReferences,comments,reviews,statusCheckRollup,mergeable,mergeStateStatus,url` |
| commits of a PR | `gh pr view <n> --json commits --jq '.commits[].messageHeadline'` |
| diff of a PR | `gh pr diff <n>` (add `--name-only` for the file list) |
| comments on the PR's diff | see below |
| replace a PR body | `gh pr edit <n> --body-file -` |
| PR of the current branch | the same `gh pr view` without `<n>` |
| open a PR | `gh pr create --base <base> --head <branch> --title '<title>' --body-file -` |
| comment | `gh pr comment <n> --body-file -` |
| merge | `gh pr merge <n> --merge --delete-branch --match-head-commit <sha>` (`--squash` or `--rebase` instead of `--merge` if the taskie section says so) |

Comments on the PR's diff:

```bash
gh api 'repos/{owner}/{repo}/pulls/<n>/comments?per_page=100' --jq '.[] | {path, line, body, user: .user.login}'
```

The issues a PR resolves are its `closingIssuesReferences`. GitHub fills that
field only for PRs into the default branch, so for any other base also read
the `Closes #<n>` lines in the PR body and the `issue-<n>-` prefix of the
branch name.

`statusCheckRollup` holds two kinds of entry: check runs, with `conclusion`
and `detailsUrl`, and commit statuses from outside CI, with `state` and
`targetUrl`. An entry is:

- green: a `conclusion` of `SUCCESS`, `NEUTRAL` or `SKIPPED`, or a `state` of
  `SUCCESS`
- still running: no `conclusion` yet, or a `state` of `PENDING` or `EXPECTED`
- cancelled: a `conclusion` of `CANCELLED` or `STALE`, which says a run was
  stopped or superseded, not that the code is wrong; it needs a re-run
- failing: anything else, such as `FAILURE`, `TIMED_OUT`, `ACTION_REQUIRED`
  or a `state` of `FAILURE` or `ERROR`

Checks are green when every entry is. Treat an empty `statusCheckRollup` as
green, but tell the user the repo has no checks. To wait for checks on the
current head, run `gh pr checks <n> --watch --fail-fast`; it exits non-zero if
a check fails. If its output says no checks were reported, the repo has no
checks: treat that as green, whatever the exit code.

For a failing GitHub Actions check, read the log of its failed steps with
`gh run view --job <job id> --log-failed`, taking the job id from the entry's
`detailsUrl` (`.../actions/runs/<run id>/job/<job id>`). If gh cannot give the
log yet (the rest of the run is still going), or the check is not from Actions,
give the user the entry's `detailsUrl` or `targetUrl` instead.

The latest review marker is the last entry in `comments` whose `body` starts
with `<!-- taskie:review sha=`; compare its sha with `headRefOid`.

`gh pr merge --delete-branch` cannot delete a local branch that a worktree has
checked out, so remove the worktree before merging.

## Milestones

`gh` has no milestone command; use the REST API.

| Action | Command |
|---|---|
| list milestones | see below |
| create a milestone | `gh api repos/{owner}/{repo}/milestones -f title='<title>' -f description='<description>'` |
| issues in a milestone | `gh issue list --milestone '<title>' --state all --limit 500 --json number,title,state,labels` |
| close a milestone | `gh api -X PATCH repos/{owner}/{repo}/milestones/<number> -f state=closed` |

List milestones:

```bash
gh api 'repos/{owner}/{repo}/milestones?state=all&per_page=100' --jq '.[] | {number, title, description, state, open_issues, closed_issues}'
```

## Releases

| Action | Command |
|---|---|
| check a tag is free | see below |
| create a release | `gh release create '<tag>' --target <base> --title '<tag>' --notes-file -` |

A tag is free when `gh release view '<tag>'` fails and this prints `0`
(`matching-refs` matches by prefix, so the exact ref is selected):

```bash
gh api 'repos/{owner}/{repo}/git/matching-refs/tags/<tag>' --jq 'map(select(.ref == "refs/tags/<tag>")) | length'
```
