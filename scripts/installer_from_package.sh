#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo "  WORBI Installer"
echo "============================================="
echo ""

NODE_VERSION="${WORBI_NODE_VERSION:-18.20.8}"
export PATH="$HOME/.local/bin:$PATH"

install_local_node() {
  echo "Installing Node.js ${NODE_VERSION} to ~/.local (no sudo)..."
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH" >&2; exit 1 ;;
  esac
  NODE_TAR="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}" -o "/tmp/${NODE_TAR}"
  mkdir -p "$HOME/.local"
  tar -xJf "/tmp/${NODE_TAR}" -C "$HOME/.local" --strip-components=1
  rm -f "/tmp/${NODE_TAR}"
  echo "Node.js installed: $(node --version)"
}

if [[ -x "$HOME/.local/bin/node" ]]; then
  echo "Node.js local runtime found: $("$HOME/.local/bin/node" --version)"
else
  install_local_node
fi

INSTALL_DIR="${WORBI_INSTALL_DIR:-$HOME/worbi}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ls "$SCRIPT_DIR"/worbi-*.tar.gz >/dev/null 2>&1; then
  ARCHIVE_PATH="$(ls "$SCRIPT_DIR"/worbi-*.tar.gz | head -1)"
else
  echo "ERROR: Cannot find WORBI package archive (worbi-*.tar.gz)" >&2
  exit 1
fi

echo "Archive: $ARCHIVE_PATH"
echo "Install: $INSTALL_DIR"
echo ""

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR"
STAGE_DIR="$TEMP_DIR/worbi-stage"
PRESERVE_DIR="$TEMP_DIR/preserve"

if [[ -f "$INSTALL_DIR/logs/worbi-server.pid" ]]; then
  echo "Stopping existing WORBI..."
  if command -v worbi-stop >/dev/null 2>&1; then
    worbi-stop 2>/dev/null || true
  fi
fi

if [[ -d "$INSTALL_DIR" ]]; then
  if [[ -f "$INSTALL_DIR/.nymph-module-version" ]]; then
    echo "Existing installation found. Preserving declared user data for in-place refresh..."
    mkdir -p "$PRESERVE_DIR/server/src/data"
    [[ -f "$INSTALL_DIR/server/src/data/users.json" ]] && cp "$INSTALL_DIR/server/src/data/users.json" "$PRESERVE_DIR/server/src/data/" 2>/dev/null || true
    [[ -d "$INSTALL_DIR/server/src/data/user-settings" ]] && cp -r "$INSTALL_DIR/server/src/data/user-settings" "$PRESERVE_DIR/server/src/data/" 2>/dev/null || true
    [[ -d "$INSTALL_DIR/server/src/data/users" ]] && cp -r "$INSTALL_DIR/server/src/data/users" "$PRESERVE_DIR/server/src/data/" 2>/dev/null || true
  else
    echo "Partial WORBI install found. Cleaning runtime folder without creating backups..."
  fi
fi

mkdir -p "$STAGE_DIR"

# Copy new dist (frontend) from archive
cp -r "$TEMP_DIR/worbi/dist" "$STAGE_DIR/"

cp -r "$TEMP_DIR/worbi/server" "$STAGE_DIR/"
cp -r "$TEMP_DIR/worbi/bin" "$STAGE_DIR/"
cp -f "$TEMP_DIR/worbi/package.json" "$STAGE_DIR/" 2>/dev/null || true

# Create symlink: server/dist -> dist (required for Express to find frontend)
ln -sf "$INSTALL_DIR/dist" "$STAGE_DIR/server/dist"

if [[ -d "${PRESERVE_DIR}/server/src/data" ]]; then
  [[ -f "$PRESERVE_DIR/server/src/data/users.json" ]] && cp "$PRESERVE_DIR/server/src/data/users.json" "$STAGE_DIR/server/src/data/" 2>/dev/null || true
  [[ -d "$PRESERVE_DIR/server/src/data/user-settings" ]] && cp -r "$PRESERVE_DIR/server/src/data/user-settings" "$STAGE_DIR/server/src/data/" 2>/dev/null || true
  [[ -d "$PRESERVE_DIR/server/src/data/users" ]] && cp -r "$PRESERVE_DIR/server/src/data/users" "$STAGE_DIR/server/src/data/" 2>/dev/null || true
fi

mkdir -p "$STAGE_DIR/logs"
mkdir -p "$STAGE_DIR/server/src/data"
mkdir -p "$STAGE_DIR/server/src/data/user-settings"
mkdir -p "$STAGE_DIR/server/src/data/users"

echo ""
NPM_TIMEOUT_SECONDS="${NYMPHS_WORBI_NPM_TIMEOUT_SECONDS:-240}"
echo "Installing production server dependencies (timeout: ${NPM_TIMEOUT_SECONDS}s)..."
if command -v timeout >/dev/null 2>&1; then
  (cd "$STAGE_DIR/server" && timeout "${NPM_TIMEOUT_SECONDS}s" npm install --omit=dev --no-audit --no-fund --loglevel=warn)
else
  (cd "$STAGE_DIR/server" && npm install --omit=dev --no-audit --no-fund --loglevel=warn)
fi

rm -rf "$INSTALL_DIR/server" "$INSTALL_DIR/bin" "$INSTALL_DIR/dist" "$INSTALL_DIR/package.json" "$INSTALL_DIR/.nymph-module-version"
mkdir -p "$INSTALL_DIR"
cp -r "$STAGE_DIR/dist" "$INSTALL_DIR/"
cp -r "$STAGE_DIR/server" "$INSTALL_DIR/"
cp -r "$STAGE_DIR/bin" "$INSTALL_DIR/"
cp -f "$STAGE_DIR/package.json" "$INSTALL_DIR/" 2>/dev/null || true
mkdir -p "$INSTALL_DIR/logs"

mkdir -p "$HOME/.local/bin"
cp "$INSTALL_DIR/bin/worbi-start" "$HOME/.local/bin/"
cp "$INSTALL_DIR/bin/worbi-stop" "$HOME/.local/bin/"
cp "$INSTALL_DIR/bin/worbi-status" "$HOME/.local/bin/"
cp "$INSTALL_DIR/bin/worbi-open" "$HOME/.local/bin/" 2>/dev/null || true
cp "$INSTALL_DIR/bin/worbi-logs" "$HOME/.local/bin/" 2>/dev/null || true
chmod +x "$HOME/.local/bin/worbi-start" "$HOME/.local/bin/worbi-stop" "$HOME/.local/bin/worbi-status" "$HOME/.local/bin/worbi-open" "$HOME/.local/bin/worbi-logs" 2>/dev/null || true

echo ""
echo "WORBI installed successfully."
echo "App: http://localhost:8082"
echo "Logs: $INSTALL_DIR/logs/"
