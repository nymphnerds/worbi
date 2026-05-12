#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-${WORBI_INSTALL_DIR:-$HOME/worbi}}"
LOGS_DIR="${INSTALL_DIR}/logs"
MARKER_FILE="${INSTALL_DIR}/.nymph-module-version"
SERVER_PID_FILE="${LOGS_DIR}/worbi-server.pid"
FRONTEND_URL="${WORBI_FRONTEND_URL:-http://localhost:8082}"
BACKEND_URL="${WORBI_BACKEND_URL:-http://localhost:8082}"
HEALTH_URL="${WORBI_HEALTH_URL:-http://localhost:8082/api/health}"
SERVER_DIR="${INSTALL_DIR}/server"
PORT="${WORBI_PORT:-8082}"

if [[ "${HEALTH_URL}" =~ :([0-9]+)(/|$) ]]; then
  PORT="${BASH_REMATCH[1]}"
fi

pid_running() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 1
  local pid=""
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

find_server_pids() {
  local server_dir_resolved
  server_dir_resolved="$(readlink -f "${SERVER_DIR}" 2>/dev/null || true)"

  local install_dir_resolved
  install_dir_resolved="$(readlink -f "${INSTALL_DIR}" 2>/dev/null || true)"

  while read -r pid args; do
    [[ -n "${pid}" ]] || continue
    local cwd
    cwd="$(readlink -f "/proc/${pid}/cwd" 2>/dev/null || true)"
    if [[ -n "${server_dir_resolved}" && "${cwd}" == "${server_dir_resolved}" ]] ||
      [[ -n "${install_dir_resolved}" && "${cwd}" == "${install_dir_resolved}"* ]] ||
      [[ -n "${server_dir_resolved}" && "${args}" == *"${server_dir_resolved}/src/index.js"* ]] ||
      [[ -n "${install_dir_resolved}" && "${args}" == *"${install_dir_resolved}/server/src/index.js"* ]] ||
      [[ "${args}" == *"node"* && "${args}" == *"src/index.js"* && "${args}" == *"worbi"* ]]; then
      echo "${pid}"
    fi
  done < <(ps -eo pid=,args= 2>/dev/null | awk '/node/ {print $0}')
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

installed=false
runtime_present=false
data_present=false
version=not-installed
backend=stopped
frontend=stopped
health=unknown

if [[ -f "$MARKER_FILE" ]]; then
  installed=true
  runtime_present=true
  version="$(head -n 1 "$MARKER_FILE" 2>/dev/null || true)"
  [[ -n "$version" ]] || version=unknown
fi

if [[ -d "$INSTALL_DIR/data" || -d "$INSTALL_DIR/projects" || -d "$INSTALL_DIR/config" || -d "$INSTALL_DIR/logs" ]]; then
  data_present=true
fi

if pid_running "$SERVER_PID_FILE"; then
  backend=running
  frontend=running
fi

if curl --max-time 2 -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  health=ok
  if [[ "$backend" != "running" ]]; then
    unmanaged_pid="$({ find_server_pids; find_port_pids; } | head -n 1 || true)"
    if [[ -n "$unmanaged_pid" ]]; then
      backend=running-unmanaged
      frontend=running-unmanaged
    else
      backend=responding
      frontend=responding
    fi
  fi
elif [[ "$backend" == "running" ]]; then
  health=unreachable
fi

running=false
if [[ "$backend" == "running" || "$backend" == "running-unmanaged" || "$backend" == "responding" ]]; then
  running=true
fi

state=available
detail="WORBI is not installed."
if [[ "$installed" == "true" && "$running" == "false" ]]; then
  state=installed
  detail="WORBI is installed but stopped."
elif [[ "$installed" == "true" && "$backend" == "running-unmanaged" ]]; then
  state=running
  detail="WORBI is running. PID tracking was not available for this session."
elif [[ "$installed" == "true" && "$backend" == "responding" ]]; then
  state=running
  detail="WORBI is responding. Process ownership was not identified, so stop will use the port fallback."
elif [[ "$installed" == "true" && "$running" == "true" ]]; then
  state=running
  detail="WORBI is running."
elif [[ "$installed" == "false" && "$data_present" == "true" ]]; then
  detail="WORBI user data remains, but runtime files are not installed."
  health=unavailable
fi

cat <<STATUS
id=worbi
installed=${installed}
runtime_present=${runtime_present}
data_present=${data_present}
version=${version}
running=${running}
state=${state}
backend=${backend}
frontend=${frontend}
url=${FRONTEND_URL}
frontend_url=${FRONTEND_URL}
backend_url=${BACKEND_URL}
health=${health}
install_root=${INSTALL_DIR}
logs_dir=${LOGS_DIR}
marker=${MARKER_FILE}
detail=${detail}
STATUS
