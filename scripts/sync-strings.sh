#!/usr/bin/env bash
# Brings the String Catalogs in line with the strings the code uses, from a build's .stringsdata
# (the compiler writes them with SWIFT_EMIT_LOC_STRINGS). Xcode's editor does this on every build;
# command-line builds don't, so run this after adding or changing a string outside Xcode.
#
#   scripts/sync-strings.sh <derived-data-dir>          update the catalogs
#   scripts/sync-strings.sh --check <derived-data-dir>  fail if a catalog is out of date
#
# The derived data must come from a build of the target that owns each catalog: scripts/test.sh
# builds into .build/derived (the app, which also builds NudgeEngine) and passes it here.
set -euo pipefail
cd "$(dirname "$0")/.."

check=false
if [ "${1:-}" = "--check" ]; then check=true; shift; fi
derived="${1:?usage: scripts/sync-strings.sh [--check] <derived-data-dir>}"

# Target name, then its catalog.
catalogs=(
  "NudgeInator App/Resources/Localizable.xcstrings"
  "NudgeEngine Packages/NudgeEngine/Sources/NudgeEngine/Localizable.xcstrings"
)

stale=()
for entry in "${catalogs[@]}"; do
  target="${entry%% *}"
  catalog="${entry#* }"
  args=()
  while IFS= read -r file; do args+=(--stringsdata "$file"); done < <(
    find "$derived" -path "*/$target.build/Objects-normal/*" -name "*.stringsdata" | sort)
  if [ ${#args[@]} -eq 0 ]; then
    echo "No .stringsdata for $target under $derived: build it first" >&2
    exit 1
  fi
  if $check; then
    copy="$(mktemp -d)/$(basename "$catalog")"
    cp "$catalog" "$copy"
    xcrun xcstringstool sync "$copy" "${args[@]}"
    if ! diff -q "$catalog" "$copy" > /dev/null; then
      diff "$catalog" "$copy" | head -40 >&2
      stale+=("$catalog")
    fi
  else
    xcrun xcstringstool sync "$catalog" "${args[@]}"
    echo "Synced $catalog"
  fi
done

if [ ${#stale[@]} -gt 0 ]; then
  echo "Out of date (run scripts/sync-strings.sh .build/derived, then fill in any plural variants): ${stale[*]}" >&2
  exit 1
fi
