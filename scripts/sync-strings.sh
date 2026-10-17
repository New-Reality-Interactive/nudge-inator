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
# InfoPlist.xcstrings isn't synced here: the build itself adds Info.plist keys to it, and
# scripts/test.sh fails if a build changed it.
set -euo pipefail
cd "$(dirname "$0")/.."

check=false
if [ "${1:-}" = "--check" ]; then check=true; shift; fi
derived="${1:?usage: scripts/sync-strings.sh [--check] <derived-data-dir>}"

# Target|its sources|its catalogs (one per table). The sources tell which .stringsdata are current:
# one whose .swift file was deleted would otherwise keep a removed string in the catalog.
targets=(
  "NudgeInator|App|App/Resources/Localizable.xcstrings App/Resources/Untranslated.xcstrings"
  "NudgeEngine|Packages/NudgeEngine/Sources|Packages/NudgeEngine/Sources/NudgeEngine/Localizable.xcstrings"
)

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

stale=()
for entry in "${targets[@]}"; do
  IFS='|' read -r target sources catalogs <<< "$entry"
  args=()
  while IFS= read -r file; do
    if [ -n "$(find "$sources" -name "$(basename "$file" .stringsdata).swift" -print -quit)" ]; then
      args+=(--stringsdata "$file")
    fi
  done < <(find "$derived" -path "*/$target.build/Objects-normal/*" -name "*.stringsdata" | sort)
  if [ ${#args[@]} -eq 0 ]; then
    echo "No .stringsdata for $target under $derived: build it first" >&2
    exit 1
  fi
  read -r -a files <<< "$catalogs"
  if $check; then
    copies=()
    for catalog in "${files[@]}"; do
      mkdir -p "$scratch/$target"
      cp "$catalog" "$scratch/$target/"
      copies+=("$scratch/$target/$(basename "$catalog")")
    done
    xcrun xcstringstool sync "${copies[@]}" "${args[@]}"
    for catalog in "${files[@]}"; do
      if ! diff -q "$catalog" "$scratch/$target/$(basename "$catalog")" > /dev/null; then
        diff "$catalog" "$scratch/$target/$(basename "$catalog")" | head -40 >&2
        stale+=("$catalog")
      fi
    done
  else
    xcrun xcstringstool sync "${files[@]}" "${args[@]}"
    echo "Synced ${files[*]}"
  fi
done

if [ ${#stale[@]} -gt 0 ]; then
  echo "Out of date (run scripts/sync-strings.sh .build/derived, then fill in any plural variants): ${stale[*]}" >&2
  exit 1
fi
