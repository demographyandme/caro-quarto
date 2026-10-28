#!/usr/bin/env bash
# scripts/release-tag.sh on a scratch repository: the tag names the commit that
# set the version (not a later commit that left theme and fonts alone), a theme
# change after the tag without a version bump fails, a bump gets its own tag,
# and a version without x.y.z fails. Run from the repository root.
set -euo pipefail

script=$PWD/scripts/release-tag.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
bad() { echo "tests/release-tag: $*" >&2; fail=1; }

cd "$work"
git init -q -b main .
git config user.email t@example.org; git config user.name test
mkdir -p _extensions/caro-quarto fonts .github
setv() { printf 'title: CARO Theme\nversion: %s\n' "$1" > _extensions/caro-quarto/_extension.yml; }
commit() { git add -A; git commit -q -m "$1"; git rev-parse HEAD; }

setv 1.0.0; echo a > _extensions/caro-quarto/caro.scss; echo f > fonts/fonts.css
r100=$(commit "1.0.0")
echo ci > .github/ci.yml; later=$(commit "CI only")
got=$(bash "$script" 2>/dev/null) || bad "1.0.0: script failed"
[[ "$got" == "$r100" ]] || bad "1.0.0: tagged $got, want the commit that set the version ($r100), not $later"

git tag v1.0.0 "$r100"
got=$(bash "$script" 2>/dev/null) || bad "existing tag with the same content must pass"
[[ "$got" == "$r100" ]] || bad "existing tag: printed $got"

echo b > _extensions/caro-quarto/caro.scss; commit "theme change, no bump" > /dev/null
if bash "$script" 2> /dev/null; then bad "a theme change without a version bump passed"; fi
echo g >> fonts/fonts.css; git add -A; git commit -q -m "font change"   # still unbumped
if bash "$script" 2> /dev/null; then bad "a font change without a version bump passed"; fi

setv 1.1.0; r110=$(commit "1.1.0")
got=$(bash "$script" 2>/dev/null) || bad "1.1.0: script failed"
[[ "$got" == "$r110" ]] || bad "1.1.0: tagged $got, want $r110"

setv 1.2; commit "bad version" > /dev/null
if bash "$script" 2> /dev/null; then bad "a version without x.y.z passed"; fi

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "release-tag: ok"
