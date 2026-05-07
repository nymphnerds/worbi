#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

if command -v worbi-stop >/dev/null 2>&1; then
  exec worbi-stop
fi

if [[ -x "$HOME/worbi/bin/worbi-stop" ]]; then
  exec "$HOME/worbi/bin/worbi-stop"
fi

echo "WORBI is not installed."
exit 0
