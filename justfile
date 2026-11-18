# Validate manifests and skills (fails on warnings), then check the version bump
verify: && version-bump
    claude plugin validate --strict .

# Fail when plugin files differ from origin/main but plugin.json is not newer:
# installed copies only update when the version rises, and two branches that
# bump to the same number would otherwise merge one after another unnoticed.
version-bump:
    #!/usr/bin/env bash
    set -euo pipefail
    base=origin/main
    if ! git rev-parse -q --verify "$base^{commit}" >/dev/null; then
        echo "version-bump: no $base to compare with, skipped"
        exit 0
    fi
    # Working tree against the branch point, so uncommitted changes count too.
    fork=$(git merge-base "$base" HEAD)
    if [ -z "$(git diff --name-only "$fork" -- skills shared backends .claude-plugin)" ]; then
        exit 0
    fi
    version() { sed -n 's/.*"version": *"\([^"]*\)".*/\1/p'; }
    old=$(git show "$base:.claude-plugin/plugin.json" | version)
    new=$(version < .claude-plugin/plugin.json)
    newest=$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -n 1)
    if [ "$new" = "$old" ] || [ "$newest" != "$new" ]; then
        echo "version-bump: plugin files changed, but plugin.json is $new, not above $old on $base"
        exit 1
    fi

# Extra checks the plugin directory runs at submission (needs an icon first)
submit-check:
    claude plugin validate --strict --profile directory .
