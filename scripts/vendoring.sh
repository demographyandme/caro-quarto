#!/usr/bin/env bash
# Copy canonical CARO into a consumer site/: the extension tree
# (_extensions/caro-quarto/) and the self-hosted fonts (fonts/), which the
# theme references via `css: fonts/fonts.css`. Source after ROOT (consumer
# site/ dir) and CARO_QUARTO_SRC are exported. CARO_QUARTO_SRC is the
# caro-quarto checkout, or its _extensions/caro-quarto/ folder.
#
# Nothing in the site is touched until the source is proven to be CARO (its
# _extension.yml says `title: CARO Theme` and fonts/fonts.css exists beside it)
# and source and site do not contain one another. Each tree is copied into a
# temporary sibling first and moved into place only after the copy succeeded,
# so a failed copy leaves the site's previous theme as it was.

_caro_vendoring_fail() {
  echo "caro vendoring: $*" >&2
  return 1
}

# Physical path of an existing directory.
_caro_vendoring_real() {
  (cd "$1" 2>/dev/null && pwd -P)
}

# True when one path is the other or lies inside it.
_caro_vendoring_nested() {
  [[ "$1" == "$2" || "$1" == "$2"/* || "$2" == "$1"/* ]]
}

# Mirror directory $1 into $2 (created or replaced), via a temporary sibling.
_caro_vendoring_mirror() {
  local _from="$1" _to="$2" _tmp
  mkdir -p "$(dirname "${_to}")" || return 1
  _tmp=$(mktemp -d "$(dirname "${_to}")/.caro-vendoring.XXXXXX") || return 1
  if ! cp -R "${_from}/." "${_tmp}/"; then
    rm -rf "${_tmp}"
    _caro_vendoring_fail "copying ${_from} failed; ${_to} left as it was"
    return 1
  fi
  rm -rf "${_to}" && mv "${_tmp}" "${_to}"
}

caro_vendoring_copy() {
  if [[ -z "${CARO_QUARTO_SRC:-}" || ! -d "${CARO_QUARTO_SRC}" || -z "${ROOT:-}" ]]; then
    return 0
  fi

  # Resolve the repository root explicitly: the checkout itself, or two levels
  # up from its _extensions/caro-quarto/ folder (and that folder must be it).
  local _repo _src
  _src=$(_caro_vendoring_real "${CARO_QUARTO_SRC}") || return 1
  if [[ -f "${_src}/_extensions/caro-quarto/_extension.yml" ]]; then
    _repo="${_src}"
  elif [[ -f "${_src}/_extension.yml" && "$(_caro_vendoring_real "${_src}/../../_extensions/caro-quarto")" == "${_src}" ]]; then
    _repo=$(_caro_vendoring_real "${_src}/../..")
  else
    _caro_vendoring_fail "CARO_QUARTO_SRC=${CARO_QUARTO_SRC} is not a caro-quarto checkout (no _extensions/caro-quarto/_extension.yml)"
    return 1
  fi
  local _ext="${_repo}/_extensions/caro-quarto" _fonts="${_repo}/fonts"
  grep -qx 'title: CARO Theme' "${_ext}/_extension.yml" \
    || { _caro_vendoring_fail "${_ext}/_extension.yml is not the CARO theme (no 'title: CARO Theme')"; return 1; }
  [[ -f "${_fonts}/fonts.css" ]] \
    || { _caro_vendoring_fail "${_fonts}/fonts.css missing: the theme ships its fonts beside _extensions/"; return 1; }

  local _site
  _site=$(_caro_vendoring_real "${ROOT}") || { _caro_vendoring_fail "ROOT=${ROOT} is not a directory"; return 1; }
  if [[ "${_site}/_extensions/caro-quarto" == "${_ext}" ]]; then
    echo "caro vendoring: source and target are the same folder; nothing to do" >&2
    return 0
  fi
  # A target inside its source (or the reverse) would be deleted while copied.
  if _caro_vendoring_nested "${_site}/_extensions/caro-quarto" "${_ext}" || _caro_vendoring_nested "${_site}/fonts" "${_fonts}"; then
    _caro_vendoring_fail "source ${_repo} and site ${_site} overlap (one contains the other); refusing to mirror"
    return 1
  fi

  # Mirror, not overlay: a file removed or renamed upstream must not linger in
  # the site (1.4.0 renamed every font file).
  _caro_vendoring_mirror "${_ext}" "${_site}/_extensions/caro-quarto" || return 1
  _caro_vendoring_mirror "${_fonts}" "${_site}/fonts" || return 1
}
