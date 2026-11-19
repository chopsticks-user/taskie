# Validate manifests and skills (fails on warnings), then check the skill rules and the version bump
verify: && skill-rules version-bump
    claude plugin validate --strict .

# Fail when a skill's allowed-tools does not start with the plugin-root Read
# rule: without it, the skill prompts for its own shared files outside this repo.
skill-rules:
    #!/usr/bin/env bash
    set -euo pipefail
    rule='allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**) '
    missing=0
    for f in skills/*/SKILL.md; do
        grep -qF -- "$rule" "$f" || { echo "skill-rules: $f: allowed-tools must start with $rule" >&2; missing=1; }
    done
    exit "$missing"

# Fail when plugin files differ from main but plugin.json is not newer:
# installed copies only update when the version rises, and two branches that
# bump to the same number would otherwise merge one after another unnoticed.
version-bump:
    #!/usr/bin/env bash
    set -euo pipefail
    fail() { echo "version-bump: $*" >&2; exit 1; }
    # The remote that points at this repo on GitHub, which is not always origin.
    remote=$(git remote -v | awk 'tolower($2) ~ /[\/:]chopsticks-user\/taskie(\.git)?$/ && $3 == "(fetch)" { print $1; exit }')
    [ -n "$remote" ] || fail "no git remote points at chopsticks-user/taskie"
    base="$remote/main"
    git rev-parse -q --verify "$base^{commit}" >/dev/null || fail "no $base; run: git fetch $remote main"
    fork=$(git merge-base "$base" HEAD) || fail "no common history with $base (shallow clone?)"
    paths=(skills shared backends .claude-plugin)
    # Working tree against the branch point: uncommitted and untracked files count.
    changed=$(git diff --name-only "$fork" -- "${paths[@]}"; git ls-files --others --exclude-standard -- "${paths[@]}")
    [ -n "$changed" ] || exit 0
    # First "version" key only, quitting sed there (no head, which pipefail would trip on).
    version() { sed -n '/"version"[[:space:]]*:/ { s/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; q; }'; }
    old=$(git show "$base:.claude-plugin/plugin.json" | version) || fail "no .claude-plugin/plugin.json on $base"
    new=$(version < .claude-plugin/plugin.json)
    [ -n "$old" ] && [ -n "$new" ] || fail "cannot read the version in .claude-plugin/plugin.json"
    newest=$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -n 1)
    if [ "$new" = "$old" ] || [ "$newest" != "$new" ]; then
        fail "plugin files changed, but plugin.json is $new, not above $old on $base"
    fi

# Extra checks the plugin directory runs at submission (needs an icon first)
submit-check:
    claude plugin validate --strict --profile directory .

# Behavioral checks: run taskie stages headless against the sandbox repo, with
# every GitHub write disallowed. Costs model usage, so it is not part of verify.
# Pass case names to run only those; EVAL_RUNS and EVAL_BUDGET tune it.
eval *cases:
    evals/run.sh {{cases}}
