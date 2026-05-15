#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-${WORBI_INSTALL_DIR:-$HOME/worbi}}"
DATA_DIR="${INSTALL_DIR}/data"

mkdir -p "${DATA_DIR}"
echo "directory=${DATA_DIR}"
