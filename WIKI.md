# Tião Oficina - Documentação Técnica (WIKI)

**Última atualização:** 11 de maio de 2026  
- **Status: Backend (14 rotas) + AI Service (4 endpoints) operacionais localmente. Flutter com telas completas (API real). Autenticação JWT ainda não protege rotas. Docker Compose completo. `packages/` segue vazio e parte da estrutura planejada do AI Service ainda é placeholder. ✅ Muitas funcionalidades funcionando, ⚠️ Segurança e arquitetura carecem de refatoração.**

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura de Serviços](#arquitetura-de-serviços)
3. [Stack Técnico](#stack-técnico)
4. [Banco de Dados](#banco-de-dados)
5. [Fluxo de Dados](#fluxo-de-dados)
6. [Integrações Externas](#integrações-externas)
7. [Dependências e Configurações](#dependências-e-configurações)
8. [Estrutura de Diretórios](#estrutura-de-diretórios)
9. [Serviços por Componente](#serviços-por-componente)
10. [Autenticação e Segurança](#autenticação-e-segurança)
11. [Convenções e Padrões de Código](#convenções-e-padrões-de-código)
12. [Decisões Arquiteturais](#decisões-arquiteturais)
13. [Estado Atual do Projeto](#estado-atual-do-projeto)
14. [Próximos Passos Sugeridos](#próximos-passos-sugeridos)

---

## Visão Geral

**Projeto:** Tião Oficina - Borracharia & Oficina Mecânica Inteligente  
**Objetivo:** Sistema inteligente de atendimento automático via WhatsApp com gestão de Ordens de Serviço (OS), agendamentos, orçamentos, catálogo de serviços, controle de estoque e relatórios.

**Características principais:**
- Atendimento automático via WhatsApp (Bot AI com handoff humano controlável)
- Gestão interna de OS (Ordens de Serviço) para oficina
- Catálogo de serviços e produtos com controle de estoque
- Sistema de agendamentos e orçamentos
- Chat interno e chat com clientes via dashboard (funcionário → WhatsApp)
- Relatórios de desempenho (faturamento, serviços, ticket médio)
- Notificações push via Firebase Cloud Messaging
- Análise de pedidos via IA (LLM NVIDIA via LangChain)
- Busca semântica de produtos (ChromaDB Vector Store com RAG)

---

## Arquitetura de Serviços

Sistema dividido em **4 camadas principais**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cliente Mobile (Flutter)                     │
│                         iOS/Android                             │
│   - App Cliente (clientes da oficina)                          │
│   - App Interno (mecânicos / gerentes)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/REST
                             │ Firebase Push
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   BACKEND (Node.js/Express)                     │
│                         Port 3000                               │
│ - REST API (14 módulos: Auth, Usuários, Veículos,              │
│   Agendamentos, Orçamentos, Serviços, Execuções,               │
│   Produtos, Relatórios, Notificações, Push Tokens,             │
│   Chat, Conversas, Webhook WhatsApp)                           │
│ - Middlewares de auth/role existem mas não estão aplicados      │
│   nas rotas atualmente (endpoints sem proteção de JWT)          │
│ - Webhook WhatsApp (Meta) com handoff humano                   │
│ - Notificações Push (Firebase Admin, limite 5/user/dia)        │
│ - Integração com AI Service (RAG sync + análise)               │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/REST
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   AI SERVICE (Node.js/Express)                  │
│                         Port 3001                               │
│ - Análise de mensagens WhatsApp (LLM NVIDIA via LangChain)     │
│ - Busca semântica de produtos (ChromaDB RAG)                   │
│ - Criação de OS via IA (agendamento + orçamento + magic link)  │
│ - Prisma conectado ao PostgreSQL compartilhado                 │
│ - Modelos próprios (Customer/ChatLog/ServiceOrder) definidos,  │
│   mas sem persistência ativa no fluxo atual                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────┼────────┐
                    ▼        ▼        ▼
            ┌───────────────────────────────┐
            │  PostgreSQL Database          │
            │  Compartilhado (Backend + AI) │
            │  Port 5432                    │
            └───────────────────────────────┘
                             │
                             ▼
            ┌───────────────────────────────┐
            │  ChromaDB (Vector Store)      │
            │  Embeddings de produtos       │
            │  Port 8000                    │
            └───────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              Serviços Externos                                  │
│ - Meta WhatsApp Business API (Graph API v21.0)                 │
│ - NVIDIA Cloud AI (LLM via endpoint OpenAI-compatible)         │
│ - Firebase Cloud Messaging (Push notifications)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Componentes

| Componente | Tipo | Porta | Linguagem | Status Real |
|-----------|------|-------|-----------|-------------|
| Backend | API REST | 3000 | Node.js/TS | ✅ Operacional |
| AI Service | API REST | 3001 | Node.js/TS | ✅ Operacional |
| PostgreSQL | Database | 5432 | - | ✅ Local (manual) |
| ChromaDB | Vector DB | 8000 | - | ⚠️ Requer instância local |
| Redis | Cache | 6379 | - | ❌ Não implementado |
| Flutter App | Mobile | - | Dart | ✅ Rodando (Android) |

> **Nota:** O Redis foi mencionado em documentações anteriores mas **não existe nenhum código** usando Redis no projeto. Pode ser descartado ou planejado para futuro.

---

## Stack Técnico

### Backend
- **Runtime:** Node.js 20+
- **Framework:** Express.js 4.19+
- **Linguagem:** TypeScript 5.4+
- **ORM/Query:** pg (node-postgres) — queries SQL raw com pool
- **Validação:** Zod 3.22+
- **Autenticação:** JWT (jsonwebtoken 9.0+) + Magic Links
- **Criptografia:** bcrypt 6.0+ (10 rounds para senhas)
- **IDs:** uuid 14.0+ para geração de UUIDs
- **Documentação:** Swagger/OpenAPI (swagger-jsdoc + swagger-ui-express) — disponível em `/api-docs` apenas em `development`
- **HTTP Client:** Axios 1.15+ (comunicação com AI Service e Meta API)
- **Cloud:** Firebase Admin SDK 13.8+
- **Dev Tools:** ngrok (para expor webhook em desenvolvimento)

### AI Service
- **Runtime:** Node.js 20+
- **Framework:** Express.js 4.19+ (com `express-async-errors` 3.1.1+)
- **Linguagem:** TypeScript 5.4+
- **ORM:** Prisma 7.8+ (com adapter `@prisma/adapter-pg` para PostgreSQL)
- **IA/LLM:** LangChain (`@langchain/openai` 1.4.4+, `langchain` 1.3.4+) com `ChatOpenAI` apontando para NVIDIA NIM
- **Vector Store:** ChromaDB (`chromadb` 1.9.2+)
- **Query:** pg (node-postgres) 8.20+ (via Prisma adapter, não diretamente)
- **Validação:** Zod 3.22+
- **HTTP Client:** Axios 1.15+
- **Estrutura:** Monolítica em `src/index.ts` — subdiretórios (`agents/`, `chains/`, `prompts/`, `services/`, `tools/`, `whatsapp/`) estão **vazios** (apenas `.gitkeep`)
- ⚠️ `package.json` tem scripts `db:migrate` e `db:seed` apontando para `src/database/migrations/migrations.ts` e `src/database/seeds/seeds.ts` que **não existem**. O correto para o AI Service é `npx prisma migrate deploy`.

### Prototipo (Flutter)
- **SDK:** Flutter (Dart SDK ^3.11.4)
- **Firebase:** firebase_core 4.7+, firebase_messaging 16.2+
- **HTTP:** http 1.2+ (chamadas à REST API)
- **UI:** google_fonts 6.2+, flutter_local_notifications 17.2+, cupertino_icons 1.0.8+
- **Versão do app:** 1.0.0+1

### Infraestrutura
- **Database:** PostgreSQL (local, porta 5432)
- **Vector DB:** ChromaDB (local, porta 8000)
- **Docker:** `infra/docker/docker-compose.yml` está commitado e funcional para stack local (PostgreSQL, Redis, ChromaDB, Backend e AI Service).

---

## Banco de Dados

### PostgreSQL (Compartilhado entre Backend e AI Service)

**Conexão:** Pool de conexões pg (Backend: raw queries; AI Service: Prisma + pg adapter)  
**Extensões:** `pgcrypto` (UUID nativo via `gen_random_uuid()`)  
**Gerenciamento:** Backend usa `src/database/migrations/migrations.ts` (SQL raw, executado via `npm run db:migrate`)

**Convenção de preços:** Todos os valores monetários são armazenados como `INTEGER` em centavos. Ex: R$ 10,50 = 1050.

#### Tabelas Completas (ordem de criação)

**1. oficinas**
```sql
oficinas
├── id UUID PK (gen_random_uuid)
├── nome VARCHAR NOT NULL
├── quantidade_boxes INTEGER NOT NULL
└── criado_em TIMESTAMP DEFAULT now()
```

**2. tipos_usuario**
```sql
tipos_usuario
├── id SERIAL PK
├── nome VARCHAR NOT NULL
└── descricao TEXT
```
Seed padrão (via `seeds.ts`):
- `id=1`: ADMIN (Administrador do sistema)
- `id=2`: CLIENTE (Cliente da oficina)
- `id=3`: MECANICO (Técnico/Mecânico)

> ✅ **Status CORRIGIDO:** O código atual cria clientes com `tipo_id: 2` (CLIENTE) — o bug foi resolvido. Tanto o webhook quanto o AI Service usam `tipo_id: 2` corretamente.

**3. usuarios**
```sql
usuarios
├── id UUID PK
├── tipo_id INTEGER FK → tipos_usuario (ON DELETE RESTRICT)
├── cpf_cnpj VARCHAR UNIQUE NOT NULL
├── nome VARCHAR NOT NULL
├── telefone VARCHAR UNIQUE NOT NULL
├── email VARCHAR UNIQUE
├── senha_hash VARCHAR (nullable — clientes WhatsApp não têm senha real)
└── criado_em TIMESTAMP DEFAULT now()
```

**4. veiculos**
```sql
veiculos
├── id UUID PK
├── cliente_id UUID FK → usuarios (ON DELETE CASCADE)
├── placa VARCHAR UNIQUE NOT NULL
├── marca VARCHAR
├── modelo VARCHAR
├── ano INTEGER
├── quilometragem_atual INTEGER
└── criado_em TIMESTAMP DEFAULT now()
```

**5. catalogo_servicos**
```sql
catalogo_servicos
├── id UUID PK
├── nome VARCHAR NOT NULL
├── descricao TEXT
├── preco INTEGER NOT NULL (centavos)
├── duracao_minutos INTEGER NOT NULL
└── ativo BOOLEAN DEFAULT true
```

**6. produtos**
```sql
produtos
├── id UUID PK
├── nome VARCHAR NOT NULL
├── marca VARCHAR
├── valor INTEGER NOT NULL (centavos)
├── quantidade_estoque INTEGER
├── ativo BOOLEAN DEFAULT true
├── categoria VARCHAR (adicionada via ALTER)
├── min_estoque INTEGER DEFAULT 10 (adicionada via ALTER)
└── unidade VARCHAR DEFAULT 'unid.' (adicionada via ALTER)
```
> Quando um produto é criado/atualizado no Backend, `RagSyncService.syncProduto()` é chamado fire-and-forget para indexar o produto no ChromaDB.

**7. agendamentos**
```sql
agendamentos
├── id UUID PK
├── cliente_id UUID FK → usuarios (ON DELETE CASCADE)
├── veiculo_id UUID FK → veiculos (ON DELETE CASCADE)
├── funcionario_id UUID FK → usuarios (nullable)
├── agendado_para TIMESTAMP NOT NULL
├── duracao_total_minutos INTEGER NOT NULL
├── fim_estimado_em TIMESTAMP NOT NULL
├── status VARCHAR NOT NULL (PENDENTE, CONFIRMADO, CANCELADO)
├── notas_cliente TEXT
└── criado_em TIMESTAMP DEFAULT now()
```

**8. orcamentos**
```sql
orcamentos
├── id UUID PK
├── agendamento_id UUID FK → agendamentos (nullable, ON DELETE SET NULL)
├── cliente_id UUID FK → usuarios
├── funcionario_id UUID FK → usuarios (nullable)
├── status VARCHAR NOT NULL (RASCUNHO → ENVIADO → APROVADO | REJEITADO | CANCELADO)
├── valor_total INTEGER NOT NULL (centavos, recalculado automaticamente ao adicionar/remover itens)
├── observacoes TEXT (nullable)
├── valido_ate TIMESTAMP (nullable, obrigatório apenas ao aprovar)
└── criado_em TIMESTAMP DEFAULT now()

itens_orcamento_servico
├── id UUID PK
├── orcamento_id UUID FK → orcamentos (ON DELETE CASCADE)
├── servico_id UUID FK → catalogo_servicos (ON DELETE RESTRICT)
├── quantidade INTEGER DEFAULT 1
└── preco_unitario INTEGER NOT NULL

itens_orcamento_produto
├── id UUID PK
├── orcamento_id UUID FK → orcamentos (ON DELETE CASCADE)
├── produto_id UUID FK → produtos (ON DELETE RESTRICT)
├── quantidade INTEGER NOT NULL
└── preco_unitario INTEGER NOT NULL
```

**9. execucoes_servico**
```sql
execucoes_servico
├── id UUID PK
├── orcamento_id UUID UNIQUE FK → orcamentos (ON DELETE CASCADE)
├── funcionario_id UUID FK → usuarios (nullable)
├── status VARCHAR NOT NULL (AGUARDANDO, EM_EXECUCAO, REVISAO_TECNICA, CONCLUIDO, CANCELADO)
├── iniciado_em TIMESTAMP
├── finalizado_em TIMESTAMP
└── notas_internas TEXT
```
> **Nota importante:** Há inconsistência entre `execucaoServicoModel.ts` (que define AGUARDANDO, EM_EXECUCAO, REVISAO_TECNICA, CONCLUIDO, CANCELADO) e `reportModel.ts` (que também filtra por AGUARDANDO_RETIRADA). Necessário alinhar os status válidos ou documentar se AGUARDANDO_RETIRADA é um estado legado.

**10. conversacoes_chat** *(tabela de sessões de conversa)*
```sql
conversacoes_chat
├── id UUID PK
├── cliente_id UUID UNIQUE FK → usuarios (ON DELETE CASCADE)
├── ia_pausada BOOLEAN DEFAULT false  -- controla handoff humano
├── atualizado_em TIMESTAMP DEFAULT now()
└── criado_em TIMESTAMP DEFAULT now()
```
> Cada cliente tem no máximo uma conversa ativa. `ia_pausada=true` faz o backend parar de enviar mensagens ao AI Service — as mensagens do cliente são só salvas, aguardando atendente humano.

**11. mensagens_chat**
```sql
mensagens_chat
├── id UUID PK
├── cliente_id UUID FK → usuarios (ON DELETE CASCADE)
├── conversacao_id UUID FK → conversacoes_chat (ON DELETE CASCADE, adicionada via ALTER)
├── tipo_remetente VARCHAR NOT NULL (client, bot, employee, system)
├── conteudo TEXT NOT NULL
├── lida BOOLEAN DEFAULT false (adicionada via ALTER)
└── criado_em TIMESTAMP DEFAULT now()
```

**12. notifications**
```sql
notifications
├── id UUID PK
├── usuario_id UUID FK → usuarios (ON DELETE CASCADE)
├── tipo VARCHAR NOT NULL
├── titulo VARCHAR NOT NULL
├── mensagem TEXT NOT NULL
├── referencia_id UUID
├── referencia_tipo VARCHAR
├── push_enviado BOOLEAN DEFAULT false
├── push_enviado_em TIMESTAMP
├── lida BOOLEAN DEFAULT false
├── lido_em TIMESTAMP
└── criado_em TIMESTAMP DEFAULT now()
```

**13. user_push_tokens** *(anteriormente chamada `push_tokens`)*
```sql
user_push_tokens
├── id UUID PK
├── usuario_id UUID FK → usuarios (ON DELETE CASCADE)
├── fcm_registration_token TEXT UNIQUE NOT NULL
├── criado_em TIMESTAMP DEFAULT now()
└── atualizado_em TIMESTAMP DEFAULT now()
```
> Migration inclui compatibilidade: renomeia coluna `token` → `fcm_registration_token` em bases antigas.

**14. magic_links** *(autenticação sem senha para clientes)*
```sql
magic_links
├── id UUID PK
├── usuario_id UUID FK → usuarios (ON DELETE CASCADE)
├── token VARCHAR(64) UNIQUE NOT NULL (crypto.randomBytes(32).toString('hex'))
├── expires_at TIMESTAMP NOT NULL (24h TTL)
├── used BOOLEAN DEFAULT false
└── criado_em TIMESTAMP DEFAULT now()
```

### AI Service — Modelos Prisma (schema separado)

O AI Service usa Prisma com **19 modelos no total**: 3 modelos **próprios** + 16 mapeamentos das tabelas do backend PostgreSQL (necessário para o Prisma funcionar com banco compartilhado).

> ⚠️ **Schema drift detectado:** A coluna `observacoes` de `orcamentos` existe na migration SQL e no DTO, mas **não está mapeada no `schema.prisma`** do AI Service. Se o AI Service precisar ler `observacoes` via Prisma, o schema precisará ser atualizado.

Modelos **próprios** (3):

```prisma
Customer          -- Clientes WhatsApp identificados pelo número
├── id String UUID PK
├── whatsappNumber String UNIQUE  -- vem de message.from (Meta API)
├── name String?
├── status String DEFAULT "BOT"   -- "BOT" ou "HUMAN" (handoff)
└── createdAt DateTime

ChatLog           -- Histórico de mensagens para contexto do LLM
├── id String UUID PK
├── message String
├── role String                   -- "user" ou "assistant"
├── customerId String? FK → Customer
└── timestamp DateTime

ServiceOrder      -- OS criadas pela IA
├── id String UUID PK
├── customerName String
├── vehiclePlate String
├── description String
├── status String DEFAULT "OPEN"
└── createdAt DateTime
```

> ⚠️ **Estado real do runtime:** apesar desses 3 modelos existirem no schema Prisma, o fluxo atual de `src/index.ts` não grava `Customer`, `ChatLog` nem `ServiceOrder`. O endpoint `/ai/analyze` apenas lê `Customer` (`findUnique`) e o restante do processo usa integração HTTP com o backend.

> Os demais 16 modelos espelham as tabelas do backend (`agendamentos`, `usuarios`, `veiculos`, `catalogo_servicos`, `produtos`, `orcamentos`, `itens_orcamento_servico`, `itens_orcamento_produto`, `execucoes_servico`, `conversacoes_chat`, `mensagens_chat`, `notifications`, `user_push_tokens`, `magic_links`, `oficinas`, `tipos_usuario`) para consultas cruzadas pelo AI Service.

### ChromaDB — Vector Store

**Collection:** `produtos_oficina`  
**Endpoint:** `http://localhost:8000` (variável `CHROMA_URL`)  
**Documento armazenado (linguagem natural):**
```
"Filtro de óleo Mann (Mann): preço R$ 45.90 por unidade. Estoque atual: 30 unidades."
```
**Metadados:** `nome`, `marca`, `valor`, `quantidade_estoque`  
**Interface:** `ai_service/src/vectorstore/productVectorStore.ts`
- `upsertProduto(payload)` — insere ou atualiza embedding
- `queryProdutos(query, topK?)` — busca semântica, retorna array de strings de contexto

> ⚠️ ChromaDB usa embeddings padrão da própria biblioteca (não usa NVIDIA para embeddings — somente para o LLM de análise). Isso pode limitar a qualidade semântica.

---

## Fluxo de Dados

### Fluxo WhatsApp → OS (Completo)

```
1. Cliente envia mensagem WhatsApp
   ↓
2. Meta API dispara POST → /whatsapp no Backend
   ↓
3. Backend:
   a. Verifica se existe usuário com aquele telefone
      - Se não: cria usuário on-the-fly com `tipo_id=2` (CLIENTE)
   b. Busca ou cria conversacoes_chat para o cliente
   c. Salva mensagem em mensagens_chat (tipo_remetente='client')
   d. Verifica ia_pausada na conversa
      - Se true: retorna 200 sem processar (aguarda atendente humano)
   ↓
4. Backend POST → /ai/analyze no AI Service com { message, number }
   ↓
5. AI Service:
   a. Busca Customer pelo whatsappNumber no Prisma
      - Se status='HUMAN': retorna action='MANUAL_WAIT'
   b. Consulta ChromaDB com a mensagem (RAG) → contexto de produtos
   c. Chama LLM NVIDIA via LangChain com:
      - System prompt com contexto de produtos
      - Mensagem do usuário
   d. Analisa resposta:
      - JSON com action='CREATE_OS' → retorna action='CREATE_OS' + demand
      - Texto livre → retorna action='REPLY' + result
   ↓
6. Backend processa ação:
   - REPLY: envia resposta ao cliente via Meta API + salva em mensagens_chat (bot)
   - CREATE_OS: POST → /ai/create-os no AI Service
   - MANUAL_WAIT: envia mensagem de espera + chama ConversationModel.updateHandoff()
   ↓
7. AI Service /ai/create-os:
   a. Busca ou cria cliente no Backend (/usuarios)
   b. Busca ou cria veículo no Backend (/veiculos)
   c. Busca mecânico disponível (/usuarios?tipo_id=3)
   d. Cria agendamento (/agendamentos)
   e. Cria orçamento (/orcamentos)
   f. Gera magic_link_url
   g. Retorna { message, magic_link_url }
   ↓
8. Backend envia ao cliente:
   "Gerando OS... Acompanhe: {magic_link_url}"
   Salva em mensagens_chat (bot)
```

### Fluxo App Mobile → Backend

```
1. Usuário autentica via login (email + senha)
   → Backend verifica senha com bcrypt, retorna JWT
   ↓
2. App usa `usuario.tipo_id` retornado para rotear Cliente vs Interno
   ↓
3. No estado atual, o token JWT não é persistido/propagado pelos repositórios HTTP do Flutter
   (exceção parcial: chat interno possui header Authorization placeholder `YOUR_JWT_TOKEN_HERE`)
   ↓
4. Acessa endpoints:
   - Agendamentos, Orçamentos, Serviços, Execuções
   - Produtos, Relatórios, Notificações, Conversas
   ↓
5. Backend retorna dados do PostgreSQL
   ↓
6. App renderiza UI com dados reais (API)
```

### Fluxo Funcionário → Cliente WhatsApp (via Dashboard)

```
1. Funcionário acessa tela de conversas no app interno
2. Seleciona conversa de um cliente
3. Envia mensagem via POST /conversacoes/{id}/mensagens
   { conteudo, tipo_remetente: 'employee' }
   ↓
4. Backend salva em mensagens_chat
5. Backend busca telefone do cliente em usuarios
6. Backend envia mensagem via Meta API → WhatsApp do cliente
```

### Fluxo RAG Sync (Produtos)

```
1. Produto criado/atualizado no Backend (/produtos)
2. Backend chama RagSyncService.syncProduto() (fire-and-forget)
3. POST → /ai/produtos/sync no AI Service
4. AI Service faz upsert no ChromaDB com texto em linguagem natural
5. Próxima análise de mensagem usa contexto atualizado de produtos
```

---

## Integrações Externas

### Meta WhatsApp Business API
- **Endpoint:** `https://graph.facebook.com/v21.0/{WA_PHONE_NUMBER_ID}/messages`
- **Autenticação:** Bearer token (`WA_ACCESS_TOKEN`)
- **GET /whatsapp:** Validação de webhook (hub.verify_token)
- **POST /whatsapp:** Recebimento de mensagens (processa apenas `text.body`)
- **Envio:** `sendWhatsAppMessage(to, text)` em `backend/src/webhook/controller.ts`

**Variáveis:**
```
WA_ACCESS_TOKEN=
WA_PHONE_NUMBER_ID=
VERIFY_TOKEN=
```

### NVIDIA NIM (LLM)
- **Provider:** NVIDIA Cloud AI via endpoint OpenAI-compatible
- **SDK:** LangChain `ChatOpenAI` com `configuration.baseURL` custom
- **Configuração:**
  ```typescript
  new ChatOpenAI({
    apiKey: NVIDIA_API_KEY,
    configuration: { baseURL: NVIDIA_BASE_URL },
    modelName: AI_MODEL,
    temperature: 0.3,
    maxRetries: 1,
    timeout: 15000,
  }).withConfig({ runName: "Pistao_Analyze" })
  ```
- **Prompt de sistema:** Identifica tipo de serviço, informa preços e, para agendamentos, responde JSON estruturado `{ action, customerName, vehiclePlate, description, serviceType }`

**Variáveis:**
```
NVIDIA_API_KEY=
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
AI_MODEL=meta/llama-2-7b-chat-q4
```

### Firebase Cloud Messaging (FCM)
- **Serviço:** Push notifications via Firebase Admin SDK 13.8+
- **Inicialização:** `backend/src/config/firebase.ts` (`initFirebase()`)
- **Envio:** `sendEachForMulticast()` (suporte a múltiplos tokens por chamada)
- **Limite:** Máximo **5 pushes FCM/usuário/dia** (RN049) — verificado via SQL count em `notifications`
- **Prioridade:** `android.priority: 'high'`, `apns.aps.sound: 'default'`
- **Credenciais:** Arquivo `.json` de service account (não versionado)

**Variável:**
```
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

---

## Dependências e Configurações

### Variáveis de Ambiente — Backend (`backend/.env`)

```env
# Server
PORT=3000
BASE_URL=http://localhost
API_PORT=:3000
NODE_ENV=development
JWT_SECRET=<chave_secreta_256_bits>

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/oficina

# WhatsApp (Meta)
WA_ACCESS_TOKEN=
WA_PHONE_NUMBER_ID=
VERIFY_TOKEN=

# AI Service
AI_SERVICE_URL=http://localhost:3001

# Firebase
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

> **Nota sobre Seeds:** As seeds **não usam variáveis de ambiente**. Os usuários de demonstração têm UUIDs e credenciais **hardcoded** diretamente em `seeds.ts`:
> - Admin: `admin@omniconnect.com.br` / `admin_secret_password` (UUID: `a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11`)
> - Mecânico: `mecanico@omniconnect.com.br` / `mecanico_secret_password` (UUID: `b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12`)
> - 6 Clientes demo: senhas `cliente_secret_password`, emails `gabriela@gmail.com`, `beatriz@gmail.com`, etc.
> - Oficina: `Tião Oficina Mecânica` com 4 boxes

### Variáveis de Ambiente — AI Service (`ai_service/.env`)

```env
PORT=3001
NODE_ENV=development

DATABASE_URL=postgresql://postgres:postgres@localhost:5432/oficina

BACKEND_URL=http://localhost:3000

NVIDIA_API_KEY=
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
AI_MODEL=meta/llama-2-7b-chat-q4

CHROMA_URL=http://localhost:8000
```

### Scripts de Package.json

**Backend:**
```bash
npm run dev          # ts-node-dev (desenvolvimento com hot reload)
npm run build        # tsc (compila para dist/)
npm start            # node dist/server.js (produção)
npm run db:migrate   # Executa migrations SQL
npm run db:seed      # Executa seeds de demonstração (UUIDs fixos, credenciais hardcoded — ver abaixo)
npm run db:reset     # Reseta o banco (cuidado!)
```

**AI Service:**
```bash
npm run dev          # ts-node-dev
npm run build        # tsc
npm start            # node dist/index.js
# Para migrations do AI Service, usar a CLI do Prisma: npx prisma migrate deploy
```

---

## Estrutura de Diretórios

```
DesafioCicloOficina/
├── README.md
├── WIKI.md (este arquivo)
│
├── backend/                          ✅ Operacional
│   ├── package.json
│   ├── tsconfig.json
│   ├── firebase-service-account.json (não versionado)
│   └── src/
│       ├── server.ts               (entry point: conecta DB, inicia Express)
│       ├── app.ts                  (Express setup: cors, json, routes, swagger)
│       ├── config/
│       │   ├── database.ts         (pg Pool, getDb())
│       │   ├── firebase.ts         (Firebase Admin init, getMessaging())
│       │   └── swagger.ts          (OpenAPI spec)
│       ├── routes/ (14 arquivos)
│       │   ├── index.ts            (agrega todos os routers)
│       │   ├── authRoutes.ts
│       │   ├── usuarioRoutes.ts
│       │   ├── veiculoRoutes.ts
│       │   ├── agendamentoRoutes.ts
│       │   ├── orcamentoRoutes.ts
│       │   ├── catalogoServicoRoutes.ts
│       │   ├── execucaoServicoRoutes.ts
│       │   ├── produtoRoutes.ts
│       │   ├── reportRoutes.ts
│       │   ├── notificationRoutes.ts
│       │   ├── pushTokenRoutes.ts
│       │   ├── chatMessageRoutes.ts
│       │   └── conversationRoutes.ts
│       ├── controllers/ (14 arquivos — espelham routes)
│       │   ├── authController.ts    (generateMagicLink, validateMagicLink, login)
│       │   ├── conversationController.ts (list, getMessages, sendMessage → WhatsApp)
│       │   ├── reportController.ts  (métricas por day/month/year)
│       │   └── ... (demais seguem padrão CRUD)
│       ├── models/ (14 arquivos — queries SQL raw via pg)
│       │   ├── conversationModel.ts (findOrCreateByClienteId, findAll, addMessage, updateHandoff)
│       │   ├── reportModel.ts       (loadPeriodMetrics, InternalReportDTO)
│       │   └── ... (demais: findById, findAll, create, update, delete)
│       ├── services/
│       │   ├── pushService.ts       (sendPushToTokens, sendPushToUsers, limite RN049)
│       │   └── ragSyncService.ts    (syncProduto — fire-and-forget para AI Service)
│       ├── database/
│       │   ├── migrations/
│       │   │   └── migrations.ts   (runMigrations — SQL raw, todas as tabelas)
│       │   ├── seeds/
│       │   │   └── seeds.ts        (tipos_usuario, admin, mecanico, cliente)
│       │   └── reset.ts            (DROP + recria tudo)
│       ├── webhook/
│       │   ├── index.ts            (Router: GET + POST /whatsapp)
│       │   └── controller.ts       (validateWebhook, handleMessage, sendWhatsAppMessage)
│       ├── middlewares/
│       │   ├── AuthMiddleware.ts   (valida JWT → req.user)
│       │   └── RoleMiddleware.ts   (authorizeRole([tipo_ids]))
│       ├── types/
│       │   └── express/            (augmentation: Request.user?: TokenPayload)
│       └── utils/
│           ├── JWTUtils.ts         (sign, verify, TokenPayload)
│           └── passwordUtils.ts    (hash, compare — bcrypt)
│
├── ai_service/                       ✅ Operacional (monolítico em index.ts)
│   ├── package.json
│   ├── tsconfig.json
│   ├── prisma.config.ts
│   ├── prisma/
│   │   ├── schema.prisma           (Customer, ChatLog, ServiceOrder + tabelas backend)
│   │   └── migrations/
│   │       └── 20260430112827_init_schema/
│   └── src/
│       ├── index.ts                (TUDO: Express setup, rotas, LLM, Prisma, ChromaDB)
│       ├── vectorstore/
│       │   └── productVectorStore.ts (upsertProduto, queryProdutos via ChromaDB)
│       ├── agents/                 ⚠️ Placeholder
│       ├── chains/                 ⚠️ Placeholder
│       ├── config/                 (ai_model.ts, embeddings.ts, prisma.ts)
│       ├── routes/                 (ai_routes.ts)
│       ├── schemas/                (ai_schemas.ts)
│       ├── services/               (analyze_service.ts, appointment_service.ts)
│       ├── tools/                  (index.ts + tools de appointment/availability/history)
│       ├── utils/                  (date_utils.ts)
│       └── whatsapp/               ⚠️ Placeholder
│
├── prototipo/                        ✅ Flutter rodando (Android)
│   ├── pubspec.yaml                (tiao_oficina v1.0.0+1)
│   └── lib/
│       ├── main.dart               (entry: Firebase init, LoginScreen)
│       ├── firebase_options.dart   (gerado pelo FlutterFire CLI)
│       ├── core/
│       │   ├── theme/
│       │   │   ├── colors.dart
│       │   │   └── theme.dart      (buildAppTheme)
│       │   └── widgets/            (AppButton, AppCard, AppInput, AppProgressBar, StatusBadge, etc.)
│       ├── data/
│       │   ├── auth_repository.dart   (login via backend — email+senha)
│       │   └── mock_data.dart         (dados fictícios para desenvolvimento)
│       ├── services/
│       │   ├── firebase_messaging_service.dart (FCM init, handlers)
│       │   └── inventory_service.dart          (chamadas à API de produtos)
│       └── features/
│           ├── cliente/
│           │   ├── cliente_app.dart
│           │   ├── data/
│           │   │   ├── client_flow_api_repository.dart      (API real)
│           │   │   ├── client_flow_repository.dart          (interface)
│           │   │   ├── client_notification_api_repository.dart
│           │   │   ├── client_notification_repository.dart
│           │   │   ├── client_schedule_api_repository.dart
│           │   │   └── models/client_models.dart
│           │   └── screens/
│           │       ├── home_screen.dart
│           │       ├── history_screen.dart
│           │       ├── budget_approval_screen.dart
│           │       ├── notifications_screen.dart
│           │       ├── register_vehicle_screen.dart
│           │       ├── schedule_service_sheet.dart
│           │       ├── service_detail_screen.dart
│           │       └── client_screen_header.dart
│           └── interno/
│               ├── interno_app.dart
│               ├── data/
│               │   ├── internal_flow_api_repository.dart    (API real)
│               │   ├── internal_flow_mock_repository.dart   (mock data)
│               │   ├── internal_flow_repository.dart        (interface)
│               │   ├── internal_chat_api_repository.dart
│               │   ├── internal_chat_repository.dart
│               │   ├── notification_api_repository.dart
│               │   ├── notification_repository.dart
│               │   ├── report_api_repository.dart
│               │   ├── report_repository.dart
│               │   ├── scheduling_api_repository.dart
│               │   ├── scheduling_repository.dart
│               │   └── models/
│               │       ├── internal_service.dart
│               │       ├── internal_budget_item.dart
│               │       ├── internal_chat_models.dart
│               │       ├── catalogo_servico_item.dart
│               │       ├── produto_item.dart
│               │       ├── report_data.dart
│               │       └── scheduled_service_item.dart
│               └── screens/
│                   ├── login_screen.dart            (auth email+senha)
│                   ├── employee_dashboard_screen.dart
│                   ├── service_list_screen.dart
│                   ├── internal_service_detail_screen.dart
│                   ├── scheduled_services_screen.dart
│                   ├── budget_list_screen.dart
│                   ├── budget_detail_screen.dart
│                   ├── inventory_screen.dart
│                   ├── reports_screen.dart
│                   ├── internal_chat_screen.dart       (chat entre funcionários)
│                   ├── internal_messages_screen.dart
│                   ├── service_client_chat_screen.dart (chat com cliente via WhatsApp)
│                   └── internal_notifications_screen.dart
│
├── shared/                           ✅ DTOs compartilhados (TypeScript)
│   └── dtos/
│       ├── index.ts                (re-exporta apenas 9 DTOs)
│       ├── usuarioDto.ts
│       ├── veiculoDto.ts
│       ├── catalogoServicoDto.ts
│       ├── produtoDto.ts
│       ├── agendamentoDto.ts
│       ├── orcamentoDto.ts
│       ├── execucaoServicoDto.ts
│       ├── itemOrcamentoDto.ts
│       ├── itemOrcamentoSimplesDto.ts
│       ├── notificationDto.ts
│       ├── pushTokenDto.ts
│       └── oficinaDto.ts
│
├── infra/                            ⚠️ Parcialmente populado
│   ├── db/                         (.gitkeep)
│   │   └── postgres/               (.gitkeep — reservado para scripts locais)
│   └── docker/
│       ├── docker-compose.yml      (stack local completo)
│       └── .gitkeep
│
└── packages/                        ⚠️ Todos vazios (só .gitkeep)
    ├── eslint-config/
    ├── flutter_core/
    ├── shared/
    ├── shared-types/
    └── typescript-config/
```

---

## Serviços por Componente

### Backend (Port 3000) — Express API

**Padrão de Arquitetura:** MVC (Model-View-Controller)
- **Models:** Queries SQL com pg (métodos estáticos de classe)
- **Controllers:** Classes com métodos estáticos (`async (req, res)`)
- **Routes:** Objetos Router com JSDoc Swagger
- **Middleware de segurança:** `AuthMiddleware` e `RoleMiddleware` existem, porém **não são montados** em `routes/*.ts` no estado atual

**Rotas Principais (14 módulos):**

| Prefixo | Descrição | Observação |
|---------|-----------|------------|
| `/auth` | Magic Links, login email+senha, JWT | generateMagicLink, validateMagicLink, login |
| `/usuarios` | CRUD de usuários | tipo_id filtrável por query param (1=ADMIN, 2=CLIENTE, 3=MECANICO) |
| `/veiculos` | CRUD de veículos dos clientes | |
| `/agendamentos` | CRUD de agendamentos | status: PENDENTE, CONFIRMADO, CANCELADO |
| `/orcamentos` | Orçamentos com itens + aprovação | status: RASCUNHO→ENVIADO→APROVADO|REJEITADO|CANCELADO; endpoints adicionais: `/:id/servicos`, `/:id/produtos`, `/:id/aprovar`, `/:id/rejeitar` |
| `/servicos` | Catálogo de serviços | |
| `/execucoes` | Execução de serviços | status: AGUARDANDO, EM_EXECUCAO, REVISAO_TECNICA, CONCLUIDO, CANCELADO |
| `/produtos` | Produtos/peças com estoque | Trigger RAG sync em create/update |
| `/reports` | Relatórios de faturamento | query param: `period=day/month/year`, `month=YYYY-MM`, `date=YYYY-MM-DD` |
| `/notifications` | Notificações internas | |
| `/push-tokens` | FCM tokens | CRUD de `user_push_tokens` |
| `/chat` | Mensagens de chat individuais | |
| `/conversacoes` | Conversas (sessões) com clientes | list, getMessages, sendMessage (→ WhatsApp) |
| `/whatsapp` | Webhook Meta WhatsApp | GET: handshake; POST: handleMessage |

**Documentação Swagger:** `GET /api-docs` (apenas `NODE_ENV !== 'production'`)

**Bootstrap real do servidor:**
- `src/server.ts` inicializa Firebase (`initFirebase`) e sobe Express
- Não executa migrations automaticamente no startup
- Conexão com PostgreSQL é lazy (pool criado sob demanda no primeiro `getDb()`)

**Serviços Internos:**

```
pushService.ts
├── sendPushToTokens(tokens, title, body, data?)
│   └── firebase.sendEachForMulticast() com prioridade high (Android) e sound default (iOS)
└── sendPushToUsers(userIds, notificationIds, title, body, data?)
    ├── Filtra via SQL: tokens cujos usuários têm < 5 pushes HOJE
    ├── Chama sendPushToTokens()
    └── Marca notificações como push_enviado=true

ragSyncService.ts
└── syncProduto(produto: ProdutoDTO)
    └── POST /ai/produtos/sync (fire-and-forget, timeout 5s)
```

**Métodos adicionais do OrcamentoModel:**
```
OrcamentoModel
├── findByAgendamentoId(id)     — verifica orçamento já existente para o agendamento
├── recalcularTotal(id)         — recalcula valor_total somando itens de serviço + produto via SQL
├── addServico/removeServico    — adiciona/remove item de serviço (congela preco_unitario do catálogo)
├── addProduto/removeProduto    — adiciona/remove item de produto (congela preco_unitario do estoque)
├── aprovar(id, valido_ate)     — muda status para APROVADO + cria execucao_servico
└── rejeitar(id)                — muda status para REJEITADO + notifica funcionários internos

ExecucaoServicoModel
├── ensureByOrcamentoId(id)     — cria OS (status=AGUARDANDO) se não existir; ON CONFLICT não faz nada
└── backfillFromApprovedBudgets() — retroativamente cria OS para orçamentos APROVADO sem OS associada
```

### AI Service (Port 3001) — Monolítico em index.ts

**Endpoints:**

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/health` | GET | `{ status: 'ok', service: 'CicloOficina AI Service' }` |
| `/ai/analyze` | POST | Analisa mensagem WhatsApp → REPLY / CREATE_OS / MANUAL_WAIT |
| `/ai/create-os` | POST | Cria cliente, veículo, agendamento, orçamento, magic link |
| `/ai/produtos/sync` | POST | Upsert de produto no ChromaDB |

**Fluxo de `/ai/analyze`:**
1. Busca `Customer` pelo número no Prisma
2. Se `status='HUMAN'` → retorna `{ action: 'MANUAL_WAIT' }`
3. Consulta ChromaDB com a mensagem → lista de produtos relevantes como contexto
4. Invoca LLM com system prompt + contexto + mensagem do usuário
5. Tenta `JSON.parse()` da resposta:
   - Se JSON com `action='CREATE_OS'` → retorna `{ action: 'CREATE_OS', demand: {...} }`
   - Caso contrário → retorna `{ action: 'REPLY', result: <texto> }`

**Fluxo de `/ai/create-os`:**
1. Busca cliente existente por telefone em `/usuarios?tipo_id=2` (CLIENTE) → cria se não encontrar com `tipo_id: 2`
2. Busca veículo por placa em `/veiculos` → cria se não encontrar
3. Pega primeiro mecânico de `/usuarios?tipo_id=3` (MECANICO)
4. Calcula próximo dia útil às 9h (`nextBusinessDay9am()`)
5. Cria agendamento em `/agendamentos`
6. Cria orçamento em `/orcamentos` (status inicial: RASCUNHO)
7. Chama `POST /auth/magic-link` para gerar link de acompanhamento
8. Retorna `{ ok: true, magic_link_url, message }`

> **Nota:** Tanto o webhook do backend quanto o fluxo de criação de OS no AI Service usam `tipo_id=2` para clientes.

**Configuração LLM:**
```typescript
const model = new ChatOpenAI({
  apiKey: NVIDIA_API_KEY,
  configuration: { baseURL: NVIDIA_BASE_URL },
  modelName: AI_MODEL,
  temperature: 0.3,
  maxRetries: 1,
  timeout: 15000,
}).withConfig({ runName: "Pistao_Analyze" });
```

### Flutter App (Prototipo)

**Entry point:** `main.dart`
- Inicializa Firebase (trata falha silenciosamente para compatibilidade com web/simuladores)
- Define orientação: apenas portrait
- Rota inicial: `LoginScreen`

**Login:** Email + senha via `AuthRepository` → backend `/auth/login`
- URL do backend: `localhost:3000` (web/iOS/macOS) ou `10.0.2.2:3000` (Android emulador)
- ⚠️ `internal_messages_screen.dart` usa base URL hardcoded `http://10.0.2.2:3000` (sem detecção web/iOS/macOS)

**Após login — dois fluxos:**
- **Mecânico/Admin** → `InternoApp` (dashboard, serviços, orçamentos, estoque/relatórios para gerente, mensagens para mecânico)
- **Cliente** → `ClienteApp` (home, histórico, orçamentos, agendamento, notificações)

**Comportamento DEV ativo por padrão:**
- `InternoApp`: `_kEnableDevLowStockSeedOnStartup = true` (dispara `POST /notifications/dev/seed-low-stock` no startup)
- `ClienteApp`: `_kEnableDevClientSeedOnStartup = true` (dispara `POST /notifications/dev/seed-client-alert` no startup)

**Padrão de repositório (dual mode):**
- `*_api_repository.dart` — consome a REST API real (**em uso em produção**)
- `*_mock_repository.dart` / `mock_data.dart` — dados fictícios para desenvolvimento offline (**implementado mas não instanciado** — `internal_flow_mock_repository.dart` existe mas não é referenciado em `interno_app.dart`)
- `*_repository.dart` — interface (abstract class / interface)

**Telas do App Interno (13 screens):**

| Tela | Descrição |
|------|-----------|
| login_screen | Email + senha, roteamento por tipo de usuário |
| employee_dashboard_screen | Resumo: serviços pendentes, orçamentos, métricas |
| service_list_screen | Lista de OS ativas |
| internal_service_detail_screen | Detalhes e atualização de status de OS |
| scheduled_services_screen | Agenda de serviços por data |
| budget_list_screen | Lista de orçamentos |
| budget_detail_screen | Detalhes e aprovação/rejeição de orçamento |
| inventory_screen | Estoque de produtos |
| reports_screen | Relatórios de faturamento e serviços |
| internal_chat_screen | Tela de chat de uma conversa (aberta a partir de internal_messages_screen) |
| internal_messages_screen | Lista de conversas com clientes (tab ativa para perfil mecânico) |
| service_client_chat_screen | Chat com cliente via WhatsApp (envio pelo dashboard) |
| internal_notifications_screen | Notificações internas |

> Nota de navegação atual: perfil **gerente** não tem aba dedicada de mensagens no `InternoApp`; perfil **mecânico** possui aba `Mensagens`.

**Telas do App Cliente (8 screens):**

| Tela | Descrição |
|------|-----------|
| home_screen | Dashboard do cliente |
| history_screen | Histórico de serviços |
| budget_approval_screen | Aprovação de orçamentos |
| notifications_screen | Notificações |
| register_vehicle_screen | Cadastro de veículo |
| schedule_service_sheet | Agendamento de serviço (bottom sheet modal — não é uma tela full) |
| service_detail_screen | Detalhes de um serviço |
| client_screen_header | Widget de header compartilhado (componente — não é uma tela full) |

### Shared DTOs (`shared/dtos/`)

DTOs TypeScript compartilháveis entre serviços Node.js:

| DTO | Uso |
|-----|-----|
| `UsuarioDTO` | Usuário sem senha; `CreateUsuarioDTO` inclui `senha_hash` |
| `VeiculoDTO` | Dados do veículo |
| `CatalogoServicoDTO` | Serviço do catálogo |
| `ProdutoDTO` | Produto com `categoria`, `min_estoque`, `unidade` |
| `AgendamentoDTO` | Agendamento |
| `OrcamentoDTO` | Orçamento completo |
| `ExecucaoServicoDTO` | Execução de serviço |
| `ItemOrcamentoDTO` | Item de orçamento (serviço ou produto) |
| `NotificationDTO` | Notificação interna |
| `PushTokenDTO` | Token FCM |
| `OficinaDTO` | Dados da oficina |

> **Nota:** Os `packages/shared` e `packages/shared-types` estão **vazios**. Os DTOs atualmente ficam em `shared/dtos/` na raiz do monorepo, importados diretamente com caminho relativo.

> ⚠️ **Detalhe de barrel export:** `shared/dtos/index.ts` não exporta todos os arquivos do diretório. Ficam fora do barrel atual, por exemplo: `execucaoServicoDto`, `itemOrcamentoDto` e `itemOrcamentoSimplesDto`.

> ⚠️ **DTO legado:** `LoginDTO` em `usuarioDto.ts` ainda usa formato `{ email_ou_telefone, senha_hash }`, enquanto o endpoint real `/auth/login` recebe `{ email, senha }`.

---

## Autenticação e Segurança

### Estratégia de Autenticação

O sistema possui **duas estratégias** de autenticação:

**1. Login Tradicional (App Interno)**
```
POST /auth/login
   { email, senha }
  → PasswordUtils.compare(senha, hash)
  → JWTUtils.sign({ id, email, role: tipo_id })
   → { token, usuario }
```

**2. Magic Link (Clientes via WhatsApp / Link)**
```
POST /auth/magic-link
  { telefone }
  → Busca usuário pelo telefone
  → crypto.randomBytes(32).toString('hex') → token (64 chars)
  → Salva em magic_links (expires_at = now + 24h)
  → Retorna { token, url, expires_at }

GET /auth/magic-link/:token
  → Valida: exists? expired? used?
  → Marca used=true
  → Retorna JWT
```

### JWT

```typescript
interface TokenPayload {
  id: string;      // UUID do usuário
  email: string;
  role: string;    // tipo_id como string: "1", "2", "3"
}
// Assinado com JWT_SECRET (variável de ambiente)
```

### Middlewares

**AuthMiddleware** (`src/middlewares/AuthMiddleware.ts`):
```typescript
// Extrai "Bearer {token}" do header Authorization
// Valida JWT com JWT_SECRET
// Injeta req.user: TokenPayload
// Retorna 401 se inválido/expirado
```

**RoleMiddleware** (`src/middlewares/RoleMiddleware.ts`):
```typescript
authorizeRole(['1'])      // Apenas ADMIN
authorizeRole(['1', '2']) // ADMIN ou MECANICO
```

> ⚠️ **Estado real:** apesar de implementados, esses middlewares não estão sendo usados nas rotas do backend atualmente.

### Segurança

- **Senhas:** bcrypt 10 rounds. Nunca retornadas em respostas.
- **Clientes WhatsApp:** Criados on-the-fly com senha hash aleatória (bcrypt de 'whatsapp_client_123') — sem acesso por senha real.
- **SQL:** Parameterized queries (`$1`, `$2`, etc.) via pg — proteção contra SQL injection.
- **Firebase:** Credenciais em arquivo `.json` separado (`.gitignore`).
- **Secrets:** Via variáveis de ambiente (`.env` não versionado).

**Risco atual (confirmado no código):**
- Endpoints de negócio (`/usuarios`, `/produtos`, `/orcamentos`, `/execucoes`, etc.) estão sem `authMiddleware`/`authorizeRole` aplicado nas rotas.
- Na prática, o backend depende de proteção externa (rede/gateway) ou está aberto localmente sem controle de acesso por JWT nas handlers.

**Checklist de produção:**
- [ ] JWT_SECRET com 256 bits+ de entropia
- [ ] HTTPS/TLS obrigatório
- [ ] CORS restritivo (apenas domínios do app)
- [ ] Rate limiting por IP/usuário
- [ ] Logs de auditoria para ações críticas
- [ ] Remover ngrok de `package.json` em produção

---

## Convenções e Padrões de Código

### Backend (Node/TS)

- **Tabelas SQL:** `snake_case` (`catalogo_servicos`, `tipos_usuario`)
- **Colunas:** `snake_case`
- **Variáveis TS:** `camelCase`
- **Classes:** `PascalCase` (`UsuarioController`, `UsuarioModel`)
- **Respostas de erro:** `{ error: 'mensagem' }` com status HTTP adequado
- **Prices:** Sempre `INTEGER` em centavos — conversão na camada de apresentação

### AI Service (Node/TS)

- **Tudo em `index.ts`** — sem separação em módulos ainda
- **Prisma** para Customer/ChatLog/ServiceOrder; **pg direto** não usado (apenas via Prisma)
- **LangChain** como wrapper do LLM; resposta esperada como JSON ou texto livre

### Flutter (Dart)

- **Dual repository:** API real vs. mock — facilita desenvolvimento offline e testes
- **Orientação:** Apenas portrait (`portraitUp`)
- **Backend URL:** detectado automaticamente (Android emulador vs. outros)
- **Firebase:** Falhas de init tratadas silenciosamente (app funciona com mock)

---

## Decisões Arquiteturais

| Decisão | Razão | Trade-off |
|---------|-------|-----------|
| **PostgreSQL compartilhado** | Backend e AI Service no mesmo banco | Acoplamento; migrações precisam ser coordenadas (Backend = SQL raw, AI Service = Prisma) |
| **Backend SQL raw (pg)** | Controle total de queries | Mais verboso; sem ORM |
| **AI Service com Prisma** | Geração de tipos, migrations fáceis | Duplicação de modelos (tabelas do backend mapeadas no schema Prisma) |
| **NVIDIA NIM via LangChain** | API remota, sem GPU local | Latência de rede, custo de API, dependência de terceiro |
| **ChromaDB para RAG** | Vector search semântico de produtos | Serviço adicional para manter; embeddings padrão podem ter qualidade limitada |
| **Magic Links** | Autenticação sem senha para clientes | Fluxo mais complexo; tokens podem ser interceptados |
| **Firebase FCM** | Push multiplataforma gerenciado | Vendor lock-in; dados em terceiro |
| **Monorepo** | Compartilhamento de DTOs e configs | Packages ainda não configurados (todos vazios) |
| **Dual repository Flutter** | Desenvolvimento offline e testes | Duplicação de interfaces |

---

## Estado Atual do Projeto

### ✅ Implementado e Operacional

- **Backend** com 14 módulos de rotas funcionais
- **Webhook WhatsApp** completo: recebimento, análise IA, handoff humano (`ia_pausada`), envio de resposta
- **AI Service** monolítico: análise LLM NVIDIA via LangChain, RAG com ChromaDB com embeddings NVIDIA E5, criação de OS end-to-end, 4 endpoints funcionais (`/ai/analyze`, `/ai/create-os`, `/ai/produtos/sync`, `/ai/servicos/sync`)
- **Banco PostgreSQL** com schema completo (16 tabelas) via migrations SQL + seeds de demonstração ricos
- **Autenticação** JWT + Magic Links + login email/senha
- **Firebase Push** com limite 5/usuário/dia (RN049)
- **Backend — 14 modelos de dados e controllers:** Cada módulo de rota (`agendamento`, `usuario`, `veiculo`, etc.) tem:
  - `xController.ts` — handlers HTTP
  - `xModel.ts` — queries diretas ao PostgreSQL (pg raw queries)
  - `xRoutes.ts` — definição de endpoints
  
  Todos os 14 modelos estão implementados e funcionais. Problemas de exportação no barrel export (`models/index.ts`) não impedem operação.

- **Flutter com 13 screens internos + 8 screens clientes:** Ambos os apps (App Interno para mecânicos/gerentes + App Cliente para clientes) têm UI completa com chamadas reais da API. Chat interno possui placeholder `Authorization: YOUR_JWT_TOKEN_HERE`, que precisa ser substituído dinamicamente após login.
- **Padrão dual repository** no Flutter (API real em uso; Mock implementado mas não instanciado)
- **Shared DTOs** TypeScript em `shared/dtos/`
- **Chat bidirecional** funcionário ↔ cliente (via dashboard + WhatsApp)
- **Relatórios** de faturamento, serviços e ticket médio (por dia/mês/ano)
- **RAG Sync automático** ao criar/atualizar produtos
- **Seeds de demonstração ricos**: 4 cenários realistas (OS em execução, agendamento pendente, cancelado, orçamento aguardando aprovação)
- **Recálculo automático de valor_total** em orçamentos ao adicionar/remover itens
- **Backfill de OS**: `ExecucaoServicoModel.backfillFromApprovedBudgets()` garante consistência histórica

### ⚠️ Parcial / Requer Atenção

- **AI Service — modularização parcial:** já existem módulos ativos em `routes/`, `schemas/`, `services/`, `tools/`, `config/` e `vectorstore`; porém `index.ts` ainda concentra responsabilidades importantes. `agents/`, `chains/` e `whatsapp/` permanecem placeholders. Refatoração incremental continua necessária.
- **Autenticação não aplicada nas rotas backend:** `AuthMiddleware` (em `backend/src/middlewares/AuthMiddleware.ts`) e `RoleMiddleware` (em `backend/src/middlewares/RoleMiddleware.ts`) existem, mas **não são montados em nenhuma rota**. Todos os 14 endpoints estão sem proteção de JWT. Prioridade: aplicar em endpoints críticos (`/usuarios/*`, `/orcamentos/*`, `/execucoes/*`, `/produtos/*`, `/reports/*`, `/conversacoes/*`).
- **Risco de IDOR no fluxo de agendamento do cliente:** o app envia `cliente_id` no corpo de `POST /agendamentos`; sem vínculo obrigatório com identidade autenticada no backend, um cliente malicioso pode tentar agir em nome de outro usuário caso conheça UUIDs válidos.
- **Leitura de perfil potencialmente exposta:** o app cliente resolve contexto com `GET /usuarios/:clientId` e `GET /veiculos/cliente/:clientId`; como as rotas ainda não exigem autenticação/autorização, há risco de exposição de dados por enumeração de UUID.
- **Flutter sem sessão JWT efetiva:** o login recebe token, porém os repositórios HTTP do app não persistem/usam esse token de forma consistente.
- **Falha silenciosa no catálogo de serviços (UX):** em `client_schedule_api_repository.dart`, `fetchCatalogoServicos()` retorna `[]` em erro HTTP, mascarando indisponibilidade de backend como "catálogo vazio".
- **Flutter com seeds DEV habilitadas no startup:** `InternoApp` e `ClienteApp` disparam endpoints DEV de notificação ao inicializar.
- **ChromaDB:** Requer instância rodando na porta 8000 (local ou via Docker Compose do projeto).
- **Prisma schema — schema drift:** `orcamentos.observacoes` existe na migration SQL e no DTO mas **não está mapeado no `schema.prisma`** do AI Service. Se o Prisma precisar ler esse campo, o schema precisa ser atualizado.
- **Prisma schema — duplicação:** Duplica tabelas do backend (necessário para Prisma funcionar com banco compartilhado). Manutenção manual necessária se schema mudar.
- **execucao_servico status:** Valores definidos em `execucaoServicoModel.ts`: `AGUARDANDO`, `EM_EXECUCAO`, `REVISAO_TECNICA`, `CONCLUIDO`, `CANCELADO`. O `reportModel.ts` também filtra por `AGUARDANDO_RETIRADA` em queries de relatório.
- **models/index.ts incompleto:** Apenas 7 dos 14 models são re-exportados via barrel export (`oficina`, `usuario`, `veiculo`, `catalogoServico`, `produto`, `agendamento`, `orcamento`). Os demais 7 (`execucaoServico`, `report`, `conversation`, `notification`, `pushToken`, `chatMessage`, `catalogoServicoModel`) devem ser importados via caminho direto (`import { X } from '../models/xModel'`). Backend funciona, mas a organização das exportações é inconsistente.
- **AI Service — migrações Prisma:** O `package.json` não possui scripts de migração; usar CLI do Prisma (`npx prisma migrate deploy` em produção) para manter consistência de schema.
- **AI Service — cobertura de tools:** `src/tools/` já possui implementação de ferramentas de appointment, disponibilidade e histórico; ainda há espaço para expansão de ferramentas de domínio.

### 🔴 Bugs Confirmados

- **NENHUM BUG DE tipo_id DETECTADO:** O webhook em `backend/src/webhook/controller.ts` está criando clientes com `tipo_id: 2` (CLIENTE) corretamente. O AI Service também usa `tipo_id: 2` no `appointment_service.ts`. A documentação anterior que mencionava esse bug parece ter sido corrigida no código.

### ❌ Não Implementado

- **Docker:** `infra/docker/docker-compose.yml` existe e está COMPLETO com definições para PostgreSQL, Redis, ChromaDB, Backend e AI Service. Mas está parcialmente documentado nos arquivos `.ts` — confirmar se está sendo usado em CI/CD.
- **Redis:** Sem código de Redis em nenhum lugar. Pode ser removido do planejamento ou implementado futuramente para cache/filas.
- **packages/:** Todos os packages do monorepo estão **vazios** exceto conteúdo mínimo:
  - `shared/` — contém apenas `.gitkeep`
  - `shared-types/` — vazio
  - `typescript-config/` — vazio
  - `eslint-config/` — vazio  
  - `flutter_core/` — vazio
  
  O monorepo estrutura está configurada mas esses packages nunca foram populados. DTOs reais estão em `shared/dtos/` na raiz.
- **Testes:** Nenhum framework de testes (Jest, Vitest, etc.) instalado ou configurado.
- **Rate limiting:** Sem limitação de requests por IP/usuário.
- **Logging centralizado:** Apenas `console.log/error` — sem estruturado ou agregado.
- **CI/CD:** Sem pipelines de build ou deploy.
- **Modo dev Docker:** Sem bind mount / hot reload para desenvolvimento em containers.
- **Push tokens por plataforma:** Tabela `user_push_tokens` não tem coluna `plataforma` (android/ios) — foi simplificada em relação ao planejado.

---

## Próximos Passos Sugeridos

### 🔴 Alta Prioridade (bloqueadores)

1. **Fechar ciclo de validação JWT ponta a ponta (backend + Flutter):**
   - Confirmar no app em execução que chamadas críticas retornam `401` sem token e `200` com token.
   - Atualizar os testes de widget/integrados do Flutter para o fluxo autenticado atual (as suites atuais ainda falham com expectativas antigas).

2. **Corrigir schema drift do Prisma no AI Service:** Adicionar `observacoes` ao modelo `orcamentos` em `ai_service/prisma/schema.prisma` para manter paridade com a migration SQL e os DTOs.

3. **Implementar suíte mínima de testes automatizados (backend + ai_service):** Cobrir auth, webhook, orçamentos e os endpoints `ai/analyze` + `ai/create-os`.

### 🟡 Média Prioridade (qualidade)

1. **Eliminar payload legado de `usuario_id` no frontend de notificações:** Backend já usa `req.user.id`; agora simplificar os repositórios Flutter para não depender de IDs no body/query.

2. **Desativar gatilhos DEV de notificação em produção:** Alterar `_kEnableDevLowStockSeedOnStartup` e `_kEnableDevClientSeedOnStartup` para `false` por padrão de release.

3. **Adicionar rate limiting em endpoints de negócio expostos:** Além de auth/magic-link, avaliar limites para notificações, chat e push tokens.

4. **Refinar logging estruturado:** Padronizar logger único (ex.: pino) e alinhar `requestId` entre `LoggingMiddleware` e `AuditMiddleware`.

5. **Configurar packages do monorepo (`typescript-config` / `eslint-config`)** para centralizar regras e reduzir divergências entre serviços.

6. **Evoluir contexto conversacional no AI Service:** incorporar histórico real de conversa no pipeline de análise para respostas mais consistentes.

### 🟠 Observações Importantes sobre Infraestrutura

- **docker-compose.yml funcional:** Existe em `infra/docker/docker-compose.yml` e define:
  - PostgreSQL (porta 5432) com volume persistente
  - Redis (porta 6379) — configurado mas sem uso no código backend/ai_service
  - ChromaDB (porta 8000) com volume persistente
  - Backend (porta 3000) — build via Dockerfile
  - AI Service (porta 3001) — build via Dockerfile
  - Todos com healthchecks configurados
  - Rede interna (tiao_net) conecta os serviços
  
  **Uso:** `docker compose up -d` sobe o stack completo. Muito útil para onboarding de novos devs.

- **Variáveis de ambiente:** Esperadas em `.env` na raiz (não commitado por segurança). Template em `.env.example` se existir.

### 🟢 Melhorias (escala e UX)

1. **Filas de processamento assíncrono:** Migrar processamento do webhook para filas (BullMQ ou equivalente) para reduzir risco de timeout da Meta.

2. **Índices no PostgreSQL:** Adicionar índices para colunas de consulta frequente (`cliente_id`, `status`, `telefone`, `criado_em`).

3. **Cache Redis seletivo:** Usar Redis para catálogos e consultas repetitivas de leitura.

4. **Aprimorar embeddings e recuperação semântica:** Avaliar modelo de embeddings em português e estratégia híbrida (vetorial + filtros estruturados).

5. **Aprovação de orçamento via canal conversacional:** Fechar fluxo ponta a ponta (mensagem, aprovação e transição automática de status).

6. **CI/CD:** Configurar pipeline de lint, build, teste e deploy com ambientes separados.

---

## Notas de Desenvolvimento

### Rodando localmente (sem Docker)

```bash
# 1. PostgreSQL e ChromaDB devem estar rodando localmente

# 2. Backend
cd backend
npm install
cp .env.example .env  # preencher variáveis (BASE_URL, API_PORT, JWT_SECRET, DATABASE_URL, etc.)
npm run db:migrate
npm run db:seed       # cria demo data com credenciais hardcoded (ver seção de Seeds acima)
npm run dev           # porta 3000

# 3. AI Service (em outro terminal)
cd ai_service
npm install
cp .env.example .env  # preencher variáveis (NVIDIA_API_KEY, CHROMA_URL, BACKEND_URL, etc.)
npx prisma migrate deploy  # gerencia schema Prisma (NÃO usar npm run db:migrate — arquivo não existe)
npm run dev           # porta 3001

# 4. Flutter (em outro terminal)
cd prototipo
flutter pub get
flutter run           # conecta em localhost:3000 (non-Android) ou 10.0.2.2:3000 (Android)
```

### Credenciais de demo (após seeds)

| Usuário | Email | Senha | tipo_id |
|---------|-------|-------|---------|
| Administrador | admin@omniconnect.com.br | admin_secret_password | 1 (ADMIN) |
| Mecânico Chefe | mecanico@omniconnect.com.br | mecanico_secret_password | 3 (MECANICO) |
| Cliente Teste | cliente@gmail.com | cliente_secret_password | 2 (CLIENTE) |

### Expondo webhook para desenvolvimento

```bash
# No diretório backend:
npx ngrok http 3000
# Copiar URL gerada e configurar no painel da Meta WhatsApp como webhook URL
```

### Arquivos não versionados (segredos)

- `backend/.env`
- `ai_service/.env`
- `backend/firebase-service-account.json`
- `backend/.env_old`

---

*Esta WIKI é a fonte de verdade técnica do projeto. Atualizar após mudanças significativas de arquitetura, schema ou funcionalidades.*
