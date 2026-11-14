---
name: triage
description: Triage issues in the current repo by proposing a type, priority and outcome for each untriaged issue in one table, then applying them after the user approves. Use when the user asks to triage, prioritize or sort through new issues.
argument-hint: "[#n]"
allowed-tools: Bash(gh auth status*) Bash(gh repo view *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh label list *)
---

# taskie triage

Read `${CLAUDE_PLUGIN_ROOT}/conventions.md`, then
`${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then `.taskie.md` at the repo root
if it exists.

Input: $ARGUMENTS

Every comment triage posts starts with the line `<!-- taskie:triage -->`.

## Steps

1. Run the "before any stage" check from the conventions.
2. Select issues:
   - with `#<n>`: that issue, whatever its labels
   - with no argument: every open `needs-triage` issue, plus every open
     `needs-info` issue that has a comment newer than its latest
     `<!-- taskie:triage -->` comment (the reporter answered)

   If nothing is selected, say so and stop.
3. For each issue, read its body and comments, then:
   - Type: keep the `type:*` label if it fits, otherwise propose the right
     one.
   - Priority: pick `P0` to `P3` from the definitions in the conventions.
     Weigh how many people are affected (count linked reports and comments),
     whether a workaround exists, and any severity a reviewer gave.
   - Likely files: search the repo with two or three terms from the issue
     (names, error messages, routes, UI text) and note up to three files
     that most likely need to change. Read code only; do not run anything.
     If nothing fits, write "none found".
   - Outcome: one of the outcomes below.
4. Show one table and wait for the user's answer:

   ```
   | # | Issue | Type | Priority | Outcome | Reason | Likely files |
   ```

   The user may approve all rows, or change or drop rows by number. Change
   nothing on the backend before they answer, and apply their edits.
5. Apply each approved row as its outcome describes. Make sure every label
   exists before adding it.
6. Print one line per issue with what was done, then suggest the next
   command: `/taskie:work <n>` for a ready issue, `/taskie:plan #<n>` for one
   in the backlog.

## Outcomes

Accept: the issue is valid and understood. Set the type label (removing a
wrong one), add the priority label, remove `needs-triage` and `needs-info`,
and comment:

```
<!-- taskie:triage -->
Triaged: <type>, <priority>. <reason>

Likely files: <files, or "none found">
```

Ready: the issue already meets the definition of ready in the conventions
(for example a small bug with clear acceptance criteria). Do everything
Accept does and also add `ready`. Propose this only when every point of the
definition holds; otherwise Accept and leave it for `/taskie:plan`.
