#!/usr/bin/env bash
# Execute com: bash scripts/setup.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# A imagem devcontainer já fornece Python 3.12. Este fallback atende Debian/Ubuntu.
if ! command -v python3 >/dev/null 2>&1; then
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "Instale Python 3.11+ ou use Codespaces: Rebuild Container."
        exit 1
    fi
    if [ "$(id -u)" -eq 0 ]; then
        apt-get update
        apt-get install -y python3 python3-venv
    else
        sudo apt-get update
        sudo apt-get install -y python3 python3-venv
    fi
fi
python3 -c 'import sys; assert sys.version_info >= (3, 11), "Use Python 3.11+ ou reconstrua o devcontainer"'
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements-dev.txt
if [ ! -e .env ]; then
    cp .env.example .env
fi
printf '\nAmbiente pronto. Ative: source .venv/bin/activate\n'
printf 'Teste sem chave: python -m examples.demo\n'
printf 'Validação: bash scripts/test.sh\n'
