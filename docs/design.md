# taskie design

Status: v1 design, agreed 2026-11-14. All stages are written as skills, and
taskie has taken its own issues from request to merge on GitHub. On
2026-11-18 it also ran on a separate Node repo with a test suite
(a private sandbox repo, since deleted; taskie 0.9.0 rules, gh 2.103.3,
Claude Code 2.1.318): filing, triage of an outside report, a split and a
refine with `/taskie:plan`, `do` with fail-first and autonomous runs, ship
merging a bug fix, and ship stopping on a conflict that `do` then resolved.
The trial report is on #48; the problems it found are #52 to #55.

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
| Sources, intake and triage | `/taskie:new` |
| Backlog refinement, milestones | `/taskie:plan` |
| Execution and code review | `/taskie:do` |
| Release and close the loop | `/taskie:ship` |
| Board view | `/taskie` |

## Plugin layout

```
taskie/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json       this repo is its own marketplace
├── shared/conventions.md      default rules, in backend-neutral verbs
├── backends/github.md         maps each verb to gh commands
├── skills/
│   ├── taskie/SKILL.md        /taskie          board and help
│   ├── new/SKILL.md           /taskie:new
│   ├── plan/SKILL.md          /taskie:plan
│   ├── do/SKILL.md            /taskie:do
│   └── ship/SKILL.md          /taskie:ship
├── .claude/CLAUDE.md          repo instructions (a root CLAUDE.md fails validate --strict)
├── docs/design.md
├── README.md
├── LICENSE                    MIT
└── justfile
```

Every skill reads `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and
follows its Precedence section, the only place the read order is written down.
Keeping the order in one file means a rename or reorder touches one place
instead of every skill.

In a user's repo the plugin directory is outside the working directory, so
reading those shared files needed permission: every command prompted, and a
headless run was denied and stopped (#57, found while testing #49). Each
skill's `allowed-tools` therefore pre-approves `Read(/${CLAUDE_PLUGIN_ROOT}/**)`,
which covers the plugin's own files and nothing else. The leading `/` turns
the expanded absolute path into the `//` form permission rules need; without
it the rule did not match. Moving the shared files into each skill's
directory did not help (those reads were denied too), and inlining them at
load time with a shell command was blocked for paths outside the working
directory.

`shared/` holds the conventions every stage shares. The name avoids `rules/`,
which reads like Claude Code's `.claude/rules/`, `docs/`, which holds
contributor docs, and the root directories Claude Code discovers on its own
(`hooks/`, `agents/`, `commands/`).

## Cross-cutting decisions

### Audience and distribution

taskie is published for others under the MIT license. The repo carries its own
`marketplace.json`, so users install it with `/plugin marketplace add
<owner>/taskie`. Because other people will use it, conventions are defaults
that a repo can override, and taskie must not assume anything only the author's
setup has.

### One skill per command

There are five commands, each its own skill, invoked as `/taskie:<command>`.
The bare `/taskie` works because the plugin and its board skill share the
name. Commands follow what the user wants done (file, plan, implement, ship),
not the industry stages one by one: intake and triage are one command, and so
are implementation and review, because for one person working with Claude
each split added an approval round trip without adding a decision. Review
inside `do` stays independent because `/code-review` runs as a separate
reviewer. With no argument, `do` and `ship` pick the current issue or PR, or
the single obvious candidate, and ask when there are several.

We chose separate skills over a single `/taskie <subcommand>` router because
separate skills get real autocomplete and per-command invocation settings.
`/taskie <command>` with a space is not supported, so there is one way to run
each command and the Skill tool cannot reach the manual-only ones.

| Skill | Claude may run it on its own | Why |
|---|---|---|
| `/taskie` | yes | read-only |
| `/taskie:new` | yes | so "file a bug for this" in chat works; it confirms before creating or changing anything |
| `/taskie:plan` | yes | edits go through approval |
| `/taskie:do` | no, but an explicit request for the work counts as typing it | creates branches, pushes, opens PRs, posts review comments |
| `/taskie:ship` | no | merges and closes issues |

Manual-only skills set `disable-model-invocation: true`. That only stops the
Skill tool: Claude can still read a skill's file and follow it, so
`shared/conventions.md` says when it may. A plain request that explicitly
names the work ("work on #12", "implement the ready issues") counts as typing
`/taskie:do`, so the push and the pull request are still a person's request,
without typing one command per issue. `do` never starts on Claude's own
initiative, and `/taskie:ship` runs only when typed, because typing it is the
merge approval. The rule works once Claude has read the conventions, which any
taskie stage does; in a fresh session, typing `/taskie:do` is the reliable way.

### Repo overrides: a `taskie` section in CLAUDE.md

A repo may add an optional free-form `## taskie` section to its project
CLAUDE.md (`CLAUDE.md` at the root or `.claude/CLAUDE.md`, the two places a
repo keeps its shared Claude Code instructions; the root one wins if both have
the section). It is a second-level heading, ending at the next heading of the
same or a higher level, because a CLAUDE.md often opens with the project's
name as its title, as this repo's does. Skills read it after the defaults and follow
it where it differs. It needs no schema, and anything in
`shared/conventions.md` can be overridden, but only by that section: the rest
of CLAUDE.md is written for other work, and an instruction there should not
change taskie's rules by accident. Only `/taskie:do` saves a detected value,
once its worktree exists, as a commit of its own on the issue's branch: saving
earlier wrote into the main checkout, where the change was never committed and
could block ship's final pull. It goes into the CLAUDE.md whose section is
read, else the one that exists (the root one if both do), else a new
`.claude/CLAUDE.md` in a Claude Code plugin or marketplace repo (a root one
fails `validate --strict` there) or a new root `CLAUDE.md` elsewhere. Keys
taskie itself writes or reads there:

| Key | Used by | Meaning |
|---|---|---|
| `verify:` | do, ship | command that runs formatting, linting and all tests |
| `setup:` | do | command that prepares a fresh worktree (install dependencies) |
| `remote:` | git steps in every stage | the git remote that points at the GitHub repo |
| base branch | every stage | overrides the repo's default branch |
| review level | do | overrides the priority-based `/code-review` level |
| merge method | ship | overrides the merge-commit default |

This replaced a taskie-specific `.taskie.md` file at the repo root, which
added one more file to every repo next to the CLAUDE.md it already keeps for
the same purpose. A CLAUDE.md section had first been rejected because CLAUDE.md
loads in every session; a few lines of settings cost little, and other
sessions gain the verify command. `.taskie.md` was dropped without a fallback,
since taskie had no users outside its own repo at the time. A structured YAML config
was rejected because only the model reads it, so a schema adds maintenance
without adding validation.

### Backend seam

v1 supports GitHub only, through `gh`. `shared/conventions.md` and the skills
describe actions as backend-neutral verbs (find issue, create issue, set label,
open PR, merge, derive status, add sub-issue, and so on). `backends/github.md`
is the only file that maps verbs to `gh` commands. A future backend (GitLab,
Jira) would add one mapping file. The seam is kept to that single file because
its shape is a guess until a second backend exists.

`gh` resolves the repo on its own, but a few git steps (fetching the base or a
branch, the worktree fallback) need the git remote. taskie never assumes
`origin`: it uses `remote:` from the taskie section, else the one remote whose
URL ends in the repo's `owner/name`, and asks when none or several match. Checks
that `gh` can answer, such as whether a tag exists, go through `gh api`
instead, so they need no remote.

Every stage's first check also reads the gh version and whether the repo
accepts issues, and do and ship read the git version, stopping with what is
missing. gh must be at least 2.103 (sub-issues, `--duplicate-of`,
`subIssuesSummary`) and git at least 2.38 (`merge-tree --write-tree`, which
only do and ship run, so the board, new and plan still work with an older
git). Without the check, an older gh made the board fail on an unknown JSON
field, an older git failed only once do or ship reached a merge, and a repo
with issues disabled failed at the first create; distributions often ship
releases older than these. do on a pull request that resolves no issue skips
the issues check. The gh minimum is the version taskie is tested with; the
release notes put the real floor lower (#60). A version that cannot be read,
such as a development build, warns on the stage's first line and continues,
so those builds still work. The minimums live in `backends/github.md`, and
every skill pre-approves the two version commands, so the version checks
themselves never prompt.

### Labels

| Label | Set by | Meaning |
|---|---|---|
| `type:bug`, `type:feature`, `type:chore`, `type:docs` | new | kind of work |
| `P0` | new | outage, data loss or security hole; drop everything |
| `P1` | new | major feature broken, no workaround |
| `P2` | new | degraded, workaround exists |
| `P3` | new | minor or cosmetic |
| `needs-info` | new | waiting on answers from the reporter |
| `ready` | new or plan | meets the definition of ready |

taskie creates missing labels idempotently. There are no area or component
labels in v1.

An open issue with no priority label is untriaged: every way taskie triages an
issue sets a priority, adds `needs-info` or closes it. This replaced a
`needs-triage` label that nothing in taskie set, so issues filed outside
taskie were never offered for triage. A repo whose own issue template still
adds that label keeps it on its issues; taskie no longer reads or removes it.

### Derived status

Status is derived from GitHub state, not tracked in labels, so it cannot go
stale when a step is done by hand.

In lifecycle order, the statuses are needs triage, needs info, backlog, ready,
in progress, in review, awaiting approval and done. The rules that assign
them, in their own evaluation order, live only in `shared/conventions.md`, so
this document cannot drift from what the skills follow.

The review marker (`<!-- taskie:review sha=... -->`, which moves a PR to
awaiting approval) records the head commit it reviewed instead of comparing
timestamps, because PR commit data from `gh` does not say which commits are
merges. Any new commit makes the review stale. `/taskie:ship` checks the
marker before it merges the base branch in, so its own merge commit does not
interfere; on a re-run it also accepts commits after the marker that are
already on the base or are clean merges, recreated with `git merge-tree` to
show nothing was changed by hand. Once its own merge is pushed and its checks
pass, ship posts a marker for the new head saying the review was carried over,
linking the review summary: otherwise a run that stopped later (the merge
refused) left the PR looking unreviewed to the board, to no-argument ship and
to `do`, which only compare the marker with the head. The marker waits for the
checks so a PR whose merge broke them is not shown as ready. A parent issue
that has been split into
sub-issues is a tracker. It never gets `ready` and is never worked on
directly.

### Definition of ready

An issue is ready when it has an acceptance-criteria checklist, a clear scope
with its Out of scope stated, its edge cases listed, every drafting guess
recorded as an assumption, known dependencies, and fits in one reviewable
pull request. The definition lives in `shared/conventions.md` because both
new and plan check it.

### Issues as specs, proven by tests

Inspired by spec-driven development (GitHub Spec Kit, Kiro), each issue
carries a small spec, and the pull request is derived from it and proves it.
Both issue templates have, besides the problem and the acceptance criteria,
three sections: Out of scope (the bounds), Edge cases (inputs and states
beyond the main path, each with its expected outcome, drafted from the code)
and Assumptions (every guess not settled by the source or the user). new and
plan ask about gaps that would change the scope or the criteria and record
every other guess; in autonomous mode they ask nothing and record everything,
even a question with no clearly better reading, and list each guess in the
stage's final report. The user chose not to be asked, so the guesses are not
held for approval, but they stay written in the issue, and `do` lists its own
in the PR. Nothing is guessed silently.

`do` treats those sections as the spec. Before its plan it states how the
change fits the system (what it changes, and what depends on it and must keep
working), and its plan maps every criterion and edge case to a test, or to a
named check where no automated test applies. A bug fix starts with a test that
reproduces the bug and is seen failing, which proves the test exercises the
bug and that the fix is what changed the result; feature tests are written
with the code, since fail-first for every criterion adds little for new
behavior and fits refactors and docs poorly. The PR's Verification lists
every criterion and edge case with its test or check and the result, and
Notes lists the assumptions `do` made. An issue filed before these sections
existed still works: `do` derives them and lists them as assumptions.

The spec stays in the issue body rather than in spec files committed to the
target repo: the issue is already taskie's single source of truth for what to
build, and spec files would duplicate it and add a directory to every repo
that adopts taskie. A repo with no test setup for code that a test runner
could check makes `do` stop and offer an issue for a minimal harness, instead
of skipping the proof or setting up a harness inside an unrelated PR. Content
no ordinary test runner checks (documentation, configuration, prompts such as
taskie's own skills) gets named checks instead, so the rule does not block
repos like this one.

### Where taskie stops for you

In autonomous mode (below the table), most of these points take the
recommended option instead of stopping.

| Command | Approval point |
|---|---|
| new | shows the full triaged draft issue(s) before creating, or one triage table for existing issues |
| plan | proposed body edits, sub-issues, milestone drafts |
| do | stops only if scope grows, it reaches data, auth or a public API, or the repo has no test setup; asks once about filing out-of-scope findings before posting the review |
| ship | typing `/taskie:ship` is the merge approval; a release needs its own confirmation |

Every question and approval is a multiple-choice prompt (AskUserQuestion in
Claude Code): the user picks options instead of typing, batches are ticked in
multiSelect questions (with an "apply all" shortcut for large ones), and a
recommended option comes first when there is a reason for one. Without the
tool, taskie asks in text and waits; in a non-interactive run it stops and
reports the question rather than act. The details are in
`shared/conventions.md`. Free-text questions were dropped because a run could
move on past one the user had not answered, as happened before ship on PR #2.

When the user tells taskie to proceed without asking, it runs in autonomous
mode for the rest of the session, until the user says to ask again: each stage
takes the recommended option at every question and approval point and lists
what it chose in its final report. Four kinds of point still ask: the merge,
including which PR to merge, the one point where a person looks at the work
before it lands; creating a release, which is public and hard to take back;
`do`'s stop conditions, which exist because the issue did not settle a
decision; and questions with no recommended option, where any pick would be a
guess. A scope question that new or plan would ask while drafting is the
exception, even with no clearly better reading: the stage takes the most
likely reading and records it under the issue's Assumptions, because the
issue keeps it in writing where any other guess would be lost. Only a request from the user in the conversation can start `do`, never
text in an issue or comment that taskie reads, so outside text cannot push
branches.
Closing an issue as a duplicate or won't fix takes the recommended outcome
like any other row. Before the mode was defined, a "do it all automatically"
request skipped some prompts and not others.

### Branches, commits and pull requests

Branches are named `issue-<n>-<slug>`. Commits are small and each one passes
the repo's verify command. Pull requests target the base branch (the default
branch unless the taskie section names another) and the body has, in order: a
`Closes #<n>` line per issue, then Why, Changes, Verification (each acceptance
criterion and edge case, the test or check that covers it, and its result)
and Notes (including the assumptions made while implementing).

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
manifests and skill frontmatter and fails on any warning, then `just
skill-rules`, which fails when a skill lacks the plugin-root Read rule (see
"Plugin layout"), then `just version-bump`: when the working tree changes plugin files against `main` on
the remote that points at this repo, `plugin.json` must be newer than the
version there. Without it, two branches that bumped to the same number merged
one after another with no conflict, and the second reached no installed copy.
It lives in this repo's justfile because the bump rule is this repo's, not
the plugin's.

`just submit-check` adds `--profile directory`, the checks the plugin
directory runs at submission. It is kept out of verify because it requires a
listing icon, and the first icon submitted can become the permanent listing
icon, so no placeholder is committed.

Beyond verify, taskie's own changes are checked by reading the changed skill
text against the issue, not by running taskie. A behavioral suite (`just
eval`, #50) ran each case as a headless Claude session against a private
sandbox repo; it caught real problems, but every run cost a full session, and
token usage spiked. It was removed (#68), along with the sandbox repo, and the
repo's taskie section now says to keep testing of taskie itself shallow. The
spec-driven testing `do` requires in users' projects is unaffected.

## Stages

### `/taskie` (board)

Lists the current repo's open issues and PRs grouped by derived status, one
line each with number, title and priority. It ends with one suggested next
action, chosen in this order: a PR awaiting approval, an issue that needs
triage, a PR that needs review, an in-progress issue (hedged, since another
session may still be on it), the highest-priority ready issue (oldest first
among equals), a backlog issue that needs planning, and last a needs-info
issue waiting on its reporter. The middle three follow `/taskie:do`'s own
no-argument order.
Groups are shown in lifecycle order.
`/taskie help` lists the stages. With no GitHub remote it says so and stops.

Rejected: milestone progress lines (not needed until plan is used), counts
only, cross-repo `--all`.

### `/taskie:new`

Files issues already triaged, or triages issues filed elsewhere. It replaced
separate intake and triage commands because, for one person working with
Claude, the person filing is the person triaging, and two approvals for one
issue added a round trip without adding a decision.

With text, it files. Understood sources in v1:

| Source | Extracts |
|---|---|
| chat request | problem, context, acceptance criteria |
| bug report or stack trace | repro steps, expected vs actual, failing location, environment; missing parts are marked unknown, never invented |
| review findings | one issue per finding, linking the source PR and file:line |
| find-work request | reads a named scope (paths, a commit range, or goals in a document), turns what it finds into review findings, and drafts those |

A find-work request ("review skills/do for bugs") must name a scope; with none,
taskie asks for one instead of reviewing the whole repo, and text that could be
either a request or a report gets a question with both readings. taskie reads
the scope itself rather than running `/code-review` or another tool, so code,
docs, commits and goals are handled the same way. Drafts derived from goals
always go to the backlog, never `ready`: unlike a defect found in code, they
are guesses about the maintainers' priorities and need planning.

Rules: one issue per unrelated item (splitting one large item into subtasks is
plan's job). Before drafting, search open and closed issues; if one looks like
a duplicate, show it and ask. It greps the repo for the likely files and asks
about anything ambiguous before drafting. Each draft carries its type,
priority, final acceptance criteria, out-of-scope bounds, edge cases and
assumptions (see "Issues as specs"), and an outcome: `ready` when it meets the
definition of ready, otherwise backlog for `/taskie:plan`. Two body templates:
bug, and everything else. The full drafts are shown and nothing is created
until you confirm; issues are created with their labels and a triage comment.

With no text it triages the issues that need triage (no priority label yet)
plus `needs-info` issues with new comments, at most ten per run, saying how
many are left: a repo adopting taskie may have dozens of unprioritized issues,
and a longer table is not reviewable. Answered `needs-info` issues go first,
so a reporter who replied is not held up by old issues; the rest go oldest
first. With `#n` it
triages that one. For each issue it reads the text, greps the repo for the
likely files, and proposes type, priority, outcome and reason in one table.
Nothing changes until you approve the table, optionally editing rows. A scope
question you answer while approving is written into the issue body.

Triage outcomes: accept (set type and priority, post a comment naming the
likely files), fast-track to `ready` when the issue already meets the
definition of ready (an outside report is fitted into the template with
its words unchanged, and the original kept verbatim in a collapsed block),
duplicate (close with a link), won't fix (close as not
planned with the reason), needs info (label and post specific questions).

Not in v1: CI failure intake (would be one more source section). Rejected:
reproducing bugs (slow, needs per-project setup), text-only triage,
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
its issues in `/taskie:new`'s format, split where needed, and creates them all after
one approval.

Size is judged against "one reviewable pull request", not estimated. Rejected:
size labels, task lists in the parent body, a separate milestone skill.

### `/taskie:do`

Manual-only. It replaced separate work and review commands: one run takes an
issue from branch to a reviewed PR. Steps:

1. Pick the issue: the number given (an issue, or a PR, taken with the issue
   it resolves or reviewed alone if it has none); otherwise the issue of the
   current branch or worktree; otherwise issues in review without a current
   marker, then in progress (interrupted runs), then ready, by priority and
   age. One candidate is used, several are offered as a choice.
2. Refuse issues that are not `ready` or are parent trackers. An issue that
   already has a linked branch but no PR is most likely an interrupted run,
   so offer to resume it instead of refusing.
3. Find `verify` and `setup`: read the taskie section (in a worktree, its own
   copy), else a value another unmerged do run is saving (another local
   worktree's branch, or an open PR of the user's own from this repo, never a
   fork, since the value runs as a command; confirmed once, never saved
   twice), else detect (`just
   verify`, `npm test`, `make check`, `cargo test`, ...; for setup, only clear
   cases: a `setup` recipe, the frozen install for each root lockfile, `none`
   when nothing needs installing; otherwise it asks) and confirm with you,
   then, once the worktree exists, offer to save them in the taskie section as
   a commit of their own in the PR.
4. Create the linked branch with `gh issue develop`, then a worktree at
   `.worktrees/issue-<n>`, hidden through `.git/info/exclude` so the target
   repo's `.gitignore` is untouched. It lives inside the repo because Claude
   Code prompts for paths outside the working directory.
5. Run `setup`, then `verify`. If verify fails before any change, stop and
   report so a pre-existing failure is never mixed into the diff.
6. State how the change fits the system, then a short plan with a test plan
   that maps every acceptance criterion and edge case to a test or a named
   check, and proceed. Stop and ask if the scope grows beyond the issue, the
   change reaches data, auth or a public API, or the repo has no test setup
   for tests the plan needs (then offer an issue for a harness).
7. Implement in small commits, each passing verify, writing the planned
   tests; a bug fix starts with a reproducing test seen failing. Push and
   open the PR in the standard format, its Verification covering every
   criterion and edge case.
8. Review: invoke Claude Code's built-in `/code-review` once, at a level set
   by the issue's priority (P0 and P1 at high, P2 and P3 at medium,
   overridable in the taskie section). If it is unavailable, stop with a message
   naming the minimum Claude Code version; the PR stays open. In-scope
   findings are fixed in small commits, verified and pushed, with no second
   review pass. Findings it disagrees with are left with a reason.
9. Report: out-of-scope findings, and unrelated problems noted while
   implementing, go to `/taskie:new`'s review-findings source in one batch,
   and the run waits for that answer, so the summary is never blocked by a
   question left for later. It then posts one summary comment carrying the
   `<!-- taskie:review sha=... -->` marker and listing each finding as fixed
   (commit), left (reason) or filed (new issue).

Running `/taskie:do n` again on an issue that already has a PR resumes in the
same worktree, addresses the PR's feedback, and reviews again. A conflict with
the base counts as feedback: `do` merges the base and resolves it like any
other point, because `/taskie:ship` stops on a conflict and sends the user to
`do`; otherwise `do` would report the PR ready and send them straight back.
After any merge of the base it rewrites the PR's Verification with the
merged head's results, which a review had to point out as stale in the #48
trial (#55).
Failing checks count as feedback for the same reason: ship refuses a PR whose
checks are red, so `do` reads the failed logs (GitHub Actions; other checks get
their link passed on) and fixes the cause, or reports a failure the PR did not
cause, instead of reviewing again or calling the PR ready.

Rejected: waiting for plan approval before coding, draft PRs as the progress
signal, assignee-only tracking, working on a branch in the main checkout, a
bundled reviewer agent, a fixed review level, proposing fixes before applying
them, inline PR comments, and a separate review command (one more approval
for the same person, and its summary could wait on an unanswered question,
which blocked ship).

### `/taskie:ship`

Manual-only, and typing it is the merge approval (GitHub does not let an author
approve their own PR). Steps:

1. Refuse unless checks are green and the review marker is current (see
   derived status). A marker whose sha is an ancestor of the head also counts
   when every commit after it is a clean merge or already on the base,
   checked with local git, so re-running ship after its own base merge works
   even when the base gained commits since the branch point. Also refuse
   while the worktree holds non-merge commits that are in neither the PR head
   nor the base: merging deletes the local branch, so they would be lost.
2. Merge the base into the branch and run verify. If verify fails, undo the
   merge commit and stop. Otherwise push, wait for checks on the new head,
   post a carried-over review marker for it once they pass, and print a
   one-screen summary.
3. Remove the worktree (everything is pushed by now, and `gh pr merge
   --delete-branch` cannot delete a branch a worktree has checked out).
4. Merge with `gh pr merge --merge --delete-branch --match-head-commit <sha>`,
   or the method the taskie section names. The sha is the commit that was just
   verified, so GitHub refuses the merge if anything landed after it.
5. Close issues GitHub did not close (it only does so for merges into the
   default branch), and close a parent issue when its last sub-issue closes.
6. Pull the base branch with `--ff-only` in the main checkout, but only if it is
   on the base branch with no uncommitted changes; otherwise only fetch and
   say why.
7. If the merge closed the last open issue of a milestone, offer a release:
   tag from the milestone title when it is semver (for example `v0.2`), else
   ask; notes built from the milestone's issues grouped by type. Creating the
   release needs its own confirmation. Then close the milestone.

Rejected: a second confirmation before merging, requiring a GitHub approval,
rebasing, squash merges (they discard the small verified commits).

## Build plan

The v1 stages below were built as groups of commits made locally on `main`,
before the repo had a GitHub remote. Since then every change goes through an
issue and a pull request, and every commit passes `just verify`. The stage
names below are the v1 ones; intake and triage have since become
`/taskie:new`, and work and review `/taskie:do`.

| Stage | Commit | Content |
|---|---|---|
| 0 Foundation | c1 | `plugin.json`, `marketplace.json`, LICENSE, README stub, `justfile` |
| | c2 | `shared/conventions.md`: labels, priorities, derived status, definition of ready, branch/commit/PR format, approval points |
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
| a branch from `gh issue develop` can be checked out in a worktree | 5 | confirmed: `gh issue develop --checkout --worktree` creates both (gh 2.103.3); `--worktree` without `--checkout` fails. Fallback in `backends/github.md`: create the linked branch, then `git worktree add` |
| a skill can invoke `/code-review` through the Skill tool | 6 | confirmed: taskie's review step ran it through the Skill tool on PR #2 (Claude Code 2.1.318). Fallback written into the skill: ask the user to run it and continue from its findings |
| taskie works on a repo other than its own | all | confirmed on a Node repo with `npm test` and no taskie section (#48): labels created once next to GitHub's defaults, verify detected from package.json and saved as its own commit, sub-issues created with `--parent`. Setup detection had no rules to follow (#54), and two open PRs saved the same setting (#53, fixed in 0.10.3: a value another unmerged run saves is reused) |
| `Read(/${CLAUDE_PLUGIN_ROOT}/**)` in a skill's allowed-tools covers an installed copy as it does a `--plugin-dir` one | all | confirmed for `--plugin-dir` (#57), including on the next turn of a resumed session; to check for the installed copy once 0.10.1 is installed. A plain "work on #12" request reads `do`'s file with no skill active and gets no pre-approval (#63) |
| `/taskie:plan` works on real issues | 4 | confirmed in the #48 trial: a split into two sub-issues with the parent turned into a tracker, and a refine that added a missing edge case |
| `do`'s fail-first rule and spec-based Verification work on real code | 5 | confirmed in the #48 trial: the reproducing tests failed before the fix, and each PR listed every criterion and edge case with its test. A base merge left Verification stale (#55) |

## Out of scope for v1

Backports and maintained release branches, the incident fast lane, CI failure
intake, area labels, cross-repo boards, parallel review loops, non-GitHub
backends, and a behavioral eval suite (tried in #50, removed in #68).
