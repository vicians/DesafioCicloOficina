# Tião Oficina

Borracharia & Oficina Mecânica Inteligente — Fluxo de atendimento automático via WhatsApp e Gestão de Ordens de Serviço.

> Para documentação técnica completa do projeto (arquitetura, banco de dados, fluxos, variáveis de ambiente), consulte o [WIKI.md](WIKI.md).

---

## Quick Start

```bash
# 1. Copie e preencha as variáveis de ambiente
cp backend/.env.example backend/.env
cp ai_service/.env.example ai_service/.env

# 2. Adicione o firebase-service-account.json em backend/

# 3. Suba os containers
docker compose -f infra/docker/docker-compose.yml up -d

# 4. Rode as migrations (primeira vez)
docker compose -f infra/docker/docker-compose.yml exec backend node dist/backend/src/database/migrations/migrations.js
docker compose -f infra/docker/docker-compose.yml exec ai_service npx prisma migrate deploy
```

> Para o passo a passo completo, veja a seção [Como rodar com Docker](#como-rodar-com-docker) abaixo.

---

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) e [Docker Compose](https://docs.docker.com/compose/) instalados
- Arquivo de credenciais Firebase (`firebase-service-account.json`) obtido no Firebase Console
- API Key da NVIDIA (para o AI Service)

---

## Como rodar com Docker

### 1. Configure as variáveis de ambiente

O projeto usa dois arquivos `.env` separados, um para cada serviço:

```bash
# backend/.env → lido pelo backend
cp backend/.env.example backend/.env

# ai_service/.env → lido pelo AI Service
cp ai_service/.env.example ai_service/.env
```

Abra cada arquivo e preencha os valores reais (API keys, senhas, etc.).  
As variáveis obrigatórias para funcionar são: `DATABASE_URL`, `JWT_SECRET`, `NVIDIA_API_KEY`.

### 2. Adicione as credenciais do Firebase

No [Firebase Console](https://console.firebase.google.com/), vá em **Configurações do projeto → Contas de serviço → Gerar nova chave privada**.  
Salve o arquivo baixado como `backend/firebase-service-account.json`.

> O arquivo está no `.gitignore` e no `.dockerignore` — nunca vai para o repositório nem para a imagem.  
> Em runtime ele é montado como volume somente-leitura dentro do container.

### 3. Suba os serviços

```bash
# Na raiz do projeto:
docker compose -f infra/docker/docker-compose.yml up -d
```

Na primeira vez o Docker vai baixar as imagens base e fazer o build — pode demorar alguns minutos.

```bash
# Acompanhe os logs de todos os serviços em tempo real:
docker compose -f infra/docker/docker-compose.yml logs -f

# Ou de um serviço específico:
docker compose -f infra/docker/docker-compose.yml logs -f backend
docker compose -f infra/docker/docker-compose.yml logs -f ai_service
```

Para checar se os containers estão saudáveis:

```bash
docker compose -f infra/docker/docker-compose.yml ps
```

Todos devem aparecer com status `healthy` antes de prosseguir.

### 4. Execute as migrations do banco

Na primeira vez (ou após resetar o banco com `-v`), crie as tabelas:

```bash
# Migrations do backend (SQL puro)
docker compose -f infra/docker/docker-compose.yml exec backend node dist/backend/src/database/migrations/migrations.js

# Migrations do AI Service (Prisma)
docker compose -f infra/docker/docker-compose.yml exec ai_service npx prisma migrate deploy
```

### 5. Execute o seed inicial (opcional)

Popula o banco com usuários de teste (admin, mecânico, cliente) e catálogo de serviços:

```bash
docker compose -f infra/docker/docker-compose.yml exec backend node dist/backend/src/database/seeds/seeds.js
```

> Os dados do seed (nomes, e-mails, senhas) são lidos das variáveis `ADMIN_*`, `MECANICO_*` e `CLIENTE_*` do seu `.env`.

### 6. Sincronize o catálogo de produtos com o AI Service (opcional)

Para que a IA consiga buscar produtos no vector store, sincronize o catálogo após o seed:

```bash
curl -X POST http://localhost:3001/sync-products
```

---

## Serviços disponíveis

| Serviço | URL local | Descrição |
|---------|-----------|-----------|
| Backend API | http://localhost:3000 | REST API principal |
| API Docs (Swagger) | http://localhost:3000/api-docs | Documentação interativa |
| AI Service | http://localhost:3001 | Serviço de IA (LangChain) |
| AI Health Check | http://localhost:3001/health | Status do AI Service |
| PostgreSQL | localhost:5432 | Banco de dados |
| Redis | localhost:6379 | Cache |
| ChromaDB | http://localhost:8000 | Vector Store |

### pgAdmin (opcional)

Para subir a interface web de gerenciamento do banco:

```bash
docker compose -f infra/docker/docker-compose.yml --profile tools up -d pgadmin
```

Acesse em http://localhost:5050  
Login: use os valores de `PGADMIN_EMAIL` e `PGADMIN_PASSWORD` do seu `.env`

---

## Parar e limpar

```bash
# Para os containers (dados persistem nos volumes)
docker compose -f infra/docker/docker-compose.yml down

# Para E apaga todos os dados (volumes apagados) ⚠️
docker compose -f infra/docker/docker-compose.yml down -v
```

---

## Desenvolvimento local (sem Docker)

O app Flutter (`prototipo/`) roda em device/emulador e não precisa de Docker.  
Configure o endereço da API no app apontando para `http://localhost:3000`.
