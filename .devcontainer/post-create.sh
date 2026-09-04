#!/usr/bin/env bash
set -euo pipefail

echo [post-create] Frontend deps...
(cd frontend && npm install)

echo [post-create] Backend venv...
python3 -m venv backend/.venv
backend/.venv/bin/pip install --upgrade pip -q
backend/.venv/bin/pip install -r backend/requirements.txt -q || true
backend/.venv/bin/pip install ruff pytest -q

echo [post-create] OK.
echo Frontend: cd frontend && npm run dev
echo Backend: backend/.venv/bin/uvicorn src.main:app --reload
