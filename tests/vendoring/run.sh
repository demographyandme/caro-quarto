#!/usr/bin/env bash
# scripts/vendoring.sh: copies the theme and fonts into a site only from a real
# CARO source, never into or out of itself, and a failed copy leaves the site's
# previous theme in place (audit AB-11). Run from the repository root.
set -euo pipefail

repo=$PWD
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
bad() { echo "tests/vendoring: $*" >&2; fail=1; }
leftover() { compgen -G "$work/site/_extensions/.caro-vendoring.*" > /dev/null; }

# shellcheck source=scripts/vendoring.sh
source scripts/vendoring.sh

new_site() {   # a site that already carries a theme and fonts
  rm -rf "$work/site"
  mkdir -p "$work/site/_extensions/caro-quarto" "$work/site/fonts"
  echo old > "$work/site/_extensions/caro-quarto/caro.scss"
  echo old > "$work/site/fonts/fonts.css"
}
vend() { ( ROOT="$1" CARO_QUARTO_SRC="$2" caro_vendoring_copy ) 2> "$work/err"; }

# 1. from the checkout root: mirror of both trees, stale files gone
new_site; echo stale > "$work/site/fonts/Old-var.woff2"
vend "$work/site" "$repo" || bad "vendoring from the checkout failed: $(cat "$work/err")"
diff -r _extensions/caro-quarto "$work/site/_extensions/caro-quarto" > /dev/null || bad "extension not mirrored"
diff -r fonts "$work/site/fonts" > /dev/null || bad "fonts not mirrored (a stale file lingers?)"
leftover && bad "temporary folder left behind"

# 2. from the checkout's _extensions/caro-quarto/ folder: same result
new_site
vend "$work/site" "$repo/_extensions/caro-quarto" || bad "vendoring from the extension folder failed: $(cat "$work/err")"
diff -r fonts "$work/site/fonts" > /dev/null || bad "fonts not found from the extension folder"

# 3. a folder that is not CARO (the finding's fake home with .ssh): refused, site untouched
new_site; mkdir -p "$work/home/.ssh"; echo key > "$work/home/.ssh/id_ed25519"
if vend "$work/site" "$work/home"; then bad "a non-CARO source was accepted"; fi
[[ "$(cat "$work/site/_extensions/caro-quarto/caro.scss")" == old ]] || bad "a refused source changed the site's theme"
[[ -e "$work/site/_extensions/caro-quarto/.ssh" ]] && bad "a refused source was copied"

# 4. an _extension.yml that is not CARO's: refused
mkdir -p "$work/other/_extensions/caro-quarto" "$work/other/fonts"
echo 'title: Other Theme' > "$work/other/_extensions/caro-quarto/_extension.yml"; echo x > "$work/other/fonts/fonts.css"
new_site
if vend "$work/site" "$work/other"; then bad "a non-CARO _extension.yml was accepted"; fi

# 5. the site's own copy as source (containment the old equality guard missed): no deletion
new_site; cp -R _extensions/caro-quarto/. "$work/site/_extensions/caro-quarto/"; cp -R fonts/. "$work/site/fonts/"
vend "$work/site" "$work/site/_extensions" || true
[[ -f "$work/site/_extensions/caro-quarto/caro.scss" ]] || bad "vendoring from the site's own _extensions deleted its theme"
vend "$work/site" "$work/site" || bad "the site as its own source should be a no-op: $(cat "$work/err")"
[[ -f "$work/site/_extensions/caro-quarto/caro.scss" ]] || bad "the site as its own source deleted its theme"

# 6. a failing copy (cp shimmed to fail) leaves the previous theme in place, and says so
new_site; mkdir -p "$work/bin"; printf '#!/bin/sh\nexit 1\n' > "$work/bin/cp"; chmod +x "$work/bin/cp"
if ( PATH="$work/bin:$PATH" vend "$work/site" "$repo" ); then bad "a failed copy returned success"; fi
[[ "$(cat "$work/site/_extensions/caro-quarto/caro.scss")" == old ]] || bad "a failed copy removed the previous theme"
leftover && bad "a failed copy left its temporary folder"

# 7. no CARO_QUARTO_SRC: nothing to do, success (pre-render calls it unconditionally)
new_site
( ROOT="$work/site" CARO_QUARTO_SRC='' caro_vendoring_copy ) || bad "an unset CARO_QUARTO_SRC must be a no-op"

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "vendoring: ok"
