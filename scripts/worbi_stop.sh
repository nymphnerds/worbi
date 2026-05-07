#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-$HOME/worbi}"
LOGS_DIR="${INSTALL_DIR}/logs"
PID_FILE="${LOGS_DIR}/worbi-server.pid"
SERVER_DIR="${INSTALL_DIR}/server"
HEALTH_URL="${WORBI_HEALTH_URL:-http://localhost:8082/api/health}"
PORT="${WORBI_PORT:-8082}"

if [[ "${HEALTH_URL}" =~ :([0-9]+)(/|$) ]]; then
  PORT="${BASH_REMATCH[1]}"
fi

health_ok() {
  curl --max-time 2 -fsS "${HEALTH_URL}" >/dev/null 2>&1
}

pid_running() {
  local pid="$1"
  [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1
}

find_server_pids() {
  local server_dir_resolved
  server_dir_resolved="$(readlink -f "${SERVER_DIR}" 2>/dev/null || true)"
  [[ -n "${server_dir_resolved}" ]] || return 0

  local install_dir_resolved
  install_dir_resolved="$(readlink -f "${INSTALL_DIR}" 2>/dev/null || true)"

  while read -r pid args; do
    [[ -n "${pid}" ]] || continue
    local cwd
    cwd="$(readlink -f "/proc/${pid}/cwd" 2>/dev/null || true)"
    if [[ "${cwd}" == "${server_dir_resolved}" ]] ||
      [[ "${args}" == *"${server_dir_resolved}/src/index.js"* ]] ||
      [[ "${args}" == *"${install_dir_resolved}/server/src/index.js"* ]] ||
      [[ "${args}" == *"node src/index.js"* && "${args}" == *"worbi"* ]]; then
      echo "${pid}"
    fi
  done < <(ps -eo pid=,args= 2>/dev/null | awk '/node/ && /src\/index\.js/ {print $0}')
}

find_port_pids() {
  if command -v ss >/dev/null 2>&1; then
    ss -H -ltnp "sport = :${PORT}" 2>/dev/null \
      | sed -n 's/.*pid=\([0-9]\+\).*/\1/p'
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -ti "tcp:${PORT}" -sTCP:LISTEN 2>/dev/null || true
  fi

  if command -v fuser >/dev/null 2>&1; then
    fuser -n tcp "${PORT}" 2>/dev/null || true
  fi
}

stop_pid() {
  local pid="$1"
  pid_running "${pid}" || return 0

  echo "Stopping WORBI server (PID: ${pid})..."
  kill "${pid}" >/dev/null 2>&1 || true

  for _ in $(seq 1 20); do
    if ! pid_running "${pid}"; then
      return 0
    fi
    sleep 0.25
  done

  kill -KILL "${pid}" >/dev/null 2>&1 || true
}

pids=()

if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if pid_running "${pid}"; then
    pids+=("${pid}")
  fi
fi

while IFS= read -r pid; do
  [[ -n "${pid}" ]] || continue
  pids+=("${pid}")
done < <(find_server_pids)

while IFS= read -r pid; do
  [[ -n "${pid}" ]] || continue
  pids+=("${pid}")
done < <(find_port_pids)

unique_pids=()
for pid in "${pids[@]}"; do
  seen=false
  for existing in "${unique_pids[@]}"; do
    if [[ "${existing}" == "${pid}" ]]; then
      seen=true
      break
    fi
  done
  if [[ "${seen}" == "false" ]]; then
    unique_pids+=("${pid}")
  fi
done

if [[ "${#unique_pids[@]}" -eq 0 ]]; then
  rm -f "${PID_FILE}"
  if health_ok; then
    echo "ERROR: WORBI is responding on port ${PORT}, but no matching server process was found." >&2
    exit 1
  fi
  echo "WORBI is not running."
  exit 0
fi

for pid in "${unique_pids[@]}"; do
  stop_pid "${pid}"
done

rm -f "${PID_FILE}"

for _ in $(seq 1 20); do
  if ! health_ok; then
    echo "WORBI stopped."
    exit 0
  fi
  sleep 0.25
done

echo "ERROR: WORBI still responds after stop." >&2
exit 1
