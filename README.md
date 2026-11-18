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
| `/taskie:new <text>` | Turns a chat request, bug report or review findings into issues that are already triaged: type, priority, acceptance criteria, and `ready` when they qualify. It can also look for work in a scope you name, such as `review skills/do for bugs` or `look at the last 20 commits for unfinished work`. Shows the drafts and creates only after you confirm. |
| `/taskie:new [#n]` | With no text, triages up to 10 issues that have no priority yet (usually filed outside taskie), or issue `#n`, in one table, and applies it after you approve. |
| `/taskie:plan #n` | Adds acceptance criteria, splits large issues into sub-issues, and marks issues ready. |
| `/taskie:plan <goal>` | Turns a goal such as `v0.2: offline mode` into a milestone with issues. |
| `/taskie:do [n]` | Implements an issue in its own worktree, opens a pull request, reviews it with `/code-review`, fixes in-scope findings and posts a summary comment. Run it again to address feedback, including a conflict with the base branch, which it merges and resolves, and failing checks. With no argument it takes the current issue, or the most urgent in-progress or ready one, and asks when several qualify. |
| `/taskie:ship [pr]` | Updates the PR with the base branch, verifies, merges, cleans up, and offers a release when a milestone completes. With no argument it takes the current PR or the one awaiting approval, and asks when several do. |

Claude can run `/taskie`, `new` and `plan` on its own when the conversation
calls for it (for example "file a bug for this"). `do` pushes and opens pull
requests, so it runs only when you type it or, once a taskie command has run in
the session, when you explicitly ask for that work ("work on #12"). `ship`
merges, so it runs only when you type it.

Whenever taskie needs a decision it asks a multiple-choice question, with the
recommended option first; you can always pick "Other" and type instead. Tell
it to proceed without asking and, for the rest of the session, it takes the
recommended option itself and lists what it chose at the end. It still stops
for a merge or a release, for `do`'s stop conditions (the work outgrows the
issue or needs a decision it does not settle, reaches data, auth, secrets or
a public API, an acceptance criterion looks wrong, or the repo has no test
setup for the tests it needs) and for questions with no recommended answer.

Each issue is a small spec. Besides the problem and acceptance criteria, it
lists what is out of scope, the edge cases with their expected outcomes, and
every assumption taskie made while drafting it: questions that would change
the scope are asked, and other guesses are written down instead of made
silently (in autonomous mode, all of them are written down). `/taskie:do`
works within that spec. It says how the change fits the existing code, maps
every criterion and edge case to a test, starts a bug fix with a test that
fails, and lists each criterion and edge case in the PR with the test that
proves it. If your repo has no test setup for code that tests could check,
it stops and offers to file an issue to set up a test harness first;
documentation, configuration and prompts get named checks instead.

`/taskie:do` never touches your checkout. Each issue gets a git worktree at
`.worktrees/issue-<n>`, hidden from git through `.git/info/exclude` (your
`.gitignore` is left alone), and `/taskie:ship` removes it after merging.

## A typical flow

```
/taskie:new the export button does nothing on Safari
/taskie:plan #12
/taskie:do 12
/taskie:ship
```

Run `/taskie:plan` only when `/taskie:new` put the issue in the backlog: new
ends by suggesting `/taskie:do` or `/taskie:plan`, whichever applies. If plan
splits the issue into sub-issues, run `/taskie:do` on the one it suggests
instead. For larger work that is not a single issue yet, start with
`/taskie:plan <goal>`.

## Requirements

- Claude Code with the built-in `/code-review` skill (tested with 2.1.318)
- [GitHub CLI](https://cli.github.com/) (`gh`) 2.103 or later, authenticated
  (taskie uses sub-issues and other recent flags; older releases, such as
  some distributions ship, may lack them)
- git 2.38 or later (`/taskie:do` and `/taskie:ship` use `git merge-tree
  --write-tree`)
- A git repository with a GitHub remote, with issues enabled

Every command checks the gh and git versions and that the repository accepts
issues before it starts, and stops with what is missing.

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

## Configuring a repo: a `taskie` section in CLAUDE.md

taskie works with no setup. To change its defaults for one repo, add a
`## taskie` section to the repo's CLAUDE.md (`CLAUDE.md` at the root or
`.claude/CLAUDE.md`). It is free-form markdown, and anything you write there
takes precedence over taskie's defaults; the rest of CLAUDE.md does not
change them. For example:

```markdown
## taskie

verify: just verify
setup: npm ci
Base branch is `develop`.
Merge with squash.
Run reviews at high level for every priority.
```

If `verify` or `setup` is missing, `/taskie:do` detects a likely command,
confirms it with you, and offers to save it in that section as a commit of its
own in the pull request, so your checkout is never changed. It adds the
section if there is none, or a CLAUDE.md (`.claude/CLAUDE.md` in a Claude Code
plugin or marketplace repo, `CLAUDE.md` at the root otherwise).

taskie finds the git remote that points at the GitHub repo. If it cannot tell
(no remote or several match), it asks, and `/taskie:do` offers to save a
`remote:` line there too.

## Labels

taskie creates these labels in your repo when it needs them:

| Label | Meaning |
|---|---|
| `type:bug`, `type:feature`, `type:chore`, `type:docs` | Kind of work |
| `P0` | Outage, data loss or security hole |
| `P1` | Major feature broken, no workaround |
| `P2` | Degraded, workaround exists |
| `P3` | Minor or cosmetic |
| `needs-info` | Waiting on answers from the reporter |
| `ready` | A complete spec (acceptance criteria, bounds, edge cases, assumptions) that fits in one pull request |

Status (in progress, in review, awaiting approval) is read from GitHub itself,
from linked branches, open PRs and taskie's review comment, so there are no
status labels to keep in sync.

## License

[MIT](LICENSE)
