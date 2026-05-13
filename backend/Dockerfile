# =============================================================================
# ESTÁGIO 1: builder
# Aqui instalamos TUDO e compilamos o TypeScript.
# Esse estágio existe apenas para gerar o /dist — não vai para produção.
# =============================================================================
FROM node:20-alpine AS builder

# Criamos e entramos na pasta de trabalho dentro do container
WORKDIR /app

# --- Copiamos os package.json antes do restante do código ---
# Isso é uma otimização: o Docker cacheia cada instrução. Se só o código mudar
# (mas não o package.json), ele reutiliza o cache do npm install — muito mais rápido.
COPY backend/package*.json ./backend/

# Copiamos o package da pasta shared (DTOs compartilhados que o backend importa)
COPY shared/ ./shared/

# Instalamos TODAS as dependências (incluindo devDependencies, que tem o TypeScript)
WORKDIR /app/backend
RUN npm install

# Agora copiamos o restante do código-fonte
WORKDIR /app
COPY backend/src ./backend/src
COPY backend/tsconfig.json ./backend/tsconfig.json

# Compilamos o TypeScript → gera a pasta /dist
WORKDIR /app/backend
RUN npm run build

# =============================================================================
# ESTÁGIO 2: runner (imagem final)
# Aqui só trazemos o que é necessário para rodar a aplicação.
# Resultado: imagem menor, mais rápida e mais segura.
# =============================================================================
FROM node:20-alpine AS runner

# Define o ambiente como produção (desativa logs de desenvolvimento, etc.)
ENV NODE_ENV=production

# Trabalhamos dentro de /app/backend para espelhar a estrutura do builder
WORKDIR /app/backend

# Copiamos apenas o package.json para instalar só dependências de produção
COPY backend/package*.json ./

# --omit=dev instala apenas o que está em "dependencies" (sem devDependencies)
RUN npm install --omit=dev

# Copiamos o código compilado do estágio anterior.
# No tsconfig o rootDir é ".." (raiz do monorepo), então o TypeScript gera:
#   backend/dist/backend/src/server.js
#   backend/dist/shared/dtos/...
# Por isso copiamos toda a pasta dist/ do builder para ./dist/ aqui.
COPY --from=builder /app/backend/dist ./dist

# Expõe a porta que o servidor vai escutar (documentação; não abre a porta sozinho)
EXPOSE 3000

# Healthcheck: verifica se a porta 3000 está aceitando conexões TCP.
# Usamos netcat (nc) porque o backend não tem rota /health.
# O AI Service tem /health e usa wget; aqui usamos nc (mais simples para TCP).
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD nc -z localhost 3000 || exit 1

# Comando que inicia a aplicação quando o container sobe
# Caminho corresponde ao outDir + estrutura gerada pelo rootDir ".."
CMD ["node", "dist/backend/src/server.js"]
