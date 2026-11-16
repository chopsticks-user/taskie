# taskie

A Claude Code plugin that runs a software team's ticket-to-code lifecycle on
GitHub. A chat request, bug report or review finding becomes an issue, which
gets triaged and planned, then implemented on a branch, reviewed, and merged,
the way most tech companies move tickets through a team.

> **Status: early.** Every command is written, and taskie has taken its own
> issues from request to merge, but it has not been used on other
> repositories yet. See [docs/design.md](docs/design.md) for the full design.

## Commands

| Command | What it does |
|---|---|
| `/taskie` | Board: open issues and PRs grouped by status, plus a suggested next action. `/taskie help` lists the stages. |
| `/taskie:new <text>` | Turns a chat request, bug report or review findings into issues that are already triaged: type, priority, acceptance criteria, and `ready` when they qualify. Shows the drafts and creates only after you confirm. |
| `/taskie:new [#n]` | With no text, triages issues filed outside taskie (or issue `#n`) in one table, and applies it after you approve. |
| `/taskie:plan #n` | Adds acceptance criteria, splits large issues into sub-issues, and marks issues ready. |
| `/taskie:plan <goal>` | Turns a goal such as `v0.2: offline mode` into a milestone with issues. |
| `/taskie:work <n>` | Implements a ready issue in its own worktree and opens a pull request. Run it again to address review feedback. |
| `/taskie:review [pr]` | Reviews the PR with `/code-review`, fixes in-scope findings, and posts a summary comment. |
| `/taskie:ship [pr]` | Updates the PR with the base branch, verifies, merges, cleans up, and offers a release when a milestone completes. |

Claude can run `/taskie`, `new` and `plan` on its own when the conversation
calls for it (for example "file a bug for this"). `work`, `review` and `ship`
push, comment and merge, so they only run when you type them.

`/taskie:work` never touches your checkout. Each issue gets a git worktree at
`.worktrees/issue-<n>`, hidden from git through `.git/info/exclude` (your
`.gitignore` is left alone), and `/taskie:ship` removes it after merging.

## A typical flow

```
/taskie:new the export button does nothing on Safari
/taskie:work 12
/taskie:review
/taskie:ship
```

## Requirements

- Claude Code with the built-in `/code-review` skill
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated
- A git repository with a GitHub remote

## Install

The repo is its own marketplace:

```
/plugin marketplace add chopsticks-user/taskie
/plugin install taskie@taskie
```

To try a local checkout for one session instead:

```
claude --plugin-dir /path/to/taskie
```

## Development

taskie is developed with taskie: issues and pull requests in this repo go
through its own stages. See [.claude/CLAUDE.md](.claude/CLAUDE.md) for how to
work on it.

## Configuring a repo: `.taskie.md`

taskie works with no setup. To change its defaults for one repo, add a
`.taskie.md` file at the repo root. It is free-form markdown, and anything you
write there takes precedence over taskie's defaults. For example:

```markdown
verify: just verify
setup: npm ci
Base branch is `develop`.
Merge with squash.
Run reviews at high level for every priority.
```

If `verify` or `setup` is missing, `/taskie:work` detects a likely command,
confirms it with you, and offers to save it here.

taskie finds the git remote that points at the GitHub repo. If it cannot tell
(no remote or several match), it asks and offers to save a `remote:` line.

## Labels

taskie creates these labels in your repo when it needs them:

| Label | Meaning |
|---|---|
| `type:bug`, `type:feature`, `type:chore`, `type:docs` | Kind of work |
| `P0` | Outage, data loss or security hole |
| `P1` | Major feature broken, no workaround |
| `P2` | Degraded, workaround exists |
| `P3` | Minor or cosmetic |
| `needs-triage` | Not triaged yet |
| `needs-info` | Waiting on answers from the reporter |
| `ready` | Clear acceptance criteria and fits in one pull request |

Status (in progress, in review, awaiting approval) is read from GitHub itself,
from linked branches, open PRs and taskie's review comment, so there are no
status labels to keep in sync.

## License

[MIT](LICENSE)
