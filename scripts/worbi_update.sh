#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${WORBI_INSTALL_DIR:-${HOME}/worbi}"
NODE_VERSION="${WORBI_NODE_VERSION:-18.20.8}"

export PATH="${HOME}/.local/bin:${PATH}"

ensure_local_node_runtime() {
  local arch node_arch node_tar
  if [[ -x "${HOME}/.local/bin/node" ]]; then
    echo "Node.js local runtime found: $("${HOME}/.local/bin/node" --version)"
    return 0
  fi

  echo "Installing Node.js ${NODE_VERSION} to ${HOME}/.local..."
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) node_arch="x64" ;;
    aarch64|arm64) node_arch="arm64" ;;
    *) echo "ERROR: Unsupported Node.js architecture: ${arch}" >&2; exit 1 ;;
  esac

  node_tar="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${node_tar}" -o "/tmp/${node_tar}"
  mkdir -p "${HOME}/.local"
  tar -xJf "/tmp/${node_tar}" -C "${HOME}/.local" --strip-components=1
  rm -f "/tmp/${node_tar}"
  echo "Node.js installed: $(node --version)"
}

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

ensure_local_node_runtime

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
