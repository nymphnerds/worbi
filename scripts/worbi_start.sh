#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

if command -v worbi-start >/dev/null 2>&1; then
  exec worbi-start
fi

if [[ -x "$HOME/worbi/bin/worbi-start" ]]; then
  exec "$HOME/worbi/bin/worbi-start"
fi

echo "ERROR: worbi-start not found. Install WORBI first." >&2
exit 1
