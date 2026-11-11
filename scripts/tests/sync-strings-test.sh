#!/usr/bin/env bash
# Tests scripts/sync-strings.sh (#350) over a stand-in for xcrun, in a temporary copy of the folders
# it reads: a sync rewrites and names only the catalogs that change, a run with nothing to sync
# touches no file, and a check changes none. Needs no simulator or build, so CI runs it too
# (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
script="$PWD/scripts/sync-strings.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# expect <description> <expected> <actual>
expect() {
  if [ "$2" = "$3" ]; then
    echo "ok: $1"
  else
    echo "FAIL: $1" >&2
    printf '  expected:\n%s\n  got:\n%s\n' "$2" "$3" >&2
    failures=$((failures + 1))
  fi
}

app=App/Resources/Localizable.xcstrings
untranslated=App/Resources/Untranslated.xcstrings
engine=Packages/NudgeEngine/Sources/NudgeEngine/Localizable.xcstrings

# xcstringstool sync <catalogs> --stringsdata <files>: appends a line to each catalog copy whose
# "<target folder>/<name>" ends with a path in $STUB_CHANGE (separated by spaces), as a sync that
# found a new string would. The copies are in <scratch>/<target>/.
mkdir -p "$work/bin"
cat > "$work/bin/xcrun" <<'EOF'
#!/bin/bash
[ "$1 $2" = "xcstringstool sync" ] || exit 2
shift 2
echo "$*" >> "$STUB_LOG"
for arg in "$@"; do
  case "$arg" in
    --stringsdata) ;;
    *.xcstrings)
      for change in $STUB_CHANGE; do
        case "$arg" in */"$change") echo "new string" >> "$arg" ;; esac
      done ;;
  esac
done
EOF
chmod +x "$work/bin/xcrun"

# A temporary repository holding the script, the catalogs, the sources, and a build's .stringsdata.
repo="$work/repo"
app_data="$repo/derived/Build/Intermediates.noindex/NudgeInator.build/Debug-iphonesimulator/NudgeInator.build/Objects-normal/arm64/Home.stringsdata"
engine_data="$repo/derived/Build/Intermediates.noindex/NudgeEngine.build/Debug-iphonesimulator/NudgeEngine-t.build/Objects-normal/arm64/Summary.stringsdata"
mkdir -p "$repo/scripts" "$repo/App/Resources" "$repo/Packages/NudgeEngine/Sources/NudgeEngine" \
  "$(dirname "$app_data")" "$(dirname "$engine_data")"
cp "$script" "$repo/scripts/sync-strings.sh"
for catalog in "$app" "$untranslated" "$engine"; do echo "{}" > "$repo/$catalog"; done
touch "$repo/App/Home.swift" "$repo/Packages/NudgeEngine/Sources/NudgeEngine/Summary.swift"
touch "$app_data" "$engine_data"
# A leftover from a build for another architecture, whose strings may since have been removed.
stale_data="${app_data/arm64/x86_64}"
mkdir -p "$(dirname "$stale_data")" && touch "$stale_data"

# Every catalog dated long ago, so a rewrite shows in its date even when its content is the same.
old_dates() { touch -t 200001010000 "$repo/$app" "$repo/$untranslated" "$repo/$engine"; }
# Each catalog's date and content, one line per catalog.
state() { for c in "$app" "$untranslated" "$engine"; do echo "$c $(stat -f %m "$repo/$c") $(cksum < "$repo/$c")"; done; }
# Runs the script in the temporary repository: its output and status.
run() { (cd "$repo" && PATH="$work/bin:$PATH" STUB_CHANGE="$STUB_CHANGE" STUB_LOG="$work/xcrun.log" scripts/sync-strings.sh "$@" 2>&1; echo "status $?"); }

old_dates; before="$(state)"
: > "$work/xcrun.log"
out="$(STUB_CHANGE="" run derived)"
expect "a sync with nothing to sync passes" "ok" "$(grep -q 'status 0' <<< "$out" && echo ok)"
expect "a sync with nothing to sync says so, naming no catalog" "ok" \
  "$(grep -q 'already up to date' <<< "$out" && ! grep -q 'Updated' <<< "$out" && echo ok)"
expect "a sync reads only the arm64 build's .stringsdata" "ok" \
  "$(grep -q 'arm64/Home.stringsdata' "$work/xcrun.log" && ! grep -q x86_64 "$work/xcrun.log" && echo ok)"
expect "a sync with nothing to sync changes no file, not even its date" "$before" "$(state)"

out="$(STUB_CHANGE="NudgeInator/Localizable.xcstrings" run derived)"
expect "a sync after a new app string passes" "ok" "$(grep -q 'status 0' <<< "$out" && echo ok)"
expect "a sync names the app catalog it updated, and no other" "Updated $app" "$(grep '^Updated' <<< "$out")"
expect "a sync writes the new string to the app catalog" "new string" "$(tail -1 "$repo/$app")"
expect "a sync leaves the other catalogs as they were" "$(grep -v "^$app" <<< "$before")" "$(state | grep -v "^$app")"

old_dates
out="$(STUB_CHANGE="NudgeInator/Untranslated.xcstrings NudgeEngine/Localizable.xcstrings" run derived)"
expect "a sync names every catalog it updated, the Untranslated one and the engine's too" \
  "Updated $untranslated
Updated $engine" "$(grep '^Updated' <<< "$out")"

old_dates; before="$(state)"
out="$(STUB_CHANGE="NudgeInator/Localizable.xcstrings" run --check derived)"
expect "a check after a new string fails" "ok" "$(grep -q 'status 1' <<< "$out" && echo ok)"
expect "a check names the catalog that is out of date" "ok" "$(grep -q "Out of date.*$app" <<< "$out" && echo ok)"
expect "a check changes no file" "$before" "$(state)"

out="$(STUB_CHANGE="" run --check derived)"
expect "a check with nothing to sync passes" "ok" "$(grep -q 'status 0' <<< "$out" && echo ok)"

# A build that left no .stringsdata (a failed one) must not empty the catalogs.
rm "$app_data"
out="$(STUB_CHANGE="NudgeInator/Localizable.xcstrings" run derived)"
expect "a build with no .stringsdata fails the sync" "ok" "$(grep -q 'status 1' <<< "$out" && echo ok)"
expect "a build with no .stringsdata changes no file" "$before" "$(state)"

if [ $failures -gt 0 ]; then echo "$failures failed" >&2; exit 1; fi
