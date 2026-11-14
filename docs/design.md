# taskie design

Status: v1 design, agreed 2026-11-14. Nothing is implemented yet.

This is the reference for the current design. When a decision changes, update
this document in the same pull request as the change.

## Goal

taskie is a Claude Code plugin that runs a software team's ticket-to-code
lifecycle on GitHub: work comes in as a chat request, bug report or review
finding, becomes an issue, gets triaged and planned, is implemented on a
branch, reviewed, and merged. It follows the way most tech companies move
tickets through a team, scaled down so one person and Claude can run it.

| Industry stage | taskie |
|---|---|
| Sources (support, PM, alerts, engineers) | `/taskie:intake` |
| Intake and triage | `/taskie:triage` |
| Backlog refinement, milestones | `/taskie:plan` |
| Execution (branch, code, PR) | `/taskie:work` |
| Code review | `/taskie:review` |
| Release and close the loop | `/taskie:ship` |
| Board view | `/taskie` |

## Plugin layout

```
taskie/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json       this repo is its own marketplace
├── conventions.md             default rules, in backend-neutral verbs
├── backends/github.md         maps each verb to gh commands
├── skills/
│   ├── taskie/SKILL.md        /taskie          board and help
│   ├── intake/SKILL.md        /taskie:intake
│   ├── triage/SKILL.md        /taskie:triage
│   ├── plan/SKILL.md          /taskie:plan
│   ├── work/SKILL.md          /taskie:work
│   ├── review/SKILL.md        /taskie:review
│   └── ship/SKILL.md          /taskie:ship
├── .claude/CLAUDE.md          repo instructions (a root CLAUDE.md fails validate --strict)
├── docs/design.md
├── README.md
├── LICENSE                    MIT
└── justfile
```

Every stage skill starts by reading `${CLAUDE_PLUGIN_ROOT}/conventions.md`,
then `${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` in the target
repo if it exists. Where they conflict, `.taskie.md` wins.

## Cross-cutting decisions

### Audience and distribution

taskie is published for others under the MIT license. The repo carries its own
`marketplace.json`, so users install it with `/plugin marketplace add
<owner>/taskie`. Because other people will use it, conventions are defaults
that a repo can override, and taskie must not assume anything only the author's
setup has.

### One skill per stage

Each stage is its own skill, invoked as `/taskie:<stage>`. The bare `/taskie`
works because the plugin and its board skill share the name. We chose this over
a single `/taskie <subcommand>` router because separate skills get real
autocomplete and per-stage invocation settings. `/taskie <stage>` with a space
is not supported, so there is one way to run each stage and the manual-only
gates cannot be bypassed.

| Skill | Claude may run it on its own | Why |
|---|---|---|
| `/taskie` | yes | read-only |
| `/taskie:intake` | yes | so "file a bug for this" in chat works; it confirms before creating |
| `/taskie:triage` | yes | changes go through one approval table |
| `/taskie:plan` | yes | edits go through approval |
| `/taskie:work` | no | creates branches, pushes, opens PRs |
| `/taskie:review` | no | pushes commits, posts PR comments |
| `/taskie:ship` | no | merges and closes issues |

Manual-only skills set `disable-model-invocation: true`.

### Repo overrides: `.taskie.md`

A repo may add an optional free-form markdown file named `.taskie.md` at its
root. Skills read it after the defaults and follow it where it differs. It needs
no schema, and anything in `conventions.md` can be overridden. Keys taskie
itself writes or reads there:

| Key | Used by | Meaning |
|---|---|---|
| `verify:` | work, review, ship | command that runs formatting, linting and all tests |
| `setup:` | work | command that prepares a fresh worktree (install dependencies) |
| review level | review | overrides the priority-based `/code-review` level |
| merge method | ship | overrides the merge-commit default |

A structured YAML config was rejected because only the model reads it, so a
schema adds maintenance without adding validation. A section in the repo's
CLAUDE.md was rejected because it would load in every session.

### Backend seam

v1 supports GitHub only, through `gh`. `conventions.md` and the skills describe
actions as backend-neutral verbs (find issue, create issue, set label, open PR,
merge, derive status, add sub-issue, and so on). `backends/github.md` is the
only file that maps verbs to `gh` commands. A future backend (GitLab, Jira)
would add one mapping file. The seam is kept to that single file because its
shape is a guess until a second backend exists.

### Labels

| Label | Set by | Meaning |
|---|---|---|
| `type:bug`, `type:feature`, `type:chore`, `type:docs` | intake, confirmed by triage | kind of work |
| `P0` | triage | outage or data loss, drop everything |
| `P1` | triage | major feature broken, no workaround |
| `P2` | triage | degraded, workaround exists |
| `P3` | triage | minor or cosmetic |
| `needs-triage` | intake | not yet triaged |
| `needs-info` | triage | waiting on answers from the reporter |
| `ready` | triage or plan | meets the definition of ready |

taskie creates missing labels idempotently. There are no area or component
labels in v1.

### Derived status

Status is derived from GitHub state, not tracked in labels, so it cannot go
stale when a step is done by hand.

| Status | Rule |
|---|---|
| needs triage | open, labelled `needs-triage` |
| needs info | open, labelled `needs-info` |
| backlog | open, has a priority, not `ready` |
| ready | open, labelled `ready`, no linked branch |
| in progress | has a linked branch (created with `gh issue develop`), no open PR |
| in review | has an open PR without a current review marker |
| awaiting approval | open PR whose latest `<!-- taskie:review sha=... -->` comment records the PR's current head commit |
| done | closed |

The marker records the head commit it reviewed instead of comparing
timestamps, because PR commit data from `gh` does not say which commits are
merges. Any new commit makes the review stale. `/taskie:ship` checks the
marker before it merges the base branch in, so its own merge commit does not
interfere. A parent issue that has been split into sub-issues is a tracker. It
never gets `ready` and is never worked on directly. The full rules, in
evaluation order, are in `conventions.md`.

### Definition of ready

An issue is ready when it has an acceptance-criteria checklist, a clear scope,
known dependencies, and fits in one reviewable pull request. The definition
lives in `conventions.md` because both triage (fast-track) and plan check it.

### Where taskie stops for you

| Stage | Approval point |
|---|---|
| intake | shows the full draft issue(s) before creating |
| triage | one table of proposed labels, comments and closes |
| plan | proposed body edits, sub-issues, milestone drafts |
| work | stops only if scope grows or it reaches data, auth or a public API |
| ship | typing `/taskie:ship` is the merge approval; a release needs its own confirmation |

### Branches, commits and pull requests

Branches are named `issue-<n>-<slug>`. Commits are small and each one passes
the repo's verify command. Pull requests target the base branch (the default
branch unless `.taskie.md` names another) and the body has, in order: a
`Closes #<n>` line per issue, then Why, Changes, Verification (each acceptance
criterion and how it was checked) and Notes.

### Components: skills first

v1 is skills plus shared markdown. Other plugin components are added only when
a skill shows it needs them:

| Component | Decision |
|---|---|
| Hooks | later, only to enforce rules the model is seen skipping (for example committing on the base branch) |
| MCP server | none; `gh` and `gh api` cover everything, a server would add a process, auth and tool-schema tokens |
| Subagents | none; review delegates to the built-in `/code-review` |

### Verifying this repo

`just verify` runs `claude plugin validate --strict .`, which checks the
manifests and skill frontmatter and fails on any warning. `just submit-check`
adds `--profile directory`, the checks the plugin directory runs at
submission. It is kept out of verify because it requires a listing icon, and
the first icon submitted can become the permanent listing icon, so no
placeholder is committed. Behavioral evals (`claude plugin eval`) are not part
of verify because they are slow and cost model usage; a separate `just eval`
can be added later.

## Stages

### `/taskie` (board)

Lists the current repo's open issues and PRs grouped by derived status, one
line each with number, title and priority. It ends with one suggested next
action, chosen in this order: a PR awaiting approval, then a needs-triage
issue, then the highest-priority ready issue (oldest first among equals).
`/taskie help` lists the stages. With no GitHub remote it says so and stops.

Rejected: milestone progress lines (not needed until plan is used), counts
only, cross-repo `--all`.

### `/taskie:intake`

Turns input into issues. Understood sources in v1:

| Source | Extracts |
|---|---|
| chat request | problem, context, draft acceptance criteria |
| bug report or stack trace | repro steps, expected vs actual, failing location, environment; missing parts are marked unknown, never invented |
| review findings | one issue per finding, linking the source PR and file:line |

Rules: one issue per unrelated item (splitting one large item into subtasks is
plan's job). Before drafting, search open and closed issues; if one looks like
a duplicate, show it and ask. Two body templates: bug, and everything else.
Labels are `type:*` plus `needs-triage`; priority is left to triage. The full
draft is shown and nothing is created until you confirm.

Not in v1: CI failure intake (would be one more source section).

### `/taskie:triage`

With no argument it takes every `needs-triage` issue plus `needs-info` issues
with new comments; with `#n` it takes that one. For each issue it reads the text,
greps the repo for the likely files, and proposes type, priority, outcome and
reason in one table. Nothing changes until you approve the table, optionally
editing rows.

Outcomes: accept (set priority, remove `needs-triage`, post a comment naming
the likely files), fast-track to `ready` when the issue already meets the
definition of ready, duplicate (close with a link), won't fix (close as not
planned with the reason), needs info (label and post specific questions).

Rejected: reproducing bugs (slow, needs per-project setup), text-only triage,
one-issue-at-a-time approval, asking the questions in chat instead of on the
issue.

### `/taskie:plan`

Two input shapes:

`/taskie:plan #n` refines an issue. It asks you about anything ambiguous,
rewrites the body with an acceptance-criteria checklist, and sets `ready` when
the issue meets the definition of ready. If the issue would not fit in one
reviewable pull request, it proposes children, each with its own acceptance
criteria, and creates them as native GitHub sub-issues. The parent becomes a
tracker.

`/taskie:plan <goal>` (for example `v0.2: offline mode`) drafts a milestone and
its issues in intake's format, split where needed, and creates them all after
one approval.

Size is judged against "one reviewable pull request", not estimated. Rejected:
size labels, task lists in the parent body, a separate milestone skill.

### `/taskie:work`

Manual-only. Steps:

1. Refuse issues that are not `ready`, are parent trackers, or are already in
   progress.
2. Find `verify` and `setup`: read `.taskie.md`, else detect (`just verify`,
   `npm test`, `make check`, `cargo test`, ...) and confirm with you, then offer
   to save them to `.taskie.md`.
3. Create the linked branch with `gh issue develop`, then a worktree at
   `.worktrees/issue-<n>`, hidden through `.git/info/exclude` so the target
   repo's `.gitignore` is untouched. It lives inside the repo because Claude
   Code prompts for paths outside the working directory.
4. Run `setup`, then `verify`. If verify fails before any change, stop and
   report so a pre-existing failure is never mixed into the diff.
5. State a short plan and proceed. Stop and ask if the scope grows beyond the
   issue or the change reaches data, auth or a public API.
6. Implement in small commits, each passing verify. Unrelated problems found
   along the way go to intake.
7. Push and open the PR in the standard format.

Running `/taskie:work n` again on an issue that already has a PR resumes in the
same worktree and branch. That is how review feedback is addressed.

Rejected: waiting for plan approval before coding, draft PRs as the progress
signal, assignee-only tracking, working on a branch in the main checkout.

### `/taskie:review`

Manual-only. Takes a PR number, or the PR of the current issue branch. It
invokes Claude Code's built-in `/code-review` once, at a level set by the
linked issue's priority (P0 and P1 at high, P2 and P3 at medium, overridable in
`.taskie.md`). If `/code-review` is unavailable it stops with a message naming
the minimum Claude Code version.

In-scope findings are fixed in the issue's worktree in small commits, verified
and pushed, with no second review pass. Findings it disagrees with are left
with a reason. Out-of-scope findings go to intake's review-findings source. It
then posts one summary comment carrying the `<!-- taskie:review sha=... -->` marker and
listing each finding as fixed (commit), left (reason) or filed (new issue).

Rejected: a bundled reviewer agent, a fixed review level, proposing fixes
before applying them, inline PR comments.

### `/taskie:ship`

Manual-only, and typing it is the merge approval (GitHub does not let an author
approve their own PR). Steps:

1. Refuse unless checks are green and the review marker is current (see
   derived status).
2. Merge the base into the branch, run verify, push, and print a one-screen
   summary.
3. Remove the worktree (everything is pushed by now, and `gh pr merge
   --delete-branch` cannot delete a branch a worktree has checked out).
4. Merge with `gh pr merge --merge --delete-branch --match-head-commit <sha>`,
   or the method `.taskie.md` names. The sha is the commit that was just
   verified, so GitHub refuses the merge if anything landed after it.
5. Close issues GitHub did not close (it only does so for merges into the
   default branch), and close a parent issue when its last sub-issue closes.
6. Switch to the base branch and `git pull --ff-only`.
7. If the merge closed the last open issue of a milestone, offer a release:
   tag from the milestone title when it is semver (for example `v0.2`), else
   ask; notes built from the milestone's issues grouped by type. Creating the
   release needs its own confirmation. Then close the milestone.

Rejected: a second confirmation before merging, requiring a GitHub approval,
rebasing, squash merges (they discard the small verified commits).

## Build plan

Each stage is one reviewable group of commits, made locally on `main` until the
repo has a GitHub remote (then one issue and one pull request per stage). Every
commit passes `just verify`, and each stage's last commit updates the README.

| Stage | Commit | Content |
|---|---|---|
| 0 Foundation | c1 | `plugin.json`, `marketplace.json`, LICENSE, README stub, `justfile` |
| | c2 | `conventions.md`: labels, priorities, derived status, definition of ready, branch/commit/PR format, approval points |
| | c3 | `backends/github.md`: verb to `gh` mapping, idempotent label creation |
| | c4 | `.taskie.md` override rule and README example, repo CLAUDE.md |
| 1 `/taskie` | c1 | board grouped by derived status |
| | c2 | next action line, help, README |
| 2 `:intake` | c1 | chat requests: splitting, dedupe, templates, labels, confirm |
| | c2 | bug reports and stack traces |
| | c3 | review findings, README |
| 3 `:triage` | c1 | classification, likely files, approval table, fast-track |
| | c2 | duplicate, won't fix, needs-info outcomes, README |
| 4 `:plan` | c1 | refine: acceptance criteria, definition of ready |
| | c2 | native sub-issues |
| | c3 | goal to milestone, README |
| 5 `:work` | c1 | preconditions, verify/setup discovery, linked branch, worktree, verify before |
| | c2 | plan, small verified commits, stop conditions, unrelated problems to intake |
| | c3 | push and PR, resume for rework, README |
| 6 `:review` | c1 | `/code-review` at priority-based level, fix in-scope findings |
| | c2 | out-of-scope findings to intake, summary comment, README |
| 7 `:ship` | c1 | gate, merge base in, verify, summary |
| | c2 | merge, close missed issues and parents, cleanup |
| | c3 | milestone release, README |
| 8 Hooks | | only if earlier stages show rules being skipped |

## Assumptions to verify

Each is checked at the start of the stage that depends on it, and this document
is updated with the result.

| Assumption | Stage | Fallback if false |
|---|---|---|
| `validate --strict` passes on a plugin with no skills yet | 0 | confirmed |
| `gh` can create and list native sub-issues | 4 | confirmed at the CLI level: `gh issue create --parent`, `gh issue edit --add-sub-issue`, `subIssues` JSON field (gh 2.103) |
| a branch from `gh issue develop` can be checked out in a worktree | 5 | `gh issue develop --worktree` exists (gh 2.103); not yet run against a real repo. Fallback in `backends/github.md`: create the linked branch, then `git worktree add` |
| a skill can invoke `/code-review` through the Skill tool | 6 | review asks you to run `/code-review` and reads its output |

## Out of scope for v1

Backports and maintained release branches, the incident fast lane, CI failure
intake, area labels, cross-repo boards, parallel review loops, non-GitHub
backends, and an eval suite.
