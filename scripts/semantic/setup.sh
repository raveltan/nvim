#!/usr/bin/env bash
# Create venv + install numpy for semantic search scripts.
# Idempotent: safe to re-run.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$DIR/.venv"

if [[ ! -d "$VENV" ]]; then
  echo "Creating venv at $VENV"
  python3 -m venv "$VENV"
fi

"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r "$DIR/requirements.txt"

echo "OK. Python: $VENV/bin/python3"
"$VENV/bin/python3" -c "import numpy; print('numpy', numpy.__version__)"
