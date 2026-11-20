# Contributing to taskie

Thanks for helping. taskie is developed with taskie, so issues and pull
requests here follow its lifecycle.

## Issues

Open an issue with the bug or feature template. Fill in the sections you can
and write "Unknown" for the rest; triage (`/taskie:new`) adds the type,
priority, scope, edge cases and acceptance criteria. An issue is ready to
work on once it is labelled `ready`.

Report security problems privately, as [SECURITY.md](SECURITY.md) describes.

## Pull requests

Pick an issue labelled `ready` and say in a comment that you are taking it,
so two people do not work on the same one. Work on a branch named
`issue-<n>-<slug>` and open the pull request against `main` with the pull
request template.

Every commit passes `just verify`. Its version check compares against `main`
on a remote that points at this repo, so in a fork add one first:

```sh
git remote add upstream https://github.com/chopsticks-user/taskie
git fetch upstream main
```

A change to what the plugin does bumps its version.
[.claude/CLAUDE.md](../.claude/CLAUDE.md) explains how to work in this repo,
and [docs/design.md](../docs/design.md) explains the design.

Everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md).
