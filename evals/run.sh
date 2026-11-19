#!/usr/bin/env bash
# Behavioral checks for taskie: each case runs a taskie stage headless against a
# fresh clone of a sandbox repo, with GitHub writes disallowed, and checks every
# assistant message of the run. Usage: evals/run.sh [case...]
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

work=""
cleanup() { [ -z "$work" ] || rm -rf "${work:?}"; }
trap cleanup EXIT

# Everything a stage could change on GitHub, so a run that wrote anything is
# caught even if the disallow list below missed the command. Each listing
# must succeed: a partial snapshot would hide a change or invent one.
snapshot() {
    gh issue list -R "$repo" --state all --limit 500 --json number,state,updatedAt,labels,milestone \
        --jq 'sort_by(.number)[] | "issue \(.number) \(.state) \(.updatedAt) \([.labels[].name] | sort | join(",")) \(.milestone.title // "")"' || return 1
    gh pr list -R "$repo" --state all --limit 500 --json number,state,updatedAt \
        --jq 'sort_by(.number)[] | "pr \(.number) \(.state) \(.updatedAt)"' || return 1
    gh label list -R "$repo" --limit 500 --json name,color,description \
        --jq 'sort_by(.name)[] | "label \(.name) \(.color) \(.description)"' || return 1
    gh api "repos/$repo/milestones?state=all&per_page=100" \
        --jq 'sort_by(.number)[] | "milestone \(.number) \(.state) \(.updated_at)"' || return 1
    gh api "repos/$repo/branches?per_page=100" --jq 'sort_by(.name)[] | "branch \(.name) \(.commit.sha)"' || return 1
}
take_snapshot() { snapshot > "$1" || { echo "could not read the sandbox's state; stopping" >&2; exit 2; }; }

# Writes taskie could make; none of them may run in a case. Read-only commands
# a skill pre-approves (gh issue develop --list) are left alone on purpose.
# `gh api` stays denied: no skill pre-approves it, since it can also write.
deny=(
    'Bash(gh issue create*)' 'Bash(gh issue edit*)' 'Bash(gh issue comment*)'
    'Bash(gh issue close*)' 'Bash(gh issue reopen*)' 'Bash(gh issue delete*)'
    'Bash(gh issue transfer*)' 'Bash(gh issue lock*)' 'Bash(gh issue unlock*)'
    'Bash(gh issue pin*)' 'Bash(gh issue unpin*)'
    'Bash(gh label create*)' 'Bash(gh label edit*)' 'Bash(gh label delete*)' 'Bash(gh label clone*)'
    'Bash(gh pr create*)' 'Bash(gh pr edit*)' 'Bash(gh pr comment*)' 'Bash(gh pr merge*)'
    'Bash(gh pr close*)' 'Bash(gh pr reopen*)' 'Bash(gh pr review*)' 'Bash(gh pr ready*)'
    'Bash(gh release*)' 'Bash(gh api*)' 'Bash(gh repo edit*)' 'Bash(gh repo delete*)'
    'Bash(gh workflow*)' 'Bash(git push*)'
)

# Lines in a case's expect file: "contains <ERE>" or "not_contains <ERE>",
# matched case-insensitively, line by line, against every assistant message.
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

run_case() {
    local dir=$1 result=$2
    work=$(mktemp -d)
    if ! gh repo clone "$repo" "$work" -- --quiet 2> "$result.err"; then
        echo "    could not clone $repo"; cleanup; work=""; return 1
    fi
    # User settings, plugins, hooks and MCP servers stay out, so a run behaves
    # the same on any machine. Every assistant message counts, not only the
    # last: a stage often shows its draft in one message and asks in the next.
    (cd "$work" && claude -p --plugin-dir "$root" --max-budget-usd "$budget" \
        --setting-sources project,local --strict-mcp-config \
        --output-format stream-json --verbose --allowedTools Skill \
        --disallowedTools "${deny[@]}" -- "$(cat "$dir/prompt")" < /dev/null > "$result.jsonl" 2>> "$result.err") || true
    cleanup; work=""
    jq -r 'select(.type == "assistant") | .message.content[] | select(.type == "text") | .text' \
        < "$result.jsonl" > "$result" 2>/dev/null || true
    check "$dir/expect" "$result"
}

cases=("$@")
[ ${#cases[@]} -gt 0 ] || mapfile -t cases < <(ls "$root/evals/cases")

take_snapshot "$out/before.txt"
failed=0
for name in "${cases[@]}"; do
    dir="$root/evals/cases/$name"
    [ -f "$dir/prompt" ] && [ -f "$dir/expect" ] || { echo "$name: no prompt or expect file"; failed=1; continue; }
    passed=0
    for ((i = 1; i <= runs; i++)); do
        result="$out/$name-$i.txt"
        if run_case "$dir" "$result"; then passed=$((passed + 1)); echo "  $name run $i: pass"; else echo "  $name run $i: fail ($result)"; fi
    done
    if ((passed * 2 > runs)); then echo "PASS $name ($passed/$runs)"; else echo "FAIL $name ($passed/$runs)"; failed=1; fi
done

take_snapshot "$out/after.txt"
if ! diff -q "$out/before.txt" "$out/after.txt" > /dev/null; then
    echo "FAIL: the sandbox changed during the run:"
    diff "$out/before.txt" "$out/after.txt" || true
    failed=1
fi
echo "results: $out"
exit "$failed"
