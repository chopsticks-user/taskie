---
name: new
description: File and triage issues in the current repo in one approval. Given a request, bug report or review findings, or asked to look for work in a named scope (code, docs, recent commits, stated goals), it drafts issues already typed, prioritized and with acceptance criteria; given nothing or an issue number, it triages untriaged issues. Use when the user asks to file, open, create, track or triage an issue, says something is a bug to record, asks taskie to find issues to file in a named part of the repo (not a plain review or fix), or another taskie stage hands over problems to file.
argument-hint: "[<request, bug report, findings or a scope to search> | #n]"
allowed-tools: Bash(gh --version*) Bash(git --version*) Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh issue develop --list *) Bash(gh pr list *) Bash(gh label list *)
---

# taskie new

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and follow its
Precedence section, which says what else to read.

Input: $ARGUMENTS

Every triage comment this skill posts (the comment on a created issue, and
each triage outcome's comment) starts with the line `<!-- taskie:triage -->`.
Other comments, such as new details added to an existing issue, never carry
it: the marker is how triage tells that a `needs-info` reporter answered.

## Pick the mode

First run the "before any stage" check from the conventions. Then:

- Input is exactly `#<n>`: triage that issue ("Triage" below), whatever its
  labels.
- Input is empty: triage the open issues whose status is needs triage,
  derived as the conventions describe (an open PR or a linked branch comes
  before labels, so fetch those too), plus every open `needs-info` issue that
  has a comment newer than its latest `<!-- taskie:triage -->` comment (the
  reporter answered). Take at most 10, the answered `needs-info` issues
  first, then the rest oldest first, and if more qualify, say how many are
  left for the next run. If nothing is selected, say so and stop.
- Anything else, including text that starts with a number or `#<n>`: file it
  ("File" below). When Claude starts this skill from a conversation (for
  example "file that as a bug"), it passes the problem as text.

## File

1. Work out what kind of source the input is and read the matching section
   under "Sources". Input can mix kinds; handle each part with its section.
2. Split the input into items, one per unrelated problem. Two things are
   related if one change would resolve both. Do not break a single feature
   into subtasks; that is `/taskie:plan`'s job.
3. For each item, search for duplicates with two to four distinctive keywords,
   in open and closed issues.
   - An open issue that looks like the same problem: show it, and ask whether
     to add the new details to it as a comment, file anyway, or skip.
   - A closed issue that matches: file anyway, and mention it under Context
     (or Problem, for a bug) as a possible regression.
4. Read the code each item touches: search the repo with two or three terms
   from it (names, error messages, routes, UI text) and note up to three
   files that most likely need to change, or "none found". Note how the
   change fits there: what calls or depends on that code and must keep
   working. Read code only; do not run anything (a find-work request may
   read a commit log, see below).
5. Ask the user, in one message, about anything ambiguous whose answer would
   change the scope or the acceptance criteria, including what done looks
   like when the source does not say. Skip this when nothing is ambiguous,
   and never ask for details the source cannot have (for a report written by
   someone else, write "Unknown" instead). Every other guess goes under the
   draft's Assumptions; in autonomous mode, so do these questions' answers
   (see the conventions).
6. Draft each issue:
   - title: the problem or the outcome, specific, under 70 characters, no
     prefix such as "Bug:" (the label says that)
   - body: the bug template for `type:bug`, the general template otherwise,
     from the conventions. Fill the problem's sections only from what the
     source and the user's answers say; write "Unknown" for the rest. List
     dependencies as `Depends on #<n>`, and, in Context (or Problem, for a
     bug), how the change fits the code from step 4.
   - Out of scope, Edge cases and Assumptions: drafted from the request and
     the code read in step 4, as the conventions describe. An expected
     outcome for an edge case that the source does not give is a guess, so
     it is also listed under Assumptions.
   - acceptance criteria: final, each item one observable outcome that can be
     checked by reading the code or running something
   - Source section: where the item came from
   - triage: one `type:*` label, a priority from the conventions (weigh how
     many people are affected, whether a workaround exists, and any severity
     a reviewer gave), the likely files, and an outcome: `ready` if the draft
     meets every point of the definition of ready, otherwise `backlog` with
     the point that fails (an item too big for one pull request is filed
     as backlog for `/taskie:plan #<n>` to split)
7. Show every draft in one message, numbered, each with its title, labels,
   outcome and full body. Then ask which drafts to create, as a batch (see
   "Asking the user" in the conventions). Create nothing until they answer.
   This holds even when another stage or Claude itself started this skill.
8. For the confirmed drafts: make sure the labels exist, create each issue
   with its type and priority labels (plus `ready` when that is the
   outcome), post any agreed comments on existing issues, and post the
   Accept outcome's triage comment (under "Outcomes") on each new issue.

9. Print each result as `#<n> <title> <url>` with its status, and suggest
   `/taskie:do <n>` for a ready issue or `/taskie:plan #<n>` for one in the
   backlog.

## Triage

For issues that already exist, usually filed by someone outside taskie.

1. For each selected issue, read its body and comments, then:
   - Type: keep the `type:*` label if it fits, otherwise propose the right
     one.
   - Priority: pick `P0` to `P3` as in "File" step 6.
   - Likely files: as in "File" step 4.
   - Outcome: one of the outcomes below.
2. Show one table with numbered rows, then ask which rows to apply, as a
   batch (see "Asking the user" in the conventions):

   ```
   | # | Issue | Type | Priority | Outcome | Reason | Likely files |
   ```

   Change nothing on the backend before they answer, and apply their edits.
   If the user's answer settles a question of scope or acceptance criteria,
   write it into the issue's body (keeping the template) when applying the
   row, and re-check the definition of ready with it. Below the table, show
   the body sections any Ready row would add (see "Outcomes").
3. Apply each approved row as its outcome describes. Make sure every label
   exists before adding it.
4. Print one line per issue with what was done, then suggest the next
   command: `/taskie:do <n>` for a ready issue, `/taskie:plan #<n>` for one
   in the backlog.

### Outcomes

Accept: the issue is valid and understood. Set the type label (removing a
wrong one), add the priority label, remove `needs-info`, and comment:

```
<!-- taskie:triage -->
Triaged: <type>, <priority>. <reason>

Likely files: <files, or "none found">
```

Ready: the issue already meets the definition of ready in the conventions
(for example a small bug with clear acceptance criteria). Do everything
Accept does and also add `ready`. Propose this only when every point of the
definition holds; otherwise Accept and leave it for `/taskie:plan`. An
issue filed outside taskie usually lacks the Out of scope, Edge cases and
Assumptions sections; it can still be Ready when the rest holds and those
sections can be drafted from the issue and the code as in "File" step 6.
Show them below the table, and on approval add them to the body (keeping
the existing text and the template's section order).

Duplicate: another issue, open or closed, describes the same problem. Search
for it as in "File" step 3 and name it in the Reason column. If the duplicate
has details the original lacks, add them to the original as a comment. Then
close the duplicate as a duplicate of the original.

Needs info: the issue cannot be classified or acted on without answers from
the reporter. Add `needs-info` and comment with specific, numbered questions
(for example "Which browser and version?", "Does it happen with an empty table
too?"), never a generic "please add more details":

```
<!-- taskie:triage -->
Thanks for the report. To triage this we need:

1. ...
2. ...
```

The issue comes back to triage once someone comments after this.

Won't fix: the request is out of the project's scope (judged from the README
and the repo's CLAUDE.md files), or the behavior is intended. Propose it only
with a concrete reason. Comment with the reason, starting with the triage
marker, then close the issue as not planned.

Closing is visible to the reporter, so put every Duplicate and Won't fix in
the table like any other outcome; the user's approval of the table covers
them.

## Sources

### Chat request

A request written by the user, such as "add dark mode" or "the login page is
slow". Keep the user's intent and wording where it is specific; do not add
requirements they did not ask for. Pick the type from what is asked: broken
behavior is a bug, new behavior a feature, maintenance a chore,
documentation-only work docs. For a bug described in chat, fill the bug
template's sections only from what the user said.

### Bug report or stack trace

Pasted error output, a log excerpt, or a report written by someone else (a
user, a support ticket). Always `type:bug`.

- Problem: what fails and who is affected, in one or two sentences.
- Steps to reproduce: only steps the report gives or that follow directly
  from it. If there are none, write "Unknown".
- Expected and Actual: the report's words; for a stack trace, Actual is the
  exception type and message.
- Environment: versions, OS, browser, configuration if stated.
- Failing location: for a stack trace, find the innermost frame that is in
  this repo's code (skip library and runtime frames) and check that the file
  exists. Add it under Actual as `path:line`. Put a trimmed excerpt of the
  trace (the exception line and the frames from this repo) in a fenced code
  block under Actual; never paste a whole log.
- Remove secrets, tokens, passwords, email addresses and other personal data
  from anything copied into the issue, replacing them with `<redacted>`.

### Review findings

A list of code-review findings, usually the out-of-scope ones another taskie
stage hands over, or `/code-review` output the user pastes. Each finding
normally becomes one issue; merge two findings only when one change would fix
both.

- Type: `type:bug` for a correctness or security problem, `type:chore` for
  simplification, reuse or efficiency, `type:docs` for documentation.
- Problem: the finding in one or two sentences.
- For a bug, Actual is the failure scenario the reviewer gave (concrete input
  or state, and the wrong result); Steps to reproduce are "Unknown" unless the
  finding gives them.
- Context (or Actual, for a bug): the location as `path:line`, and the
  reviewer's severity or confidence if given.
- Acceptance criteria: at least "the failure scenario no longer happens" for a
  bug, or the concrete cleanup for a chore.
- Source: `Review of PR #<n>` with the PR's URL when known.

When another stage hands over findings, it has already told the user about
them; still show the drafts and wait for confirmation.

### Find-work request

A request to go and look for work in a named scope, instead of a description
of a problem: "review skills/do for bugs", "what's missing given the goals in
docs/design.md", "look at the last 20 commits for unfinished work". Text that
describes something the writer saw ("review is broken on large PRs") is a
report, not a request. When it could be either, ask, offering both readings
and no recommended option.

The scope is required. If the request names none ("find some bugs"), ask for
one, offering concrete scopes from this repo (its top-level directories, its
main docs, the last 20 commits); review the whole repo only when the user
names it as the scope.

Read the scope directly instead of running another review tool. A large
scope (a long range, a big directory, the whole repo) starts from an
overview, such as file stats or the file list; read the parts that matter
and say which were only skimmed.

- paths: the named files or directories, as code or docs
- a commit range: the log of the range with each commit's diff (running the
  log is the one command this source needs)
- a pull request: its commits and its diff, as the backend reads them
- goals: the named document (a README, a design doc) and the descriptions of
  open milestones, compared with what the code and the open issues already
  cover; a goal that a closed issue declined as not planned is not drafted
  again

Each finding then becomes a draft as in "Review findings" above, with Source
`Find-work request: <the request>`, and goes through the same duplicate
search, batch and approval as every other draft. Unfinished new behavior,
such as a stub left for later, is a `type:feature`. A draft derived from
goals, rather than a defect found in code or docs, is a guess at what the
maintainers want: it is typed by what is missing and filed to the backlog for
`/taskie:plan`, never `ready`.
