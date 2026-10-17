#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [ ! -x .venv/bin/python ]; then
    echo "Execute primeiro: bash scripts/setup.sh"
    exit 1
fi
.venv/bin/python -m ruff check .
.venv/bin/python -m pytest -q
.venv/bin/python -m examples.demo
