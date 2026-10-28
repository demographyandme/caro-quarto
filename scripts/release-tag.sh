#!/usr/bin/env bash
# Name the release a commit carries: print the commit that tag v<version> must
# point at, for the version in _extensions/caro-quarto/_extension.yml at SHA
# (default HEAD). With --push, create the tag there and push it (CI does this:
# .github/workflows/release-tag.yml, after the checks passed on main).
#
# A release names exact content: the theme (_extensions/caro-quarto/) and fonts
# (fonts/) that sites vendor. The tag goes on the oldest commit, at or after the
# commit that set the version, whose theme and fonts equal SHA's. Tags never
# move: when v<version> exists and its theme or fonts differ from SHA's, the
# theme changed without a version bump, and this fails.
set -euo pipefail

push=0
if [[ "${1:-}" == "--push" ]]; then push=1; shift; fi
sha=$(git rev-parse --verify "${1:-HEAD}^{commit}")
ext=_extensions/caro-quarto/_extension.yml

version_at() { git show "$1:$ext" 2>/dev/null | sed -n 's/^version: *//p'; }
content_at() { echo "$(git rev-parse "$1:_extensions/caro-quarto") $(git rev-parse "$1:fonts")"; }

version=$(version_at "$sha")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "release-tag: no x.y.z version in $ext at $sha" >&2; exit 1; }
tag="v$version"
want=$(content_at "$sha")

if old=$(git rev-parse -q --verify "refs/tags/$tag^{commit}"); then
  if [[ "$(content_at "$old")" != "$want" ]]; then
    echo "release-tag: the theme or fonts changed since $tag ($old) but $ext still says $version; bump the version and add a CHANGELOG entry" >&2
    exit 1
  fi
  echo "release-tag: $tag already names this content ($old)" >&2
  echo "$old"
  exit 0
fi

# The commit that set this version: walk back the commits that touched
# _extension.yml while they still carry it.
bump=""
while read -r c; do
  [[ "$(version_at "$c")" == "$version" ]] || break
  bump=$c
done < <(git rev-list "$sha" -- "$ext")
[[ -n "$bump" ]] || { echo "release-tag: no commit sets version $version" >&2; exit 1; }

target=""
while read -r c; do
  if [[ "$(content_at "$c")" == "$want" ]]; then target=$c; break; fi
done < <(git rev-list --reverse --ancestry-path "$bump^..$sha" 2>/dev/null || git rev-list --reverse "$sha")
[[ -n "$target" ]] || target=$sha

echo "release-tag: $tag -> $target" >&2
if [[ $push -eq 1 ]]; then
  git tag "$tag" "$target"
  git push origin "refs/tags/$tag"
fi
echo "$target"
