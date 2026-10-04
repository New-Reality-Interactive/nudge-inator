#!/bin/bash
# Runs the mockup's scripted checks in headless Chrome.
#   run-checks.sh behavior [index.html]   behavior checks (default)
#   run-checks.sh axe [index.html]        axe-core, WCAG 2.0/2.1/2.2 A and AA, 216 screen configurations
# The mockup defaults to ../index.html. Pass another copy (for example `git show HEAD~1:…`) to confirm a
# new check fails on the commit before its fix.
# Notes: don't add --user-data-dir (Chrome hangs on GoogleUpdater); macOS has no `timeout`, so runs are
# capped with a perl alarm (exit 142 means the cap was hit).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-behavior}"
MOCK="${2:-$HERE/../index.html}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

inject() { # inject <out.html> <script files...>
  python3 - "$MOCK" "$@" <<'PY'
import sys
mock, out, scripts = sys.argv[1], sys.argv[2], sys.argv[3:]
m = open(mock).read(); i = m.rfind("</body>")
open(out, "w").write(m[:i] + "".join(f"<script>\n{open(s).read()}\n</script>\n" for s in scripts) + m[i:])
PY
}

case "$MODE" in
  behavior)
    inject "$TMP/page.html" "$HERE/behavior-checks.js"
    perl -e 'alarm 60; exec @ARGV' "$CHROME" --headless=new --disable-gpu --virtual-time-budget=2000 \
      --enable-logging=stderr --v=0 --dump-dom "file://$TMP/page.html" > "$TMP/dom.html" 2> "$TMP/err.txt"
    python3 - "$TMP/dom.html" <<'PY'
import sys, re, json, html
s = open(sys.argv[1]).read(); m = re.search(r'<pre id="TESTRESULTS">(.*?)</pre>', s, re.S)
if not m: print("NO RESULTS (the page didn't finish; check for a script error)"); sys.exit(1)
r = json.loads(html.unescape(m.group(1))); bad = [x for x in r if x[0] != "PASS"]
print(f"{len(r) - len(bad)}/{len(r)} pass"); [print(f"{a:5} {b}  -> {c}") for a, b, c in bad]
sys.exit(1 if bad else 0)
PY
    grep -i "Uncaught" "$TMP/err.txt" || true ;;
  axe)
    (cd "$TMP" && npm pack axe-core@4.13.0 --silent >/dev/null && tar xzf axe-core-*.tgz)
    inject "$TMP/page.html" "$TMP/package/axe.min.js" "$HERE/axe-checks.js"
    perl -e 'alarm 280; exec @ARGV' "$CHROME" --headless=new --disable-gpu --window-size=1400,1000 \
      --virtual-time-budget=3600000 --dump-dom "file://$TMP/page.html" > "$TMP/dom.html" 2>/dev/null
    python3 - "$TMP/dom.html" <<'PY'
import sys, re, json, html
s = open(sys.argv[1]).read(); m = re.search(r'<pre id="AXERESULTS">(.*?)</pre>', s, re.S)
if not m: print("NO RESULTS"); sys.exit(1)
r = json.loads(html.unescape(m.group(1)))
print(f"axe runs {r['runs']}, errors {len(r['errors'])}, violations {len(r['violations'])}")
for k, v in r["violations"].items(): print(f" * {k}: {v['configs']} configs, e.g. {', '.join(v['examples'][:3])}")
sys.exit(1 if r["violations"] or r["errors"] else 0)
PY
    ;;
  *) echo "usage: $0 [behavior|axe] [index.html]"; exit 2 ;;
esac
