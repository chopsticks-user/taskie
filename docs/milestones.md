# Milestones

A record of each completed milestone: what it set out to do, what shipped,
what was decided along the way, and what was left. Newest first. Release
notes, built by `/taskie:ship` from the milestone's issues, list the changes;
this file keeps the reasons.

## v0.10: ready for experimental use in personal projects

Opened 2026-11-18, completed 2026-11-19. Plugin 0.9.0 to 0.10.8.

### Goal

taskie had only ever run on its own repository, a markdown plugin. The
milestone's description: taskie is ready for experimental use in personal
projects. It has been tried end to end outside its own repo, checks its
requirements, has repeatable behavioral tests, and tells a new user what to
expect.

It built on #46 (0.9.0, just before the milestone): issues became small
specs (Out of scope, Edge cases, Assumptions), and `/taskie:do` had to prove
every acceptance criterion and edge case with a test, starting a bug fix with
a test seen failing.

### Outcome

Every goal was met. The README now calls taskie experimental: ready for
personal projects, not yet for work that can't be redone.

- **Tried outside its own repo.** #48 ran the whole lifecycle on a separate
  Node repo with a test suite: filing, triage of an outside report, a split
  and a refine with `/taskie:plan`, fail-first and autonomous `do` runs,
  ship, and a conflict between two pull requests resolved through `do`. The
  trial report is on #48. The sandbox repo was deleted afterwards.
- **Checks its requirements.** Every stage checks the gh version (2.94 or
  later), whether the repo accepts issues, and, for do and ship, git 2.38 or
  later (#49, #60).
- **Behavioral tests.** These were built, removed and rebuilt (see Decisions).
  Now `just eval`, without a sandbox (#77).
- **Tells a new user what to expect.** The README's "Trying taskie on your
  project" section covers what taskie writes, what waits for approval, and
  how to update, remove and clean up (#51, #63).

### Issues

| Issue | Pull request | What changed |
|---|---|---|
| #48 | #56 | End-to-end trial on a separate repo; findings filed as #52 to #55 |
| #49 | #59 | gh, git and issues checks before every stage |
| #50 | #64 | Behavioral eval suite against a sandbox (later removed by #68) |
| #51 | #65 | README section for first-time users |
| #52 | #66 | Triage's Ready outcome fits an outside report into the template, keeping the original verbatim |
| #53 | #67 | do reuses a repo command another of the user's runs is saving; never from a fork |
| #57 | #62 | Skills pre-approve reading taskie's own files in any repo |
| #68 | #69 | Eval suite and sandbox removed; testing of taskie itself kept shallow |
| #54 | #70 | Setup detection only in clear cases (lockfiles at the root), otherwise asked |
| #55 | #71 | do refreshes Verification before its review summary after pushing commits |
| #58 | #72 | Board finds linked branches with pre-approvable commands |
| #60 | #73 | gh minimum lowered from 2.103 to the measured 2.94 |
| #61 | #74 | Ship waits for GitHub's mergeability before merging |
| #63 | #75 | README explains prompts on plain "work on #12" requests |
| #77 | #78 | Behavioral checks back, without a sandbox |
| #76 | this file | Milestone record |

### Decisions

- **The biggest problem was found by running taskie, not by reading it
  (#57).** Outside the taskie repo, every command was denied its own
  `shared/` files. Six variants were tested; only
  `Read(/${CLAUDE_PLUGIN_ROOT}/**)` in each skill's allowed-tools worked.
  The leading `/` matters. `just verify` now enforces the rule.
- **A security hole was caught in review (#53).** Taking a pending `verify:`
  value from any open pull request would have run a stranger's command from
  a fork. Only the user's own same-repo branches count now, and the value is
  confirmed once.
- **Behavioral testing, three times.** `claude plugin eval` could not run
  taskie: its sandbox has no `gh`. A custom runner against a private sandbox
  (#50) caught real bugs, but testing every change headless made token
  usage spike. It was removed (#68). It came back without the sandbox (#77):
  4 state-independent cases, read-only against a clone of this repo, about
  $1.30 a pass. It runs only before a release, after permission or
  before-any-stage changes, after a Claude Code upgrade, or when behavior
  looks wrong. Otherwise, this repo's own issues are checked with `just
  verify` and by reading, as its taskie section says.
- **Prefer narrow rules that ask over broad guesses.** Setup detection (#54)
  and the board's lookup (#58) both started broad and were narrowed in
  review. A wrong guess costs more than a question, since it reads as a
  pre-existing failure.
- **Reviews mattered.** Every pull request was reviewed with `/code-review`.
  Most findings were fixed in the same pull request, and the rest were
  filed (#60, #61, #63) or left with a stated reason in the review summary.

### Left open

- A linked branch whose name is neither `issue-<n>-` nor `<n>-` is not seen
  as in progress (#58).
- The user-level Read rule for plain "work on #12" requests is not verified
  (#63; design.md, "Assumptions to verify").
- `just eval` covers read-only stages only; `do` and `ship` write to GitHub
  and are not exercised.
