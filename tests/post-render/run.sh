#!/usr/bin/env bash
# Fixture test for _extensions/caro-quarto/caro-post-render.sh: every input.html
# under tests/post-render/, normalized, must equal the expected.html beside it,
# and a second run must change nothing (idempotence).
#   bash tests/post-render/run.sh           # check
#   bash tests/post-render/run.sh --update  # rewrite expected.html (review the diff)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
normalizer="${here}/../../_extensions/caro-quarto/caro-post-render.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0

(cd "$here" && find . -name input.html -type f) | while IFS= read -r f; do
  mkdir -p "$work/$(dirname "$f")"
  cp "$here/$f" "$work/$f"
done
bash "$normalizer" "$work"
first=$(cd "$work" && find . -name '*.html' -type f -exec cksum {} + | sort)
bash "$normalizer" "$work"
second=$(cd "$work" && find . -name '*.html' -type f -exec cksum {} + | sort)
if [[ "$first" != "$second" ]]; then
  echo "post-render: a second run changed the output (not idempotent)" >&2
  fail=1
fi

while IFS= read -r f; do
  expected="$here/$(dirname "$f")/expected.html"
  if [[ "${1:-}" == "--update" ]]; then
    cp "$work/$f" "$expected"
  elif ! diff -u "$expected" "$work/$f"; then
    echo "post-render: $f differs from $(dirname "$f")/expected.html" >&2
    fail=1
  fi
done < <(cd "$work" && find . -name input.html -type f)

# A page it cannot read the way it expects must stop the run.
printf '<body>\n<a href="#x" class="skip-link">a</a>\n<a href="#x" class="skip-link">b</a>\n</body>\n' > "$work/bad.html"
if bash "$normalizer" "$work" 2>/dev/null; then
  echo "post-render: a page with two skip links did not fail the run" >&2
  fail=1
fi

[[ $fail -eq 0 ]] && echo "post-render: fixtures OK"
exit "$fail"
