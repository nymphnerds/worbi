#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${WORBI_INSTALL_ROOT:-$HOME/worbi}"
PURGE=0
DATA_ONLY=0
DRY_RUN=0
YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) PURGE=1; shift ;;
    --data-only) DATA_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: worbi_uninstall.sh [--dry-run] [--yes] [--purge] [--data-only]

Default uninstall removes WORBI runtime files but preserves data, projects,
config, and logs when those folders exist.
--purge removes the whole install root.
--data-only deletes WORBI data, projects, config, and logs while keeping the runtime.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "${PURGE}" -eq 1 && "${DATA_ONLY}" -eq 1 ]]; then
  echo "Choose only one of --purge or --data-only." >&2
  exit 2
fi

echo "WORBI uninstall plan"
echo "install_root=${INSTALL_ROOT}"
if [[ "${DATA_ONLY}" -eq 1 ]]; then
  echo "mode=data-only"
  echo "delete=${INSTALL_ROOT}/data"
  echo "delete=${INSTALL_ROOT}/projects"
  echo "delete=${INSTALL_ROOT}/config"
  echo "delete=${INSTALL_ROOT}/logs"
  echo "preserve=${INSTALL_ROOT}"
elif [[ "${PURGE}" -eq 1 ]]; then
  echo "mode=purge"
  echo "delete=${INSTALL_ROOT}"
else
  echo "mode=uninstall"
  echo "delete=runtime files inside ${INSTALL_ROOT}"
  echo "preserve=${INSTALL_ROOT}/data"
  echo "preserve=${INSTALL_ROOT}/projects"
  echo "preserve=${INSTALL_ROOT}/config"
  echo "preserve=${INSTALL_ROOT}/logs"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  exit 0
fi

if [[ "${YES}" -ne 1 ]]; then
  echo "Refusing to delete without --yes. Run with --dry-run first to preview." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/worbi_stop.sh" || true

if [[ ! -d "${INSTALL_ROOT}" ]]; then
  echo "WORBI is already uninstalled."
  exit 0
fi

if [[ "${DATA_ONLY}" -eq 1 ]]; then
  rm -rf \
    "${INSTALL_ROOT}/data" \
    "${INSTALL_ROOT}/projects" \
    "${INSTALL_ROOT}/config" \
    "${INSTALL_ROOT}/logs"
elif [[ "${PURGE}" -eq 1 ]]; then
  rm -rf "${INSTALL_ROOT}"
else
  find "${INSTALL_ROOT}" -mindepth 1 \
    ! -name data \
    ! -name projects \
    ! -name config \
    ! -name logs \
    -exec rm -rf {} +
fi

if [[ "${DATA_ONLY}" -eq 1 ]]; then
  echo "WORBI data deleted."
else
  echo "WORBI uninstalled."
fi
