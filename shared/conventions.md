# taskie conventions

Default rules every taskie stage follows. They are written in
backend-neutral terms; the backend file named under Precedence says how to
carry out each action.

`${CLAUDE_PLUGIN_ROOT}` below is the plugin root: the parent of the `shared/`
directory this file is in. It is not expanded inside this file, so replace it
with that directory's real path yourself; never pass it to a shell as is.

## Precedence

Every taskie skill reads this file first. This section is the only place the
read order is written down. Before doing anything else, also read, in order:

1. `${CLAUDE_PLUGIN_ROOT}/backends/github.md`
2. `.taskie.md` at the root of the target repo, if it exists

`.taskie.md` is free-form markdown written by the repo's maintainers. Where it
says something different from this file, follow `.taskie.md`. Do not ask the
user to create it; it is optional.

## Before any stage

Check that the current directory is inside a git repository whose remote is
hosted on a supported backend, and that the backend CLI is authenticated. If
not, say exactly what is missing and stop.

The base branch is the repo's default branch unless `.taskie.md` names
another.

## Labels

| Label | Meaning |
|---|---|
| `type:bug` | something is broken |
| `type:feature` | new behavior |
| `type:chore` | maintenance: refactors, upgrades, tooling, tech debt |
| `type:docs` | documentation only |
| `P0` | outage, data loss or security hole; drop everything |
| `P1` | major feature broken, no workaround |
| `P2` | degraded, a workaround exists |
| `P3` | minor or cosmetic |
| `needs-triage` | not triaged yet |
| `needs-info` | waiting on answers from the reporter |
| `ready` | meets the definition of ready |

An issue has at most one `type:*` label and at most one priority label. Before
applying a label, make sure it exists, and create only the missing ones (see
the backend). Never recolor or rename labels that already exist.

## Status

Status is derived from backend state, never stored in labels. Evaluate the
rules top to bottom and use the first that matches.

| Status | Rule |
|---|---|
| done | the issue is closed |
| awaiting approval | an open PR closes the issue and its latest review marker records the PR's current head commit |
| in review | an open PR closes the issue |
| in progress | the issue has a linked branch |
| needs info | labelled `needs-info` |
| needs triage | labelled `needs-triage` |
| ready | labelled `ready` |
| backlog | anything else that is open |

A tracker is an issue that has sub-issues. It is never `ready` and is never
worked on directly; its sub-issues are.

## Review marker

`/taskie:do` ends its review with one summary comment on the PR. Its first
line is

```
<!-- taskie:review sha=<full head commit sha that was reviewed> -->
```

Only the most recent comment with this marker counts. Any new commit on the PR
makes the marker stale, so the PR goes back to "in review" until it is
reviewed again. The one exception is checked by `/taskie:ship` with local git:
if every commit after the marker that is not on the base branch is a merge (in
practice ship's own merge of the base branch, which also brings in the base's
commits), the review still stands for shipping.

## Definition of ready

An issue is ready when all of these hold:

- it has an acceptance-criteria checklist (see below), and every item is
  checkable by reading the code or running something
- its scope is clear: someone new to the issue would know what to change and
  what to leave alone
- its dependencies are known and none of them is open and blocking
- it fits in one reviewable pull request
- it is not a tracker

## Issue bodies

Every issue body uses one of these templates. Keep section headings exactly as
written so later stages can find them. Write "Unknown" for anything the source
does not say; never invent details.

Bug:

```markdown
## Problem
<one or two sentences: what is broken, for whom>

## Steps to reproduce
1. ...

## Expected
...

## Actual
...

## Environment
<versions, OS, browser, config; or Unknown>

## Acceptance criteria
- [ ] ...

## Source
<where this came from: chat, bug report, review of #<pr>, ...>
```

Everything else (feature, chore, docs):

```markdown
## Problem
<what is missing or wrong, and why it matters>

## Context
<relevant background, constraints, links>

## Acceptance criteria
- [ ] ...

## Source
<where this came from>
```

Acceptance criteria are a markdown checklist. Each item states one observable
outcome, for example "Exporting with an empty table shows 'Nothing to export'
instead of an error". `/taskie:new` writes them final when it files an issue;
`/taskie:plan` finalizes them for issues that are not ready yet.

## Repo commands

Two commands come from the target repo:

| Name | Purpose |
|---|---|
| `verify` | formatting, linting and all tests in one command |
| `setup` | prepares a fresh checkout or worktree, such as installing dependencies |

Find each one in this order:

1. a `verify:` or `setup:` line in `.taskie.md`
2. detect it from the repo: a `verify`, `check` or `test` recipe in a
   `justfile` or `Makefile`, a `test` script in `package.json`, `cargo test`
   for a Cargo project, and so on
3. ask the user

When a command was detected or given by the user, confirm it once, then offer
to save it to `.taskie.md` (creating the file if needed). If a repo needs no
setup, record `setup: none`.

## Branches

Name the branch for issue `<n>` as `issue-<n>-<slug>`, where the slug is two to
five lowercase words from the title joined by hyphens, at most 40 characters,
for example `issue-12-export-button-safari`.

Each issue is worked on in its own worktree at `.worktrees/issue-<n>` inside
the repo; a PR that resolves no issue uses `.worktrees/pr-<pr>`. Hide
`.worktrees/` from git through the repository's `info/exclude` file, never by
editing the repo's `.gitignore`.

Never commit on the base branch. Never force-push.

## Commits

Keep commits small: one logical change each, and each one passes `verify`.
Match the repo's existing commit message style; if it has none, use a short
imperative subject line and a body that explains why.

## Pull requests

A PR targets the base branch. Its title is the issue title. Its body is:

```markdown
Closes #<n>

## Why
<the problem, in a sentence or two>

## Changes
<what changed, by area>

## Verification
- [x] <acceptance criterion>: <how it was checked>

## Notes
<follow-up issues filed, risks, anything left out and why; or "None">
```

Add one `Closes #<n>` line per issue the PR resolves.

## Approval points

Creating, editing, labelling, commenting on or closing anything on the backend
is visible to other people. Each stage defines where it stops for the user's
approval; do not act on the backend outside those points. When the user
declines or edits a proposal, follow their version.

## Asking the user

Every question a stage asks, and every approval it waits for ("ask",
"confirm", "wait for approval" in any skill, including the approval points
above), is a multiple-choice prompt: in Claude Code, the AskUserQuestion
tool. The user picks an option instead of typing, and the run waits for the
answer, so it never moves on with a question left open. Telling the user to
do something themselves, such as running a command, is not a question and
stays plain text.

- Show long content first, in the message: drafts, tables, diffs and
  summaries. A prompt holds only short labels and descriptions.
- Give each option a one-line description of what happens if it is picked.
  Put the recommended option first and end its label with "(Recommended)",
  but only when there is a reason to prefer it. A question about what a
  reporter meant gets no recommendation; offer the plausible readings.
- For an open value (a tag, a title, a name), offer concrete proposals; the
  user types their own through "Other".
- The prompt adds an "Other" choice for free text by itself; do not add one.
  Every question needs at least two options.
- A batch (drafts, table rows, findings to file): number the items in the
  message. With one item, ask a single-choice question (apply it, or drop
  it). With more than four, first ask "Apply all (Recommended)", "Choose
  items" or "Drop all", and continue only on "Choose items". To choose, use
  multiSelect questions with one option per item, labelled with its number,
  at most 4 options per question and 4 questions per prompt, in rounds past
  16 items. A ticked item is applied; to change one, tick it and describe the
  change in "Other", naming the item's number; an unticked item is dropped.
- Ask everything one decision needs in one prompt, as separate questions; past
  four questions, ask in rounds, most important first.
- If no multiple-choice tool is available, ask the same question as a
  numbered list in text and wait for the user's reply before acting. In a
  non-interactive run, where nobody can reply, change nothing that needs the
  answer: stop and report the open question.

## Unrelated problems

A problem found along the way that is outside the current issue's scope is not
fixed in place. Hand it to `/taskie:new` as a new issue, then continue.
