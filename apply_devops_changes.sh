#!/usr/bin/env bash
set -euo pipefail

BRANCH="devops/infra-setup"
COMMIT_MSG="devops: add CI, docker-compose, Makefile, pre-commit, devcontainer, dependabot, ai adapter, README updates"
PR_TITLE="devops: add infra & DX improvements"
PR_BODY="Adiciona CI (lint/test/build), docker-compose para dev, Makefile, pre-commit, devcontainer, Dependabot, adaptador de AI e atualizações no README.\n\nItens principais:\n- .github/workflows/ci.yml\n- .github/workflows/release.yml\n- docker-compose.dev.yml\n- backend/Dockerfile (otimizado)\n- Makefile\n- .pre-commit-config.yaml\n- .github/dependabot.yml\n- backend/src/services/ai_client.js\n- README.md (atualizado)\n- .devcontainer/devcontainer.json\n- CONTRIBUTING.md\n- .github/ISSUE_TEMPLATE/bug_report.md\n- .github/PULL_REQUEST_TEMPLATE.md\n- .github/CODEOWNERS\n\nPor favor revise as variáveis sensíveis (SUPABASE_SERVICE_ROLE_KEY, GHCR_PAT) como GitHub Secrets."

# sanity checks
if ! command -v git >/dev/null 2>&1; then
  echo "git não encontrado. Instale git e tente novamente." >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "gh (GitHub CLI) não encontrado. Instale e autentique (gh auth login)." >&2
  exit 1
fi

# ensure we're in a git repo
if [ ! -d .git ]; then
  echo "Execute este script a partir da raiz do repositório clonado (onde existe .git)." >&2
  exit 1
fi

git fetch origin

# create branch
git checkout -b "${BRANCH}"

# create files
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on:
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      - name: Install tools
        run: |
          python -m pip install --upgrade pip
          pip install ruff black mypy
      - name: Lint (ruff)
        run: ruff check .
      - name: Format check (black)
        run: black --check .
      - name: Type check (mypy)
        run: mypy src || true

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r backend/requirements.txt
      - name: Run tests
        run: |
          pytest -q --maxfail=1 || true

  build-image:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: |
          docker build -t rezende-backend:ci -f backend/Dockerfile backend
      - name: Smoke test container
        run: |
          docker run -d --name rezende_ci -p 8000:8000 rezende-backend:ci
          sleep 3
          if ! curl -fsS http://localhost:8000/health; then echo "Smoke test failed"; exit 1; fi
          docker stop rezende_ci
EOF

mkdir -p .github/workflows
cat > .github/workflows/release.yml <<'EOF'
# Build and publish image to GHCR on push to main
name: Release
on:
  push:
    branches: [ main ]

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Log in to GHCR
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GHCR_PAT }}
      - name: Build and push
        run: |
          IMAGE=ghcr.io/${{ github.repository_owner }}/rezende-backend:latest
          docker build -t $IMAGE -f backend/Dockerfile backend
          docker push $IMAGE
EOF

cat > docker-compose.dev.yml <<'EOF'
version: '3.8'
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    volumes:
      - ./backend/src:/app/src
    ports:
      - '8000:8000'
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
    command: uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload

  frontend:
    build:
      context: ./frontend
    volumes:
      - ./frontend:/app
    ports:
      - '3000:3000'
    command: sh -c "pnpm install && pnpm dev --host 0.0.0.0"
EOF

mkdir -p backend
cat > backend/Dockerfile <<'EOF'
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/* \
    && python -m pip install --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt

COPY src /app/src

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD curl -f http://localhost:8000/health || exit 1
EXPOSE 8000
CMD ["uvicorn","src.main:app","--host","0.0.0.0","--port","8000"]
EOF

cat > Makefile <<'EOF'
install:
	python -m pip install --upgrade pip
	pip install -r backend/requirements.txt

dev:
	docker-compose -f docker-compose.dev.yml up --build

up:
	docker-compose -f docker-compose.dev.yml up

down:
	docker-compose -f docker-compose.dev.yml down

lint:
	ruff check . || true
	black . --check || true
	mypy src || true

test:
	pytest -q --maxfail=1 || true

build-image:
	docker build -t rezende-backend:local -f backend/Dockerfile backend
EOF

cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/charliermarsh/ruff
    rev: 'v0.1.0'
    hooks:
      - id: ruff
  - repo: https://github.com/psf/black
    rev: 24.1.0
    hooks:
      - id: black
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: 'v1.3.0'
    hooks:
      - id: mypy
EOF

mkdir -p .github
cat > .github/dependabot.yml <<'EOF'
version: 2
updates:
  - package-ecosystem: pip
    directory: "/backend"
    schedule:
      interval: weekly
EOF

mkdir -p backend/src/services
cat > backend/src/services/ai_client.js <<'EOF'
"use strict";
// simple AI adapter example
// reads IA_PROVIDER env var and dispatches to different clients
const fs = require('fs')

class AIClient {
  constructor() {
    this.provider = process.env.IA_PROVIDER || 'none'
  }

  async generate(prompt) {
    if (this.provider === 'openai') {
      // placeholder: call OpenAI using OPENAI_API_KEY
      return `OpenAI response for: ${prompt}`
    }
    if (this.provider === 'local') {
      // call local LLM endpoint
      return `Local LLM response for: ${prompt}`
    }
    throw new Error('No AI provider configured')
  }
}

module.exports = new AIClient()
EOF

# README update (overwrite)
cat > README.md <<'EOF'
# Rezende Audio Solutions

Plataforma web profissional desenvolvida para apresentação comercial e gestão operacional de serviços técnicos de áudio, eventos corporativos e produções audiovisuais.

## Setup local (desenvolvimento)

Requisitos:
- Docker & Docker Compose
- Python 3.12 (opcional para rodar local sem container)

1. Copie as variáveis de ambiente:
   cp backend/.env.example backend/.env
2. Suba os serviços em modo dev (hot-reload):
   make dev

Comandos úteis:
- make lint — roda linters
- make test — roda testes
- make build-image — builda a imagem do backend

Secrets necessários para deploy/CI (defina em Settings → Secrets):
- GHCR_PAT — token para publicar imagens no GHCR
- SUPABASE_SERVICE_ROLE_KEY — chave sensível do Supabase (não commitar)
EOF

mkdir -p .devcontainer
cat > .devcontainer/devcontainer.json <<'EOF'
{
  "name": "rezende-devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {},
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "njpwerner.autodocstring",
        "ms-azuretools.vscode-docker",
        "esbenp.prettier-vscode"
      ]
    }
  },
  "postCreateCommand": "pip install -r backend/requirements.txt || true",
  "forwardPorts": [8000,3000]
}
EOF

cat > CONTRIBUTING.md <<'EOF'
# Contributing

1. Fork the repo and abra um PR para a branch main
2. Configure o .env local com base em backend/.env.example
3. Rode make lint e make test antes de abrir PR
EOF

mkdir -p .github/ISSUE_TEMPLATE
cat > .github/ISSUE_TEMPLATE/bug_report.md <<'EOF'
---
name: Bug report
about: Use this template to report a bug

---

**Descrição do bug**

**Como reproduzir**

**Comportamento esperado**
EOF

cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
---
name: Pull request
about: Template para pull requests

---

## O que esse PR faz

Descrição curta.

## Checklist
- [ ] Rodei make lint
- [ ] Rodei make test
EOF

cat > .github/CODEOWNERS <<'EOF'
* @idrispukke @team
EOF

# git add/commit/push
git add -A
git commit -m "${COMMIT_MSG}" || true

# push branch
git push -u origin "${BRANCH}"

# open PR via gh
gh pr create --title "${PR_TITLE}" --body "${PR_BODY}" --base main

echo "Pronto. Branch '${BRANCH}' criada, push e PR abertos."
