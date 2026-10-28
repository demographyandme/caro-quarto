#!/usr/bin/env bash
# _extensions/caro-quarto/reflow/caro-reflow-check.mjs, the reflow gate every fleet
# site runs on its _site (audit K-04/G-01, W3-13). Installed the way the callers
# install it (the folder copied out of the theme, `npm ci` there), then:
#   - a page 332 px wide at 320 px fails (exit 1), named with its widths and its
#     widest element; the same page fits at 375 px and a fitting page is not named;
#   - served under a sub-path (--slug, as a companion is), a page whose width comes
#     from a root-relative /<slug>/ stylesheet is measured with that stylesheet;
#   - a site whose pages fit passes (exit 0); a bad call exits 2;
#   - the gate pins the same Playwright as tests/package.json;
#   - with an argument, that rendered site (scripts/ci-check.sh passes the
#     fixture's _site) passes at 320, 375 and 1280 px served at /caro-fixture/.
# Exit 77 when Node, the npm install or Playwright's Chromium is missing (the
# caller decides whether that is a skip). Run from the repository root:
#   bash tests/reflow/run.sh [rendered _site]
set -euo pipefail

gate=_extensions/caro-quarto/reflow
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
bad() { echo "tests/reflow: $*" >&2; fail=1; }

pin() { sed -n 's/^ *"playwright": "\([^"]*\)".*/\1/p' "$1" | head -n 1; }
locked() { grep -A1 '"node_modules/playwright": {' "$1" | sed -n 's/^ *"version": "\([^"]*\)".*/\1/p'; }
p=$(pin "$gate/package.json")
[[ "$p" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || bad "$gate/package.json: playwright must be an exact version (got '$p')"
[[ "$(locked "$gate/package-lock.json")" == "$p" ]] || bad "$gate/package-lock.json does not lock playwright $p"
[[ "$(pin tests/package.json)" == "$p" ]] || bad "tests/package.json pins playwright $(pin tests/package.json), the gate $p"

if ! command -v node > /dev/null || ! command -v npm > /dev/null; then echo "tests/reflow: no node/npm"; exit 77; fi
cp -R "$gate" "$work/gate"
if ! (cd "$work/gate" && npm ci --no-audit --no-fund --ignore-scripts > "$work/npm.log" 2>&1); then
  cat "$work/npm.log"; echo "tests/reflow: npm ci failed"; exit 77
fi
(cd "$work/gate" && node -e 'process.exit(require("fs").existsSync(require("playwright").chromium.executablePath()) ? 0 : 1)') \
  || { echo "tests/reflow: Playwright's Chromium is missing"; exit 77; }

page() {   # page <file> <body> [head]
  mkdir -p "$(dirname "$1")"
  printf '<!doctype html><html><head><meta charset="utf-8">%s%s</head><body>%s</body></html>\n' \
    '<meta name="viewport" content="width=device-width, initial-scale=1"><style>body{margin:0}</style>' "${3:-}" "$2" > "$1"
}
run() { rc=0; node "$work/gate/caro-reflow-check.mjs" "$@" > "$work/out" 2>&1 || rc=$?; }

page "$work/bad/index.html" '<p>reflows</p>'
page "$work/bad/sub/wide.html" '<main><div style="overflow-x:auto"><table style="width:900px"><tr><td>scrolls in its box</td></tr></table></div><div id="wide" class="fixed" style="width:332px">fixed 332 px</div></main>'
page "$work/bad/site_libs/skip.html" '<div style="width:2000px">not a page</div>'
run "$work/bad" 320 375
[[ $rc -eq 1 ]] || bad "a 332 px page exited $rc, expected 1: $(cat "$work/out")"
grep -qF 'sub/wide.html: 332px at 320px (widest: DIV#wide.fixed "fixed 332 px" right edge 332px)' "$work/out" \
  || bad "the 332 px page or its widest element is not named: $(cat "$work/out")"
grep -qE 'index.html: |wide.html: [0-9]+px at 375px|site_libs' "$work/out" && bad "a page that fits (or site_libs/) was flagged: $(cat "$work/out")"

# Under /<slug>/: the width comes from a root-relative stylesheet, as Quarto's
# site_libs links resolve on a companion.
mkdir -p "$work/slug/css"
echo '.w{width:400px}' > "$work/slug/css/w.css"
page "$work/slug/index.html" '<div class="w">400 px</div>' '<link rel="stylesheet" href="/caro-fixture/css/w.css">'
run "$work/slug" --slug caro-fixture 320
{ [[ $rc -eq 1 ]] && grep -qF 'index.html: 400px at 320px' "$work/out"; } ||
  bad "under --slug the page's /caro-fixture/ stylesheet was not served (exit $rc): $(cat "$work/out")"

page "$work/good/index.html" '<p>reflows</p>'
page "$work/good/a/b.html" '<p>also reflows</p>'
run "$work/good" --slug caro-fixture
{ [[ $rc -eq 0 ]] && grep -qF 'ok (2 page(s) x 3 width(s): 320, 375, 1280 px, served at /caro-fixture/)' "$work/out"; } ||
  bad "a site that fits exited $rc, expected 0 at the default widths: $(cat "$work/out")"

run; [[ $rc -eq 2 ]] || bad "no arguments exited $rc, expected 2"
run "$work/none"; [[ $rc -eq 2 ]] || bad "a missing site folder exited $rc, expected 2"
run "$work/good" 0; [[ $rc -eq 2 ]] || bad "width 0 exited $rc, expected 2"

if [[ -n "${1:-}" ]]; then
  run "$1" --slug caro-fixture
  cat "$work/out"
  [[ $rc -eq 0 ]] || bad "the rendered site $1 is wider than the viewport (exit $rc)"
fi

[[ $fail -eq 0 ]] || exit 1
echo "tests/reflow: ok"
