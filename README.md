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
