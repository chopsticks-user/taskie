---
name: intake
description: Turn a request, bug report or list of review findings into issues in the current repo, showing the drafts for confirmation before creating anything. Use when the user asks to file, open, create or track an issue, says something should be tracked or is a bug to record, or another taskie stage hands over problems to file.
argument-hint: "<request, bug report or findings>"
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh label list *)
---

# taskie intake

Read `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS

If the input is empty, use what the conversation was just about (for example
"file that as a bug" after discussing a problem). If it is still unclear what
to file, ask.

## Steps

1. Run the "before any stage" check from the conventions.
2. Work out what kind of source the input is and read the matching section
   below. Input can mix kinds; handle each part with its section.
3. Split the input into items, one per unrelated problem. Two things are
   related if one change would resolve both. Do not break a single feature
   into subtasks; that is `/taskie:plan`'s job.
4. For each item, search for duplicates with two to four distinctive keywords,
   in open and closed issues.
   - An open issue that looks like the same problem: show it, and ask whether
     to add the new details to it as a comment, file anyway, or skip.
   - A closed issue that matches: file anyway, and mention it under Context
     (or Problem, for a bug) as a possible regression.
5. Draft each issue:
   - title: the problem or the outcome, specific, under 70 characters, no
     prefix such as "Bug:" (the label says that)
   - labels: one `type:*` label and `needs-triage`; no priority, which is
     triage's call
   - body: the bug template for `type:bug`, the general template otherwise,
     from the conventions. Fill only what the source says; write "Unknown"
     for the rest. The acceptance criteria are a draft that plan will
     finalize.
   - Source section: where the item came from
6. Show every draft in one message, numbered, each with its title, labels and
   full body. Ask the user to confirm, edit or drop each one. Create nothing
   until they answer. This holds even when another stage or Claude itself
   started intake.
7. For the confirmed drafts: make sure the labels exist, create the issues,
   and post any agreed comments on existing issues. Print each result as
   `#<n> <title> <url>`.

## Source: chat request

A request written by the user, such as "add dark mode" or "the login page is
slow". Keep the user's intent and wording where it is specific; do not add
requirements they did not ask for. Pick the type from what is asked: broken
behavior is a bug, new behavior a feature, maintenance a chore,
documentation-only work docs. For a bug described in chat, fill the bug
template's sections only from what the user said.

## Source: bug report or stack trace

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

## Source: review findings

A list of code-review findings, usually the out-of-scope ones that
`/taskie:review` hands over, or `/code-review` output the user pastes. Each
finding normally becomes one issue; merge two findings only when one change
would fix both.

- Type: `type:bug` for a correctness or security problem, `type:chore` for
  simplification, reuse or efficiency, `type:docs` for documentation.
- Problem: the finding in one or two sentences.
- For a bug, Actual is the failure scenario the reviewer gave (concrete input
  or state, and the wrong result); Steps to reproduce are "Unknown" unless the
  finding gives them.
- Context (or Actual, for a bug): the location as `path:line`, and the
  reviewer's severity or confidence if given, so triage can use it.
- Acceptance criteria: at least "the failure scenario no longer happens" for a
  bug, or the concrete cleanup for a chore.
- Source: `Review of PR #<n>` with the PR's URL when known.

When another stage hands over findings, it has already told the user about
them; still show the drafts and wait for confirmation.
