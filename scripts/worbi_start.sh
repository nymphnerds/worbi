#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-${WORBI_INSTALL_DIR:-$HOME/worbi}}"
LOGS_DIR="${INSTALL_DIR}/logs"
PID_FILE="${LOGS_DIR}/worbi-server.pid"
APP_URL="${WORBI_FRONTEND_URL:-http://localhost:8082}"
HEALTH_URL="${WORBI_HEALTH_URL:-http://localhost:8082/api/health}"
SERVER_DIR="${INSTALL_DIR}/server"
SERVER_ENTRYPOINT="${SERVER_DIR}/src/index.js"
SERVER_LOG="${LOGS_DIR}/worbi-server.log"

mkdir -p "${LOGS_DIR}"

if [[ ! -f "${SERVER_ENTRYPOINT}" ]]; then
  echo "ERROR: WORBI server entrypoint is missing: ${SERVER_ENTRYPOINT}" >&2
  exit 1
fi

pid_running() {
  local pid="$1"
  [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1
}

health_ok() {
  curl --max-time 2 -fsS "${HEALTH_URL}" >/dev/null 2>&1
}

find_server_pids() {
  local server_dir_resolved
  server_dir_resolved="$(readlink -f "${SERVER_DIR}")"

  for pid in $(pgrep -f "node src/index.js" 2>/dev/null || true); do
    local cwd
    cwd="$(readlink -f "/proc/${pid}/cwd" 2>/dev/null || true)"
    if [[ "${cwd}" == "${server_dir_resolved}" ]]; then
      echo "${pid}"
    fi
  done
}

if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if pid_running "${pid}"; then
    echo "WORBI is already running (PID: ${pid})"
    echo "App: ${APP_URL}"
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

if health_ok; then
  pid="$(find_server_pids | head -n 1 || true)"
  if [[ -n "${pid}" ]]; then
    echo "${pid}" > "${PID_FILE}"
    echo "WORBI is already running (PID: ${pid})"
  else
    echo "WORBI is already responding, but PID tracking is unavailable."
  fi
  echo "App: ${APP_URL}"
  exit 0
fi

echo "Starting WORBI server..."
(
  cd "${SERVER_DIR}"
  if command -v setsid >/dev/null 2>&1; then
    setsid -f bash -c 'echo $$ > "$1"; exec node src/index.js > "$2" 2>&1' _ "${PID_FILE}" "${SERVER_LOG}"
  else
    nohup bash -c 'echo $$ > "$1"; exec node src/index.js > "$2" 2>&1' _ "${PID_FILE}" "${SERVER_LOG}" >/dev/null 2>&1 &
  fi
)

pid=""
for _ in $(seq 1 20); do
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && break
  sleep 0.1
done

for _ in $(seq 1 30); do
  if health_ok; then
    if ! pid_running "${pid}"; then
      pid="$(find_server_pids | head -n 1 || true)"
      [[ -n "${pid}" ]] && echo "${pid}" > "${PID_FILE}"
    fi
    echo "WORBI started (PID: ${pid})"
    echo "App: ${APP_URL}"
    exit 0
  fi

  if [[ -n "${pid}" ]] && ! pid_running "${pid}"; then
    echo "ERROR: Server failed to start" >&2
    tail -40 "${SERVER_LOG}" >&2 || true
    exit 1
  fi

  sleep 1
done

echo "WARNING: Server started but did not respond yet."
echo "App: ${APP_URL}"
echo "Logs: ${SERVER_LOG}"
