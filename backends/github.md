# GitHub backend

How to carry out each taskie action on GitHub with the `gh` CLI (tested with
2.103; older versions may lack the sub-issue and duplicate flags). This is the only file that names `gh`
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
| check authentication | `gh auth status` |
| repo name and default branch | `gh repo view --json nameWithOwner,defaultBranchRef --jq '{repo: .nameWithOwner, base: .defaultBranchRef.name}'` |
| current user | `gh api user --jq .login` |

A repo whose `origin` is not on GitHub, or a `gh` that is not authenticated,
fails the "before any stage" check in `conventions.md`.

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
| `needs-triage` | `ededed` | Not triaged yet |
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
| search for duplicates | `gh issue list --state all --search '<keywords>' --limit 10 --json number,title,state,url` |
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
| create the linked branch and its worktree | `gh issue develop <n> --name issue-<n>-<slug> --base <base> --worktree .worktrees/issue-<n>` |

If `--worktree` fails, create the linked branch without it, then add the
worktree with git:

```bash
gh issue develop <n> --name issue-<n>-<slug> --base <base>
git fetch origin issue-<n>-<slug>
git worktree add .worktrees/issue-<n> issue-<n>-<slug>
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
| comments on the PR's diff | see below |
| replace a PR body | `gh pr edit <n> --body-file -` |
| PR of the current branch | the same `gh pr view` without `<n>` |
| open a PR | `gh pr create --base <base> --head <branch> --title '<title>' --body-file -` |
| comment | `gh pr comment <n> --body-file -` |
| merge | `gh pr merge <n> --merge --delete-branch --match-head-commit <sha>` (`--squash` or `--rebase` instead of `--merge` if `.taskie.md` says so) |

Comments on the PR's diff:

```bash
gh api 'repos/{owner}/{repo}/pulls/<n>/comments?per_page=100' --jq '.[] | {path, line, body, user: .user.login}'
```

The issues a PR resolves are its `closingIssuesReferences`. GitHub fills that
field only for PRs into the default branch, so for any other base also read
the `Closes #<n>` lines in the PR body and the `issue-<n>-` prefix of the
branch name.

Checks are green when every entry in `statusCheckRollup` has a `conclusion` of
`SUCCESS`, `NEUTRAL` or `SKIPPED`. Treat an empty `statusCheckRollup` as green,
but tell the user the repo has no checks.

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
gh api 'repos/{owner}/{repo}/milestones?state=all&per_page=100' --jq '.[] | {number, title, state, open_issues, closed_issues}'
```

## Releases

| Action | Command |
|---|---|
| check a tag is free | `gh release view '<tag>'` fails and `git ls-remote --tags origin '<tag>'` prints nothing |
| create a release | `gh release create '<tag>' --target <base> --title '<tag>' --notes-file -` |
