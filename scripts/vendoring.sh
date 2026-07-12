#!/usr/bin/env bash
# Copy canonical CARO into a consumer site/: the extension tree
# (_extensions/caro-quarto/) and the self-hosted fonts (fonts/), which the
# theme references via `css: fonts/fonts.css`. Source after ROOT (consumer
# site/ dir) and CARO_QUARTO_SRC are exported.

caro_vendoring_copy() {
  if [[ -z "${CARO_QUARTO_SRC:-}" || ! -d "${CARO_QUARTO_SRC}" || -z "${ROOT:-}" ]]; then
    return 0
  fi
  local _src="${CARO_QUARTO_SRC}/_extensions/caro-quarto"
  if [[ ! -d "${_src}" ]]; then
    _src="${CARO_QUARTO_SRC}"
  fi
  mkdir -p "${ROOT}/_extensions/caro-quarto"
  cp -R "${_src}/." "${ROOT}/_extensions/caro-quarto/"

  # Fonts live at the repo root (fonts/), beside — not inside — _extensions/.
  # CARO_QUARTO_SRC may point at the repo root or at the extension dir; resolve
  # both. Vendor to the site root so `css: fonts/fonts.css` resolves.
  local _cand _fonts=""
  for _cand in "${CARO_QUARTO_SRC}/fonts" "${CARO_QUARTO_SRC}/../../fonts"; do
    if [[ -d "${_cand}" ]]; then _fonts="${_cand}"; break; fi
  done
  if [[ -n "${_fonts}" ]]; then
    mkdir -p "${ROOT}/fonts"
    cp -R "${_fonts}/." "${ROOT}/fonts/"
  fi
}
