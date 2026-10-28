#!/usr/bin/env bash
# CI checks for caro-quarto (.github/workflows/ci.yml runs exactly this script).
# Run locally from the repository root: bash scripts/ci-check.sh
# Needs quarto (CI pins the fleet's version), shellcheck, python3 and git.
#
#   1. the shell scripts pass shellcheck; scripts/build-fonts.py compiles;
#   2. release bookkeeping: _extension.yml's version is the newest CHANGELOG entry;
#   3. fonts: every url() in fonts/fonts.css names a committed file and every
#      committed woff2 is declared there (a renamed or dropped face fails);
#   4. the tokens compile, with Quarto's bundled Sass, without deprecated colour
#      or global functions (Quarto's render hides Sass warnings);
#   5. the theme renders: scripts/vendoring.sh copies the extension and fonts into
#      a scratch copy of tests/fixture/ (a site wired as the README says, with
#      every include), quarto renders it, and the output must carry each include,
#      the theme's compiled rules and the served fonts.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
repo=$PWD
fail=0
err() { echo "::error::$*"; fail=1; }

echo "== shellcheck, py_compile"
# Each problem becomes an annotation, so a failure is readable without the raw log.
if ! sc_out=$(shellcheck -x -f gcc scripts/*.sh 2>&1); then
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

echo "== render fixture ($(quarto --version))"
site=$(mktemp -d)
trap 'rm -rf "$site"' EXIT
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
  must index.html 'caro-viewer-height'              "viewer-autoresize.html include missing"
  must index.html 'href="fonts/fonts.css"'          "fonts/fonts.css not linked"
  must viewer.html 'class="[^"]*research-companion' "body-classes: research-companion not applied"
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
  fi
  while IFS= read -r f; do
    [[ -z "$f" || -f "$out/fonts/$f" ]] || err "rendered site does not serve fonts/$f"
  done <<< "$declared"
else
  err "quarto render of tests/fixture failed"
fi

if [[ $fail -ne 0 ]]; then
  echo "ci-check: FAILED"
  exit 1
fi
echo "ci-check: all checks passed"
