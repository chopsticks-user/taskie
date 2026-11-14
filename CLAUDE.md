# taskie

A Claude Code plugin that runs a ticket-to-code lifecycle on GitHub through one
skill per stage. It is written almost entirely in markdown: skills, shared
conventions and a backend mapping. The design is in
[docs/design.md](docs/design.md).

## Docs and what each is for

| File | Audience | Purpose |
|---|---|---|
| `README.md` | users | what taskie does, install, commands, `.taskie.md`, labels |
| `docs/design.md` | contributors | the current design and the reasons behind it, build plan, assumptions to verify |
| `CLAUDE.md` | contributors and Claude | how to work in this repo |
| `conventions.md` | the skills | default rules every stage follows (planned) |
| `backends/github.md` | the skills | the only file that maps actions to `gh` commands (planned) |

Keep them in sync with the code. A change to behavior updates `docs/design.md`
and, if user-visible, `README.md` in the same commit.

## Workflow

For now, commit directly and locally on `main`. No issues, branches or pull
requests until the repo has a GitHub remote. Keep commits small, one logical
change each, and follow the build plan in `docs/design.md`.

## Verify

`just verify` will run `claude plugin validate --strict --profile directory .`.
It arrives with the plugin manifest in Stage 0, so until then there is no
verify command.

## Rules for skill files

- Every stage skill reads `${CLAUDE_PLUGIN_ROOT}/conventions.md`, then
  `${CLAUDE_PLUGIN_ROOT}/backends/github.md`, then the target repo's
  `.taskie.md` if present. The repo file wins on conflicts.
- Skills describe actions in backend-neutral verbs. Only `backends/github.md`
  names `gh` commands.
- `work`, `review` and `ship` set `disable-model-invocation: true`.
- Keep each `SKILL.md` under 500 lines.
