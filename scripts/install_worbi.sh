#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALLER_DIR="$(mktemp -d)"
trap 'rm -rf "${INSTALLER_DIR}"' EXIT

archive="${REPO_DIR}/packages/worbi-6.2.49.tar.gz"
if [[ ! -f "${archive}" ]]; then
  echo "ERROR: WORBI archive missing: ${archive}" >&2
  exit 1
fi

cp "${archive}" "${INSTALLER_DIR}/"
cp "${SCRIPT_DIR}/installer_from_package.sh" "${INSTALLER_DIR}/install.sh"
chmod +x "${INSTALLER_DIR}/install.sh"

"${INSTALLER_DIR}/install.sh"

install -m 755 "${SCRIPT_DIR}/worbi_status.sh" "${HOME}/.local/bin/worbi-status"
install -m 755 "${SCRIPT_DIR}/worbi_status.sh" "${HOME}/worbi/bin/worbi-status"
