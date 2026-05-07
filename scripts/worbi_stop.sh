#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-$HOME/worbi}"
LOGS_DIR="${INSTALL_DIR}/logs"
PID_FILE="${LOGS_DIR}/worbi-server.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "WORBI is not running."
  exit 0
fi

pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
if [[ -z "${pid}" ]] || ! kill -0 "${pid}" >/dev/null 2>&1; then
  rm -f "${PID_FILE}"
  echo "WORBI is not running."
  exit 0
fi

echo "Stopping WORBI server (PID: ${pid})..."
kill "${pid}" >/dev/null 2>&1 || true

for _ in $(seq 1 20); do
  if ! kill -0 "${pid}" >/dev/null 2>&1; then
    rm -f "${PID_FILE}"
    echo "WORBI stopped."
    exit 0
  fi
  sleep 0.25
done

kill -KILL "${pid}" >/dev/null 2>&1 || true
rm -f "${PID_FILE}"
echo "WORBI stopped."
