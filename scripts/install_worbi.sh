#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALLER_DIR="$(mktemp -d)"
trap 'rm -rf "${INSTALLER_DIR}"' EXIT

archive_rel="$(python3 - "${REPO_DIR}/nymph.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

archive = str(manifest.get("source", {}).get("archive", "")).strip()
if not archive:
    raise SystemExit("nymph.json source.archive is missing")
if archive.startswith("/") or ".." in archive.split("/"):
    raise SystemExit("nymph.json source.archive must be a safe relative path")
print(archive)
PY
)"
archive="${REPO_DIR}/${archive_rel}"
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
