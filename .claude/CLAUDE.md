# taskie

A Claude Code plugin that runs a ticket-to-code lifecycle on GitHub through
five commands, one skill each. It is written almost entirely in markdown:
skills, shared conventions and a backend mapping. The design is in
[docs/design.md](docs/design.md).

## Docs and what each is for

| File | Audience | Purpose |
|---|---|---|
| `README.md` | users | what taskie does, install, commands, the `taskie` CLAUDE.md section, labels |
| `docs/design.md` | contributors | the current design and the reasons behind it, build plan, assumptions to verify |
| `docs/milestones.md` | contributors, maintainer | each completed milestone: goal, what shipped, decisions, what was left |
| `.claude/CLAUDE.md` | contributors, Claude and taskie | how to work in this repo, and its taskie section: verify command and version-bump rule (not at the root: a root CLAUDE.md fails `validate --strict`) |
| `shared/conventions.md` | the skills | default rules every stage follows |
| `backends/github.md` | the skills | the only file that maps actions to `gh` commands |
| `.claude/settings.json` | Claude Code | loads taskie in this repo from its GitHub marketplace |
| `.github/CONTRIBUTING.md` | outside contributors | how to file issues and open pull requests here; links `.claude/CLAUDE.md` and `docs/design.md` instead of repeating them |
| `.github/CODE_OF_CONDUCT.md` | everyone taking part | Contributor Covenant 2.1, reports through GitHub private reporting |
| `.github/SECURITY.md` | reporters | how to report a vulnerability privately, supported versions |
| `.github/ISSUE_TEMPLATE/` | reporters | bug and feature templates whose headings are the first sections of taskie's issue templates in `shared/conventions.md`; triage keeps them and adds the rest |
| `.github/pull_request_template.md` | contributors | the pull request body from `shared/conventions.md`, for PRs opened by hand |

Keep them in sync with the code. A change to behavior updates `docs/design.md`
and, if user-visible, `README.md` in the same commit.

## Workflow

This repo uses taskie on itself. Every change goes through it, in order:
`/taskie:new`, `/taskie:plan #<n>` when an issue is not ready,
`/taskie:do <n>`, and `/taskie:ship <pr>` only after the maintainer approves.
Never commit on `main` directly. The base branch is `main`.

The plugin that sessions here load is the released copy from GitHub, declared
in `.claude/settings.json`. A change reaches your sessions once its PR is
merged with a version bump (see the taskie section) and the plugin updates: it
auto-updates, or run `claude plugin update taskie@taskie`, then
`/reload-plugins`. To try an unmerged change, start a session with
`claude --plugin-dir .worktrees/issue-<n>`, which takes precedence over the
installed copy.

Labels in use: taskie's set (see `shared/conventions.md`), plus GitHub's
`good first issue` and `help wanted`.

## Verify

Run `just verify` before and after every change; each commit must pass it. It
runs `claude plugin validate --strict .`, then `just skill-rules`, which fails
when a skill's `allowed-tools` lacks the `Read(/${CLAUDE_PLUGIN_ROOT}/**)` rule,
then `just version-bump`, which fails
when the working tree (untracked files included) changes `skills/`,
`shared/`, `backends/` or `.claude-plugin/` against `main` on the remote that
points at this repo, but `plugin.json`'s version is not higher than the one
there. That catches a forgotten bump, and two branches that bumped to the same
number: after one merges, the other fails until it bumps again (fetch first,
so that `main` is current). `just submit-check`
adds the plugin directory's submission checks and fails until the plugin has a
listing icon.

## taskie

verify: just verify
setup: none

Testing taskie's own issues is shallow on purpose: `just verify` plus reading
the changed skill text against the issue's acceptance criteria and edge
cases, recorded as named checks in the PR. Do not run taskie headless
(`claude -p`) or against another repo to test a change here; each run is a
full Claude session and the cost outweighs what it catches for a markdown
plugin. This overrides do's default only for this repo: the testing rules
for users' projects stay as they are.

The one exception is `just eval`, the behavioral checks in `evals/cases/`:
each case runs a taskie stage headless against a fresh clone of `EVAL_REPO`
(default this repo), with every GitHub write disallowed, and the run fails if
the repo changed. One pass cost $1.32 (`EVAL_RUNS`, default 1 per case;
`EVAL_BUDGET`, default $1.00 per run). Run it only before a release, after
changing `allowed-tools`, permissions or the "before any stage" check,
after upgrading Claude Code, and when taskie behaves oddly; never per PR.

Every pull request that changes what the plugin does (skills,
`shared/conventions.md`, `backends/`, manifests) bumps `version` in
`.claude-plugin/plugin.json`. The first such PR in a milestone bumps the
minor version, which starts that milestone's version; every later one in the
same milestone bumps the patch, fix or feature. Installed copies, including
the one this repo loads on itself, update only when the version changes, so
users get each change at merge, not at the release. Changes to docs alone do
not bump it.

Milestones and releases: each milestone is one minor version, titled
`v0.<minor>`, with a one-sentence goal as its description. One milestone,
the next version, stays open; every issue filed or planned either joins it
or stays in the backlog with no milestone, since an issue outside a
milestone never brings a release closer. An urgent fix joins the open
milestone and reaches users through its patch bump. When `/taskie:ship`
empties the milestone and offers the release, run `just eval` first, then
accept the `v0.<minor>` tag on `main` and record the milestone in
`docs/milestones.md`.

## Rules for skill files

- Every skill reads `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and
  follows its Precedence section, the one place the read order is written
  down. Do not repeat the order in a skill.
- Skills describe actions in backend-neutral verbs. Only `backends/github.md`
  names `gh` commands. The one exception is `allowed-tools` frontmatter, which
  may pre-approve read-only `gh` commands (never `gh api graphql`, which can
  also mutate).
- Every skill's `allowed-tools` starts with `Read(/${CLAUDE_PLUGIN_ROOT}/**)`,
  so it can read taskie's shared files in any repo without a prompt. Keep
  the leading `/`: the expanded path is absolute, and a permission rule
  needs `//` for an absolute path.
- `do` and `ship` set `disable-model-invocation: true`.
- Keep each `SKILL.md` under 500 lines.
