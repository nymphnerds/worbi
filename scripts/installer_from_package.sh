#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo "  WORBI Installer"
echo "============================================="
echo ""

if command -v node >/dev/null 2>&1; then
  echo "Node.js found: $(node --version)"
else
  echo "Node.js not found. Installing to ~/.local (no sudo)..."
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH" >&2; exit 1 ;;
  esac
  NODE_VERSION="18.20.8"
  NODE_TAR="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}" -o "/tmp/${NODE_TAR}"
  mkdir -p "$HOME/.local"
  tar -xJf "/tmp/${NODE_TAR}" -C "$HOME/.local" --strip-components=1
  rm -f "/tmp/${NODE_TAR}"
  export PATH="$HOME/.local/bin:$PATH"
  echo "Node.js installed: $(node --version)"
fi

INSTALL_DIR="$HOME/worbi"
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
PRESERVE_DIR="$TEMP_DIR/preserve"
mkdir -p "$PRESERVE_DIR"

if [[ -f "$INSTALL_DIR/logs/worbi-server.pid" ]]; then
  echo "Stopping existing WORBI..."
  if command -v worbi-stop >/dev/null 2>&1; then
    worbi-stop 2>/dev/null || true
  fi
fi

if [[ -d "$INSTALL_DIR" ]]; then
  echo "Existing installation found. Preserving user data in temporary staging..."
  [[ -f "$INSTALL_DIR/server/src/data/users.json" ]] && cp "$INSTALL_DIR/server/src/data/users.json" "$PRESERVE_DIR/" 2>/dev/null || true
  [[ -d "$INSTALL_DIR/server/src/data/user-settings" ]] && cp -r "$INSTALL_DIR/server/src/data/user-settings" "$PRESERVE_DIR/" 2>/dev/null || true
  [[ -d "$INSTALL_DIR/server/src/data/users" ]] && cp -r "$INSTALL_DIR/server/src/data/users" "$PRESERVE_DIR/" 2>/dev/null || true
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/server" "$INSTALL_DIR/bin" "$INSTALL_DIR/dist"

cp -r "$TEMP_DIR/worbi/server" "$INSTALL_DIR/"
cp -r "$TEMP_DIR/worbi/bin" "$INSTALL_DIR/"
cp -r "$TEMP_DIR/worbi/dist" "$INSTALL_DIR/"
# Server looks for dist at server/dist (relative to server/src/index.js)
# Create symlink so server finds the frontend
ln -sf "$INSTALL_DIR/dist" "$INSTALL_DIR/server/dist"
cp -f "$TEMP_DIR/worbi/package.json" "$INSTALL_DIR/" 2>/dev/null || true

mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/server/src/data"
mkdir -p "$INSTALL_DIR/server/src/data/user-settings"
mkdir -p "$INSTALL_DIR/server/src/data/users"
[[ -f "$PRESERVE_DIR/users.json" ]] && cp "$PRESERVE_DIR/users.json" "$INSTALL_DIR/server/src/data/" 2>/dev/null || true
[[ -d "$PRESERVE_DIR/user-settings" ]] && cp -r "$PRESERVE_DIR/user-settings" "$INSTALL_DIR/server/src/data/" 2>/dev/null || true
[[ -d "$PRESERVE_DIR/users" ]] && cp -r "$PRESERVE_DIR/users" "$INSTALL_DIR/server/src/data/" 2>/dev/null || true

legacy_backup_count="$(find "$HOME" -maxdepth 1 -type d -name 'worbi.backup.*' | wc -l | tr -d ' ')"
if [[ "${legacy_backup_count}" != "0" ]]; then
  find "$HOME" -maxdepth 1 -type d -name 'worbi.backup.*' -exec rm -rf {} + 2>/dev/null || true
  echo "Removed ${legacy_backup_count} old WORBI home backup folder(s)."
fi

echo ""
echo "Installing server dependencies..."
(cd "$INSTALL_DIR/server" && npm install --omit=dev --no-audit --no-fund --loglevel=error)

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
