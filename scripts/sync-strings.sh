#!/usr/bin/env bash
# Brings the String Catalogs in line with the strings the code uses, from a build's .stringsdata
# (the compiler writes them with SWIFT_EMIT_LOC_STRINGS). Xcode's editor does this on every build;
# command-line builds don't, so scripts/test.sh runs this after its build (a local run syncs, CI
# checks, #350).
#
#   scripts/sync-strings.sh <derived-data-dir>          update the catalogs, naming each one it changed
#   scripts/sync-strings.sh --check <derived-data-dir>  fail if a catalog is out of date, changing none
#
# The derived data must come from a build of the target that owns each catalog: scripts/test.sh
# builds into .build/derived (the app, which also builds NudgeEngine) and passes it here.
# A catalog is rewritten only when its content changes, so a run with nothing to sync touches no file.
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

changed=()
for entry in "${targets[@]}"; do
  IFS='|' read -r target sources catalogs <<< "$entry"
  args=()
  while IFS= read -r file; do
    if [ -n "$(find "$sources" -name "$(basename "$file" .stringsdata).swift" -print -quit)" ]; then
      args+=(--stringsdata "$file")
    fi
  # Xcode 27 names a package target's folder "<target>-t.build"; Xcode 26 named it "<target>.build".
  # Only arm64's: a build for another architecture (the generic simulator destination also builds
  # x86_64) leaves its own .stringsdata, which stays after the next build and would keep a removed
  # string in the catalog.
  done < <(find "$derived" \( -path "*/$target.build/Objects-normal/arm64/*" -o -path "*/$target-t.build/Objects-normal/arm64/*" \) \
    -name "*.stringsdata" | sort)
  if [ ${#args[@]} -eq 0 ]; then
    echo "No .stringsdata for $target under $derived: build it first" >&2
    exit 1
  fi
  read -r -a files <<< "$catalogs"
  # The sync runs on copies, so a catalog changes only when its content does.
  copies=()
  mkdir -p "$scratch/$target"
  for catalog in "${files[@]}"; do
    cp "$catalog" "$scratch/$target/"
    copies+=("$scratch/$target/$(basename "$catalog")")
  done
  xcrun xcstringstool sync "${copies[@]}" "${args[@]}"
  for catalog in "${files[@]}"; do
    copy="$scratch/$target/$(basename "$catalog")"
    if ! diff -q "$catalog" "$copy" > /dev/null; then
      if $check; then diff "$catalog" "$copy" | head -40 >&2 || true; else cp "$copy" "$catalog"; fi
      changed+=("$catalog")
    fi
  done
done

if $check; then
  if [ ${#changed[@]} -gt 0 ]; then
    echo "Out of date (run scripts/test.sh on your Mac, which syncs them, then fill in any plural variants and commit): ${changed[*]}" >&2
    exit 1
  fi
elif [ ${#changed[@]} -gt 0 ]; then
  for catalog in "${changed[@]}"; do echo "Updated $catalog"; done
  echo "Fill in any plural variants in the updated catalogs, then commit them."
else
  echo "The String Catalogs are already up to date"
fi
