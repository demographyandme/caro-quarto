#!/usr/bin/env bash
# Copy canonical CARO extension into a consumer site/_extensions/caro-quarto/.
# Source after ROOT (consumer site/ dir) and CARO_QUARTO_SRC are exported.

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
}
