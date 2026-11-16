# taskie

A Claude Code plugin that runs a ticket-to-code lifecycle on GitHub through
five commands, one skill each. It is written almost entirely in markdown:
skills, shared conventions and a backend mapping. The design is in
[docs/design.md](docs/design.md).

## Docs and what each is for

| File | Audience | Purpose |
|---|---|---|
| `README.md` | users | what taskie does, install, commands, `.taskie.md`, labels |
| `docs/design.md` | contributors | the current design and the reasons behind it, build plan, assumptions to verify |
| `.claude/CLAUDE.md` | contributors and Claude | how to work in this repo (not at the root: a root CLAUDE.md fails `validate --strict`) |
| `shared/conventions.md` | the skills | default rules every stage follows |
| `backends/github.md` | the skills | the only file that maps actions to `gh` commands |
| `.taskie.md` | taskie, working on this repo | this repo's verify command and its version-bump rule |
| `.claude/settings.json` | Claude Code | loads taskie in this repo from its GitHub marketplace |

Keep them in sync with the code. A change to behavior updates `docs/design.md`
and, if user-visible, `README.md` in the same commit.

## Workflow

This repo uses taskie on itself. Every change goes through it, in order:
`/taskie:new`, `/taskie:plan #<n>` when an issue is not ready,
`/taskie:do <n>`, and `/taskie:ship <pr>` only after the maintainer approves.
Never commit on `main` directly. The base branch is `main`.

The plugin that sessions here load is the released copy from GitHub, declared
in `.claude/settings.json`. A change reaches your sessions once its PR is
merged with a version bump (see `.taskie.md`) and the plugin updates: it
auto-updates, or run `claude plugin update taskie@taskie`, then
`/reload-plugins`. To try an unmerged change, start a session with
`claude --plugin-dir .worktrees/issue-<n>`, which takes precedence over the
installed copy.

Labels in use: taskie's set (see `shared/conventions.md`), plus GitHub's
`good first issue` and `help wanted`.

## Verify

Run `just verify` (`claude plugin validate --strict .`) before and after every
change; each commit must pass it. `just submit-check` adds the plugin
directory's submission checks and fails until the plugin has a listing icon.

## Rules for skill files

- Every skill reads `${CLAUDE_PLUGIN_ROOT}/shared/conventions.md` first and
  follows its Precedence section, the one place the read order is written
  down. Do not repeat the order in a skill.
- Skills describe actions in backend-neutral verbs. Only `backends/github.md`
  names `gh` commands. The one exception is `allowed-tools` frontmatter, which
  may pre-approve read-only `gh` commands (never `gh api graphql`, which can
  also mutate).
- `do` and `ship` set `disable-model-invocation: true`.
- Keep each `SKILL.md` under 500 lines.
