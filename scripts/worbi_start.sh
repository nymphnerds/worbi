#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-$HOME/worbi}"
LOGS_DIR="${INSTALL_DIR}/logs"
PID_FILE="${LOGS_DIR}/worbi-server.pid"
APP_URL="${WORBI_FRONTEND_URL:-http://localhost:8082}"
HEALTH_URL="${WORBI_HEALTH_URL:-http://localhost:8082/api/health}"

mkdir -p "${LOGS_DIR}"

if [[ ! -f "${INSTALL_DIR}/server/src/index.js" ]]; then
  echo "ERROR: WORBI server entrypoint is missing: ${INSTALL_DIR}/server/src/index.js" >&2
  exit 1
fi

if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
    echo "WORBI is already running (PID: ${pid})"
    echo "App: ${APP_URL}"
    exit 0
  fi
fi

echo "Starting WORBI server..."
(
  cd "${INSTALL_DIR}/server"
  nohup node src/index.js > "${LOGS_DIR}/worbi-server.log" 2>&1 &
  echo "$!" > "${PID_FILE}"
)

pid="$(cat "${PID_FILE}")"
for _ in $(seq 1 30); do
  if curl --max-time 2 -fsS "${HEALTH_URL}" >/dev/null 2>&1; then
    echo "WORBI started (PID: ${pid})"
    echo "App: ${APP_URL}"
    exit 0
  fi

  if ! kill -0 "${pid}" >/dev/null 2>&1; then
    echo "ERROR: Server failed to start" >&2
    tail -40 "${LOGS_DIR}/worbi-server.log" >&2 || true
    exit 1
  fi

  sleep 1
done

echo "WARNING: Server started but did not respond yet."
echo "App: ${APP_URL}"
echo "Logs: ${LOGS_DIR}/worbi-server.log"
