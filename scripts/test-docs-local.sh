#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Preparing Python virtual environment (.venv-docs)"
if [[ ! -d .venv-docs ]]; then
  python3 -m venv .venv-docs
fi
source .venv-docs/bin/activate

echo "==> Installing MkDocs dependencies"
pip install -q -r mkdocs.yml/requirements.txt

echo "==> Building site"
mkdocs build -f mkdocs.yml/mkdocs.yml

echo "==> Starting mkdocs server on 127.0.0.1:8000"
mkdocs serve -f mkdocs.yml/mkdocs.yml -a 127.0.0.1:8000 > .mkdocs-server.log 2>&1 &
SERVER_PID=$!
cleanup() {
  if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo -n "==> Waiting for server to respond"
for i in {1..30}; do
  if curl -fsS http://127.0.0.1:8000/ >/dev/null 2>&1; then
    echo "\n✅ Docs server is up: http://127.0.0.1:8000/"
    exit 0
  fi
  echo -n "."
  sleep 1
done

echo "\n❌ Failed to reach docs server within timeout. See .mkdocs-server.log"
exit 1
