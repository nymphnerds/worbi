#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${WORBI_INSTALL_ROOT:-$HOME/worbi}"
LOGS_DIR="${INSTALL_DIR}/logs"
SERVER_PID_FILE="${LOGS_DIR}/worbi-server.pid"
FRONTEND_URL="${WORBI_FRONTEND_URL:-http://localhost:8082}"
BACKEND_URL="${WORBI_BACKEND_URL:-http://localhost:8082}"
HEALTH_URL="${WORBI_HEALTH_URL:-http://localhost:8082/api/health}"
SERVER_DIR="${INSTALL_DIR}/server"

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
  [[ -n "${server_dir_resolved}" ]] || return 0

  for pid in $(pgrep -f "node src/index.js" 2>/dev/null || true); do
    local cwd
    cwd="$(readlink -f "/proc/${pid}/cwd" 2>/dev/null || true)"
    if [[ "${cwd}" == "${server_dir_resolved}" ]]; then
      echo "${pid}"
    fi
  done
}

installed=false
version=unknown
backend=stopped
frontend=stopped
health=unknown

if [[ -d "$INSTALL_DIR" ]]; then
  installed=true
fi

if [[ -f "$INSTALL_DIR/.nymph-module-version" ]]; then
  version="$(head -n 1 "$INSTALL_DIR/.nymph-module-version" 2>/dev/null || echo unknown)"
elif [[ -f "$INSTALL_DIR/package.json" ]]; then
  version="$(node -e "const p=require(process.argv[1]); console.log(p.version || 'unknown')" "$INSTALL_DIR/package.json" 2>/dev/null || echo unknown)"
elif [[ -f "$INSTALL_DIR/server/package.json" ]]; then
  version="$(node -e "const p=require(process.argv[1]); console.log(p.version || 'unknown')" "$INSTALL_DIR/server/package.json" 2>/dev/null || echo unknown)"
fi

if pid_running "$SERVER_PID_FILE"; then
  backend=running
  frontend=running
fi

if curl --max-time 2 -fsS "$HEALTH_URL" >/dev/null 2>&1; then
  health=ok
  if [[ "$backend" != "running" ]]; then
    unmanaged_pid="$(find_server_pids | head -n 1 || true)"
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

detail="WORBI is not installed."
if [[ "$installed" == "true" && "$running" == "false" ]]; then
  detail="WORBI is installed but stopped."
elif [[ "$installed" == "true" && "$backend" == "running-unmanaged" ]]; then
  detail="WORBI is running, but PID tracking is missing."
elif [[ "$installed" == "true" && "$backend" == "responding" ]]; then
  detail="WORBI is responding, but no managed process could be identified."
elif [[ "$installed" == "true" && "$running" == "true" ]]; then
  detail="WORBI is running."
fi

cat <<STATUS
installed=${installed}
version=${version}
running=${running}
backend=${backend}
frontend=${frontend}
url=${FRONTEND_URL}
frontend_url=${FRONTEND_URL}
backend_url=${BACKEND_URL}
health=${health}
install_root=${INSTALL_DIR}
logs_dir=${LOGS_DIR}
detail=${detail}
STATUS
