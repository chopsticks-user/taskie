#!/usr/bin/env bash
# Behavioral checks for taskie: each case runs a taskie stage headless against a
# fresh clone of a sandbox repo, with every GitHub write disallowed, and checks
# the final message. Usage: evals/run.sh [case...]
#
# EVAL_REPO     sandbox repo (default chopsticks-user/taskie-sandbox)
# EVAL_RUNS     runs per case (default 3); a case passes when a majority pass
# EVAL_BUDGET   cost ceiling in USD per run (default 1.00)
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
repo=${EVAL_REPO:-chopsticks-user/taskie-sandbox}
runs=${EVAL_RUNS:-3}
budget=${EVAL_BUDGET:-1.00}
out="$root/evals/results/$(date -u +%Y-%m-%dT%H-%M-%SZ)"
mkdir -p "$out"

# Everything a stage could change on GitHub, listed so a run that wrote
# anything is caught even if the disallow list missed the command.
snapshot() {
    gh issue list -R "$repo" --state all --limit 500 --json number,state,updatedAt,labels \
        --jq 'sort_by(.number)[] | "issue \(.number) \(.state) \(.updatedAt) \([.labels[].name] | sort | join(","))"'
    gh pr list -R "$repo" --state all --limit 500 --json number,state,updatedAt \
        --jq 'sort_by(.number)[] | "pr \(.number) \(.state) \(.updatedAt)"'
    gh label list -R "$repo" --limit 500 --json name --jq '.[].name' | sort | sed 's/^/label /'
}

# Writes taskie can make through gh or git; none of them may run in a case.
deny=(
    'Bash(gh issue create*)' 'Bash(gh issue edit*)' 'Bash(gh issue comment*)'
    'Bash(gh issue close*)' 'Bash(gh issue develop*)' 'Bash(gh label create*)'
    'Bash(gh pr create*)' 'Bash(gh pr edit*)' 'Bash(gh pr comment*)'
    'Bash(gh pr merge*)' 'Bash(gh release*)' 'Bash(gh api*)' 'Bash(gh repo edit*)'
    'Bash(git push*)' 'Bash(git commit*)' 'Bash(git worktree*)'
)

# Lines in a case's expect file: "contains <ERE>" or "not_contains <ERE>",
# matched case-insensitively against the run's final message.
check() {
    local expect=$1 result=$2 kind pattern ok=0
    while read -r kind pattern; do
        [ -z "$kind" ] || [ "${kind:0:1}" = "#" ] && continue
        case $kind in
            contains) grep -qiE -- "$pattern" "$result" || { echo "    missing: $pattern"; ok=1; } ;;
            not_contains) ! grep -qiE -- "$pattern" "$result" || { echo "    unexpected: $pattern"; ok=1; } ;;
            *) echo "    bad expect line: $kind $pattern"; ok=1 ;;
        esac
    done < "$expect"
    return "$ok"
}

cases=("$@")
[ ${#cases[@]} -gt 0 ] || mapfile -t cases < <(ls "$root/evals/cases")

before=$(snapshot)
failed=0
for name in "${cases[@]}"; do
    dir="$root/evals/cases/$name"
    [ -f "$dir/prompt" ] && [ -f "$dir/expect" ] || { echo "$name: no prompt or expect file"; failed=1; continue; }
    passed=0
    for ((i = 1; i <= runs; i++)); do
        work=$(mktemp -d)
        gh repo clone "$repo" "$work" -- --quiet
        result="$out/$name-$i.txt"
        # Every assistant message counts, not only the last: a stage often shows
        # its draft in one message and asks for approval in the next.
        (cd "$work" && claude -p --plugin-dir "$root" --max-budget-usd "$budget" \
            --output-format stream-json --verbose --allowedTools Skill \
            --disallowedTools "${deny[@]}" -- "$(cat "$dir/prompt")" < /dev/null > "$result.jsonl" 2>"$result.err") || true
        jq -r 'select(.type == "assistant") | .message.content[] | select(.type == "text") | .text' < "$result.jsonl" > "$result" 2>/dev/null || true
        rm -rf "${work:?}"
        if check "$dir/expect" "$result"; then passed=$((passed + 1)); echo "  $name run $i: pass"; else echo "  $name run $i: fail ($result)"; fi
    done
    if ((passed * 2 > runs)); then echo "PASS $name ($passed/$runs)"; else echo "FAIL $name ($passed/$runs)"; failed=1; fi
done

after=$(snapshot)
if [ "$before" != "$after" ]; then
    echo "FAIL: the sandbox changed during the run:"
    diff <(echo "$before") <(echo "$after") || true
    failed=1
fi
echo "results: $out"
exit "$failed"
