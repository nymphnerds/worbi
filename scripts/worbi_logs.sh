#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-${WORBI_INSTALL_DIR:-$HOME/worbi}}"
LOGS_DIR="${INSTALL_DIR}/logs"
LAST_LOG="${LOGS_DIR}/worbi-server.log"

mkdir -p "${LOGS_DIR}"
touch "${LAST_LOG}"

echo "logs_dir=${LOGS_DIR}"
echo "last_log=${LAST_LOG}"
echo "server_log=${LOGS_DIR}/worbi-server.log"
echo "client_log=${LOGS_DIR}/worbi-client.log"

if [[ -f "${LOGS_DIR}/worbi-server.log" ]]; then
  echo ""
  echo "== server =="
  tail -80 "${LOGS_DIR}/worbi-server.log"
fi

if [[ -f "${LOGS_DIR}/worbi-client.log" ]]; then
  echo ""
  echo "== client =="
  tail -80 "${LOGS_DIR}/worbi-client.log"
fi
