#!/bin/sh
# Smoke tests: sh tests/run.sh   (exits non-zero on the first failure)
HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/commit-msg"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
t() { # name, input, expected-output
  printf '%s' "$2" > "$T/m"; sh "$HOOK" "$T/m"
  if [ "$(cat "$T/m")" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "--- got:"; cat "$T/m"; fail=1; fi
}
NL='
'
t "plain message untouched"  "fix: thing${NL}${NL}body" "fix: thing${NL}${NL}body"
t "claude trailer"  "fix: x${NL}${NL}Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>${NL}" "fix: x"
t "lowercase tool name"  "fix: x${NL}${NL}co-authored-by: claude <x@y.z>${NL}" "fix: x"
t "devin bot email"  "fix: x${NL}${NL}Co-authored-by: Devin AI <devin-ai-integration[bot]@users.noreply.github.com>${NL}" "fix: x"
t "codebuff"  "fix: x${NL}${NL}Co-Authored-By: Codebuff <noreply@codebuff.com>${NL}" "fix: x"
t "generated with line"  "fix: x${NL}${NL}Generated with [Claude Code](https://claude.com/claude-code)${NL}" "fix: x"
t "robot emoji line"  "fix: x${NL}${NL}🤖 Generated with Codex${NL}" "fix: x"
t "human co-author kept"  "fix: x${NL}${NL}Co-authored-by: Hemanth <hemanth@skylinxglobal.com>${NL}" "fix: x${NL}${NL}Co-authored-by: Hemanth <hemanth@skylinxglobal.com>"
t "own footer kept after strip"  "fix: x${NL}${NL}Co-Authored-By: Claude <noreply@anthropic.com>${NL}Authored-By: Someone Else${NL}" "fix: x${NL}${NL}Authored-By: Someone Else"
t "word claude in body kept"  "fix: claude api timeout${NL}${NL}Claude was slow" "fix: claude api timeout${NL}${NL}Claude was slow"

# allow-list: a human named Devin
mkdir -p "$T/h"; cp "$HOOK" "$T/h/commit-msg"; echo "devin.k@example.com" > "$T/h/allow-coauthors"
printf 'fix: x\n\nCo-authored-by: Devin K <devin.k@example.com>\n' > "$T/m"; sh "$T/h/commit-msg" "$T/m"
if grep -q "Devin K" "$T/m"; then echo "ok   allow-list keeps human Devin"; else echo "FAIL allow-list"; fail=1; fi

# --check mode
printf 'fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$T/m"
sh "$HOOK" --check "$T/m"; [ $? -eq 1 ] && echo "ok   --check flags trailer" || { echo "FAIL --check flag"; fail=1; }
printf 'fix: x\n' > "$T/m"
sh "$HOOK" --check "$T/m"; [ $? -eq 0 ] && echo "ok   --check passes clean" || { echo "FAIL --check clean"; fail=1; }

# real git commit
R="$T/repo"; git init -q "$R"; cd "$R" || exit 1
git config user.email t@t; git config user.name t; git config core.hooksPath "$(dirname "$HOOK")"
echo a > f; git add f
git commit -q -m "feat: a" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
if git log -1 --format=%B | grep -qi claude; then echo "FAIL git commit"; fail=1; else echo "ok   real git commit stripped"; fi
git config commit-hygiene.footer "Authored-By: tester"
echo b >> f; git commit -q -am "feat: b"
if [ "$(git log -1 --format=%B | sed '/^$/d' | tail -1)" = "Authored-By: tester" ]; then echo "ok   footer appended"; else echo "FAIL footer"; fail=1; fi
exit $fail
