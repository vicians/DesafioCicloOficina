# =============================================================================
# ESTÁGIO 1: builder
# Instala todas as dependências (incluindo dev) e compila o TypeScript.
# =============================================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copiamos package.json primeiro (aproveitamos o cache do Docker para npm install)
COPY package*.json ./

# Instalamos TUDO (incluindo devDependencies como typescript, ts-node, prisma CLI)
RUN npm install

# Copiamos o schema do Prisma ANTES do código (outro ponto de cache útil)
COPY prisma ./prisma/

# O Prisma precisa "gerar" o client JavaScript a partir do schema.prisma.
# Esse comando lê o schema e cria o código em node_modules/@prisma/client.
# Deve acontecer DEPOIS do npm install e ANTES do build TypeScript.
RUN npx prisma generate

# Agora copiamos o restante do código-fonte
COPY src ./src
COPY tsconfig.json ./
COPY prisma.config.ts ./

# Compilamos TypeScript → gera /app/dist (rootDir é ./src, outDir é ./dist)
RUN npm run build

# =============================================================================
# ESTÁGIO 2: runner (imagem final)
# Imagem limpa apenas com o necessário para rodar.
# =============================================================================
FROM node:20-alpine AS runner

ENV NODE_ENV=production

WORKDIR /app

# Instalamos só dependências de produção
COPY package*.json ./
RUN npm install --omit=dev

# O Prisma Client precisa do schema para funcionar em runtime (query engine)
# Copiamos o schema e geramos o client novamente na imagem de produção
COPY prisma ./prisma/
COPY prisma.config.ts ./
RUN npx prisma generate

# Copiamos o código JavaScript compilado do estágio builder
COPY --from=builder /app/dist ./dist

# Porta que o serviço expõe
EXPOSE 3001

# Healthcheck via HTTP: o AI Service tem a rota GET /health implementada
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:3001/health || exit 1

# Inicia o serviço
# rootDir era ./src, então o arquivo compilado fica em dist/index.js
CMD ["node", "dist/index.js"]
