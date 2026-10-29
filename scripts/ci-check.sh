#!/usr/bin/env bash
# CI checks for caro-quarto (.github/workflows/ci.yml runs exactly this script).
# Run locally from the repository root: bash scripts/ci-check.sh
# Needs quarto (CI pins the fleet's version), shellcheck, python3 and git.
#
#   1. the shell scripts pass shellcheck; scripts/build-fonts.py compiles;
#   2. release bookkeeping: _extension.yml's version is the newest CHANGELOG entry;
#   3. fonts: every url() in fonts/fonts.css names a committed file and every
#      committed woff2 is declared there (a renamed or dropped face fails), and
#      every family/style a Fallback face covers has a web face;
#   4. the fonts are reproducible: scripts/build-fonts.py rebuilds them from the
#      upstream sources in git (FONT_SOURCES) and the build must equal fonts/
#      byte for byte. Needs the fontTools pinned in scripts/requirements-fonts.txt
#      (in $CARO_FONTS_PYTHON, default python3); CI fails without it, a local
#      run warns and skips;
#   5. the tokens compile, with Quarto's bundled Sass, without deprecated colour
#      or global functions (Quarto's render hides Sass warnings);
#   6. tests/post-render: the HTML normalizer (caro-post-render.sh) matches its
#      fixtures and is idempotent; on the rendered fixture it puts the skip link
#      first in <body>.
#   7. tests/vendoring: scripts/vendoring.sh accepts only a CARO source, never
#      mirrors a tree into or out of itself, and keeps the site's theme when a
#      copy fails;
#   8. release tag: tests/release-tag passes, and the version in _extension.yml
#      is not an existing tag whose theme or fonts differ from this checkout's;
#   9. the theme renders: scripts/vendoring.sh copies the extension and fonts into
#      a scratch copy of tests/fixture/ (a site wired as the README says, with
#      every include), quarto renders it, and the output must carry each include,
#      the theme's compiled rules and the served fonts; tests/external-links-check.js
#      then checks in Chromium which links open a new tab (CI fails without
#      Playwright, tests/package.json; a local run without it skips).
#  10. the reflow gate (_extensions/caro-quarto/reflow/caro-reflow-check.mjs, which
#      the fleet's CI runs on every built site): tests/reflow installs it as a
#      caller does and checks it on fixture pages (a 332 px page fails at 320 px
#      and is named; a page loading an image, or an iframe loading a script, from
#      a host other than the site fails unless --allow-host names it), then on the
#      rendered fixture at 320, 375 and 1280 px; Quarto
#      must not copy it into _site. CI fails without Node, the npm install or
#      Chromium; a local run without them skips.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
repo=$PWD
fail=0
err() { echo "::error::$*"; fail=1; }
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

echo "== shellcheck, py_compile"
# Each problem becomes an annotation, so a failure is readable without the raw log.
if ! sc_out=$(shellcheck -x -f gcc scripts/*.sh _extensions/caro-quarto/caro-post-render.sh tests/post-render/run.sh tests/vendoring/run.sh tests/release-tag/run.sh tests/reflow/run.sh 2>&1); then
  while IFS= read -r line; do err "shellcheck $(shellcheck --version | sed -n 's/^version: //p'): $line"; done <<<"$sc_out"
fi
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' scripts/build-fonts.py \
  || err "scripts/build-fonts.py does not parse"

echo "== version"
ext_version=$(sed -n 's/^version: *//p' _extensions/caro-quarto/_extension.yml)
log_version=$(sed -n 's/^## *\([0-9][0-9.]*\).*/\1/p' CHANGELOG.md | head -n 1)
[[ -n "$ext_version" && "$ext_version" == "$log_version" ]] \
  || err "_extension.yml version '$ext_version' is not the newest CHANGELOG entry '$log_version'"

echo "== fonts"
declared=$(grep -o 'url("[^"]*")' fonts/fonts.css | sed 's/^url("//; s/")$//' | sort -u)
[[ -n "$declared" ]] || err "fonts/fonts.css declares no url()"
while IFS= read -r f; do
  [[ -z "$f" || -f "fonts/$f" ]] || err "fonts/fonts.css names $f, which is not in fonts/"
done <<< "$declared"
for f in fonts/*.woff2; do
  grep -qxF "${f#fonts/}" <<< "$declared" || err "$f is not declared in fonts/fonts.css"
done
# Every style a fallback stands in for has a web face: otherwise the browser
# synthesizes it from another style once the web font loads (AB-12).
python3 - fonts/fonts.css <<'PY' || err "fonts/fonts.css: a fallback's family/style has no web face"
import re, sys
faces = {(m[0], m[1]) for m in re.findall(r'font-family: "([^"]+)";[^}]*?font-style: (\w+);', open(sys.argv[1]).read())}
missing = sorted(f"{fam[:-9]} {style}" for fam, style in faces if fam.endswith(" Fallback") and (fam[:-9], style) not in faces)
for m in missing: print(f"no web face for {m}")
sys.exit(1 if missing else 0)
PY

echo "== font rebuild"
FONT_SOURCES=e725422   # the commit holding the upstream .ttf/.otf (build-fonts.py docstring)
py=${CARO_FONTS_PYTHON:-python3}
pin=$(sed -n 's/^fonttools==//p' scripts/requirements-fonts.txt)
have=$("$py" -c 'import fontTools; print(fontTools.version)' 2>/dev/null || true)
if [[ -n "$pin" && "$have" == "$pin" ]]; then
  if ! git cat-file -e "$FONT_SOURCES^{commit}" 2>/dev/null; then
    err "commit $FONT_SOURCES (font sources) is not in this clone; fetch the full history"
  elif "$py" scripts/build-fonts.py --from-git "$FONT_SOURCES" --out "$scratch/fonts" --check-rebuild \
         > "$scratch/fonts.log" 2>&1; then
    tail -n 2 "$scratch/fonts.log"
  else
    grep -v '^fsSelection bits' "$scratch/fonts.log"
    err "scripts/build-fonts.py does not reproduce fonts/ (fontTools $have)"
  fi
elif [[ "${GITHUB_ACTIONS:-}" == true ]]; then
  err "$py has fontTools '${have:-none}'; the font rebuild check needs $pin (scripts/requirements-fonts.txt)"
else
  echo "::warning::font rebuild skipped: $py has fontTools '${have:-none}', the check needs $pin" \
       "(python3 -m venv DIR && DIR/bin/pip install -r scripts/requirements-fonts.txt; CARO_FONTS_PYTHON=DIR/bin/python)"
fi


echo "== sass deprecations"
# Quarto's render hides Sass warnings, so compile the tokens with the Sass that
# Quarto bundles and make the deprecated colour/global functions fatal: a future
# Dart Sass 3 removes them. (@import itself is Quarto's layering, so not fatal here.)
sass_bin=$(find "$(dirname "$(readlink -f "$(command -v quarto)")")/tools" -path '*dart-sass/sass' -type f 2>/dev/null | head -n 1)
if [[ -z "$sass_bin" ]]; then
  err "Quarto's bundled dart-sass not found next to $(command -v quarto)"
else
  sass_dir=$(mktemp -d)
  cat > "$sass_dir/stub.scss" <<'SCSS'
@import "caro-tokens";
a { color: $link-hover-color; }
SCSS
  "$sass_bin" --no-source-map --load-path=_extensions/caro-quarto \
    --silence-deprecation=import --fatal-deprecation=color-functions,global-builtin "$sass_dir/stub.scss" > /dev/null \
    || err "_caro-tokens.scss uses a deprecated Sass colour or global function (see above)"
  rm -rf "$sass_dir"
fi

echo "== post-render normalizer (tests/post-render)"
bash tests/post-render/run.sh || err "tests/post-render: the normalizer output differs from the fixtures"

echo "== release tag (tests/release-tag)"
bash tests/release-tag/run.sh || err "tests/release-tag: scripts/release-tag.sh picks the wrong commit or lets an unbumped change through"
# This checkout: a theme or font change that keeps an already-tagged version fails
# here, before merge (CI fetches the tags; a clone without them passes).
bash scripts/release-tag.sh > /dev/null || err "the theme or fonts differ from the tagged release this version names; bump the version"

echo "== vendoring (tests/vendoring)"
bash tests/vendoring/run.sh || err "tests/vendoring: scripts/vendoring.sh copied from a bad source, into itself, or lost the theme on a failed copy"

echo "== render fixture ($(quarto --version))"
site="$scratch/site"
mkdir "$site"
cp -R tests/fixture/. "$site/"
(
  # shellcheck source=scripts/caro-vendoring-run.sh
  source scripts/caro-vendoring-run.sh
  ROOT="$site" CARO_QUARTO_SRC="$repo" caro_vendoring_run
)
diff -r _extensions/caro-quarto "$site/_extensions/caro-quarto" > /dev/null || err "vendoring did not mirror _extensions/caro-quarto"
diff -r fonts "$site/fonts" > /dev/null || err "vendoring did not mirror fonts/"
if (cd "$site" && quarto render --quiet); then
  out="$site/_site"
  must() { grep -q -- "$2" "$out/$1" || err "$1: $3"; }
  must index.html 'class="skip-link"'               "skip-link.html include missing"
  must index.html 'demographyandme\\.com'           "external-links.html include missing"
  must index.html 'site_libs/quarto-nav/'           "external-links.html: site-root lookup (site_libs/quarto-nav/) missing"
  must index.html 'opens in a new tab'              "external-links.html: new-tab cue missing"
  must links.html 'class="skip-link"'               "links.html (link cases) not rendered"
  must index.html 'caro-viewer-height'              "viewer-autoresize.html include missing"
  must index.html 'href="fonts/fonts.css"'          "fonts/fonts.css not linked"
  must viewer.html 'class="[^"]*research-companion' "body-classes: research-companion not applied"
  bash _extensions/caro-quarto/caro-post-render.sh "$out" || err "caro-post-render.sh failed on the rendered fixture"
  perl -0777 -ne 'exit !/<body\b[^>]*>\s*<a\b[^>]*class="skip-link"/' "$out/index.html" \
    || err "index.html: after caro-post-render.sh the skip link is not the first child of <body>"
  preloads=$(grep -o '<link rel="preload" href="[^"]*" as="font"' "$out/index.html" | sed 's/^<link rel="preload" href="//; s/" as="font"$//')
  [[ -n "$preloads" ]] || err "index.html: no font preload after caro-post-render.sh"
  while IFS= read -r f; do
    [[ -z "$f" || -f "$out/$f" ]] || err "index.html preloads $f, which the rendered site does not serve"
  done <<< "$preloads"
  perl -0777 -ne 'exit !/<head>(?:(?!<link[^>]*rel="stylesheet").)*<link rel="stylesheet" href="fonts\/fonts\.css">/s' "$out/index.html" \
    || err "index.html: fonts/fonts.css is not the first stylesheet after caro-post-render.sh"
  ! grep -Eq '<script src="[^"]*(quarto-nav|headroom\.min|popper\.min|tippy\.umd\.min|bootstrap\.min)\.js"></script>' "$out/index.html" \
    || err "index.html: a classic Quarto head script is not deferred after caro-post-render.sh"
  css=$(grep -o 'href="site_libs/bootstrap/bootstrap[^"]*\.min\.css"' "$out/index.html" | head -n 1 | sed 's/^href="//; s/"$//')
  if [[ -z "$css" || ! -f "$out/$css" ]]; then
    err "compiled bootstrap css not found"
  else
    grep -q '\.skip-link' "$out/$css" || err "theme rules (.skip-link) missing from compiled css"
    grep -q 'body\.research-companion' "$out/$css" || err "theme rules (body.research-companion) missing from compiled css"
    # The root size is relative, so a reader's browser font-size setting scales every rem.
    grep -q ':root{font-size:[0-9.]*%' "$out/$css" || err "root font-size is not a percentage (\$fs-root must follow the reader's default size)"
    # A viewer iframe cannot fragment across printed pages, so print leaves it out.
    grep -q '@media print{[^@]*\.visual-companion-viewer{display:none' "$out/$css" \
      || err "print rule hiding .visual-companion-viewer missing from compiled css"
    grep -q '\.visually-hidden' "$out/$css" || err ".visually-hidden (external-links.html cue) missing from compiled css"
    # Reflow (W3-13, SC 1.4.10): a long URL as link text breaks instead of widening the page.
    grep -q '#quarto-document-content a{overflow-wrap:break-word}' "$out/$css" \
      || err "#quarto-document-content a overflow-wrap:break-word (long links) missing from compiled css"
  fi
  while IFS= read -r f; do
    [[ -z "$f" || -f "$out/fonts/$f" ]] || err "rendered site does not serve fonts/$f"
  done <<< "$declared"
  # Browser check: links served under a sub-path, as a companion is (exit 77: no Playwright here).
  rc=77
  if command -v node > /dev/null; then rc=0; node tests/external-links-check.js "$out" --assert || rc=$?; fi
  case $rc in
    0) ;;
    77) if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
          err "external-links browser check could not run (no Node, Playwright or Chromium; CI installs them from tests/package.json)"
        else
          echo "::notice::external-links browser check skipped (no Node, Playwright or Chromium)"
        fi ;;
    *) err "external-links browser check failed (tests/external-links-check.js)" ;;
  esac
  # The theme's reflow gate ships in _extensions/ and must stay out of the output.
  ! find "$out" -name caro-reflow-check.mjs -o -name reflow | grep -q . \
    || err "_site carries the reflow gate's files (Quarto copied _extensions/caro-quarto/reflow/)"
  rc=0
  bash tests/reflow/run.sh "$out" || rc=$?
  case $rc in
    0) ;;
    77) if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
          err "reflow gate check could not run (no Node, npm install of _extensions/caro-quarto/reflow, or Chromium)"
        else
          echo "::notice::reflow gate check skipped (no Node, npm install or Chromium)"
        fi ;;
    *) err "tests/reflow: the reflow gate misjudged a fixture page, or the rendered fixture is wider than the viewport" ;;
  esac
else
  err "quarto render of tests/fixture failed"
fi

if [[ $fail -ne 0 ]]; then
  echo "ci-check: FAILED"
  exit 1
fi
echo "ci-check: all checks passed"
