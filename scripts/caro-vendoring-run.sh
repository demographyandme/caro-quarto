#!/usr/bin/env bash
# Resolve and source scripts/vendoring.sh from CARO_QUARTO_SRC, then copy the extension tree.
# Canonical copy: caro-quarto/scripts/caro-vendoring-run.sh
# Main-site mirror: my-academic-website/scripts/companion/caro-vendoring.sh

caro_vendoring_run() {
  : "${ROOT:?caro_vendoring_run requires ROOT}"
  if [[ -z "${CARO_QUARTO_SRC:-}" || ! -d "${CARO_QUARTO_SRC}" ]]; then
    return 0
  fi

  local _candidate _vend=""
  for _candidate in \
    "${CARO_QUARTO_SRC}" \
    "$(cd "${CARO_QUARTO_SRC}/.." 2>/dev/null && pwd || true)" \
    "$(cd "${CARO_QUARTO_SRC}/../.." 2>/dev/null && pwd || true)"; do
    [[ -z "${_candidate}" ]] && continue
    if [[ -f "${_candidate}/scripts/vendoring.sh" ]]; then
      _vend="${_candidate}/scripts/vendoring.sh"
      break
    fi
  done

  if [[ -z "${_vend}" ]]; then
    echo "caro-vendoring: could not find scripts/vendoring.sh under CARO_QUARTO_SRC=${CARO_QUARTO_SRC}" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "${_vend}"
  caro_vendoring_copy
}
