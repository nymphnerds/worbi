#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${WORBI_INSTALL_DIR:-${HOME}/worbi}"

if [[ ! -f "${INSTALL_DIR}/.nymph-module-version" ]]; then
  echo "WORBI is not installed yet. Use Install first." >&2
  exit 2
fi

module_version="$(python3 - "${REPO_DIR}/nymph.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

print(str(manifest.get("version", "unknown")).strip() or "unknown")
PY
)"

install -m 644 "${REPO_DIR}/nymph.json" "${INSTALL_DIR}/nymph.json"
mkdir -p "${INSTALL_DIR}/scripts" "${INSTALL_DIR}/bin" "${HOME}/.local/bin"
install -m 755 "${SCRIPT_DIR}"/worbi_*.sh "${INSTALL_DIR}/scripts/"

for wrapper in start stop status open logs open_data; do
  install -m 755 "${SCRIPT_DIR}/worbi_${wrapper}.sh" "${HOME}/.local/bin/worbi-${wrapper}"
  install -m 755 "${SCRIPT_DIR}/worbi_${wrapper}.sh" "${INSTALL_DIR}/bin/worbi-${wrapper}"
done

printf '%s\n' "${module_version}" > "${INSTALL_DIR}/.nymph-module-version"

echo "WORBI module wrappers updated."
echo "installed_version=${module_version}"
