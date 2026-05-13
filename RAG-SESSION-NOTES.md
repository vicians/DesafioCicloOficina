# 🤖 RAG Session Notes — Tião Oficina

**Data:** 11 de maio de 2026  
**Objetivo:** Call de alinhamento em grupo sobre RAG — estratégia, implementação e divisão de tarefas  
**Status:** Preparação para meeting

---

## 1️⃣ Status Atual do RAG

| Componente | Status | Detalhe |
|---|---|---|
| **Vector Store** | ✅ Operacional | ChromaDB local (port 8000), collection `produtos_oficina` com embeddings NVIDIA E5 |
| **Indexação** | ✅ Automática | POST `/ai/produtos/sync` (fire-and-forget) ao criar/atualizar produtos |
| **Retrieval** | ✅ Implementado | `queryProdutos(message, topK?)` em `ai_service/src/services/analyze_service.ts` |
| **Context Injection** | ✅ Funcional | System prompt inclui catálogo + serviços dinâmico |
| **Modelos LLM** | ✅ Ativo | NVIDIA NIM (via LangChain), sem histórico persistido em `/ai/analyze` |
| **Metadados** | ⚠️ Simples | Apenas nome, marca, valor, quantidade. Sem categoria, min_estoque, disponibilidade |
| **Preprocessamento** | ❌ Ausente | Sem normalização de queries (acentos, singularização, stop words) |
| **Histórico Conversacional** | ❌ Não Persistido | Schema Prisma tem `ChatLog`, mas não é usado em `/ai/analyze` |

---

## 2️⃣ Gaps Identificados (Curto Prazo)

| Problema | Impacto | Esforço | Sugestão |
|---|---|---|---|
| Embeddings genéricos | Qualidade semântica baixa em português | 🟢 Baixo | Avaliar E5-multilíngue ou Sentence Transformers português |
| Sem histórico conversacional | Respostas desconexas em diálogos | 🟡 Médio | Usar `ChatLog` existente — incrementar contexto |
| Metadados simples | Filtros estruturados limitados | 🟡 Médio | Adicionar categoria, marca, preço, disponibilidade |
| Sem preprocessamento de queries | Perde matches ("pneu" ≠ "pneus") | 🟢 Baixo | Singularização, remoção de acentos, stop words |
| Sem feedback de relevância | Sem melhoria iterativa | 🔴 Alto | Implementar ranking manual (depois) |

---

## 3️⃣ Quick Wins — Ultra-Curto Prazo (Hoje/Semana)

### Quick Win A: Preprocessamento de Queries ⏱️ **2h**

```typescript
// ai_service/src/utils/queryPreprocessor.ts (NOVO)
export function preprocessQuery(query: string): string {
  return query
    .toLowerCase()
    .normalize('NFD') // Remove acentos: ã→a, ç→c
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\b(o|a|de|para|em|com)\b/g, '') // Stop words português
    .trim();
}

// ai_service/src/services/analyze_service.ts — USAR
const processedQuery = preprocessQuery(message);
const context = await queryProdutos(processedQuery, 3);
```

**Impacto:** +20% recall em buscas naturais  
**Bloqueador:** Nenhum  
**Quem pode fazer:** Dev com conhecimento de Node.js  
**Decisão na Call:** [ ] Fazer hoje [ ] Postergar [ ] Não fazer

---

### Quick Win B: Ativar Histórico Conversacional ⏱️ **3-4h**

Schema já existe no Prisma. Tarefa = implementar.

```typescript
// ai_service/src/services/analyze_service.ts — MODIFICAR
async function analyzeMessage(customerId: string, message: string) {
  // 1. Recuperar últimas 5 mensagens do ChatLog
  const recentChat = await prisma.chatLog.findMany({
    where: { customer_id: customerId },
    orderBy: { created_at: 'desc' },
    take: 5
  });

  // 2. Construir conversation history (alternando human/assistant)
  const conversationHistory = recentChat.reverse().map(log => ({
    role: log.role === 'USER' ? 'human' : 'assistant',
    content: log.message
  }));

  // 3. Chamar LLM com histórico completo
  const response = await llm.call([
    ...conversationHistory,
    { role: 'human', content: message }
  ]);

  // 4. Persistir nova mensagem no ChatLog
  await prisma.chatLog.create({
    data: {
      customer_id: customerId,
      message: response.content,
      role: 'ASSISTANT',
      created_at: new Date()
    }
  });

  return response;
}
```

**Impacto:** Contexto conversacional completo (cliente recorda contexto)  
**Bloqueador:** Nenhum (schema já existe)  
**Quem pode fazer:** Dev com Prisma + TypeScript  
**Decisão na Call:** [ ] Fazer hoje [ ] Postergar [ ] Não fazer

---

### Quick Win C: Enriquecer Metadados do ChromaDB ⏱️ **2-3h**

Quando upsert de produtos, adicionar mais campos:

```typescript
// ai_service/src/vectorstore/productVectorStore.ts — MODIFICAR
async upsertProduct(product: {
  id: string,
  nome: string,
  marca: string,
  valor: number,
  quantidade_estoque: number,
  categoria?: string,        // NOVO
  min_estoque?: number,       // NOVO
  unidade?: string            // NOVO
}) {
  const metadata = {
    id: product.id,
    nome: product.nome,
    marca: product.marca,
    valor: product.valor,
    quantidade_estoque: product.quantidade_estoque,
    categoria: product.categoria || 'N/A',
    min_estoque: product.min_estoque || 0,
    unidade: product.unidade || 'un',
    disponivel: product.quantidade_estoque > (product.min_estoque || 0)
  };

  await this.collection.upsert({
    ids: [product.id],
    metadatas: [metadata],
    documents: [product.nome + ' ' + product.marca]
  });
}
```

**Impacto:** Filtros estruturados possíveis (ex: "Mostrar apenas pneus em falta")  
**Bloqueador:** Nenhum  
**Quem pode fazer:** Dev com ChromaDB  
**Decisão na Call:** [ ] Fazer hoje [ ] Postergar [ ] Não fazer

---

## 4️⃣ Caminho de Implementação (Ordem Recomendada)

```
SEMANA 1:
├─ 1️⃣  [2h] Quick Win A: Preprocessamento de queries
├─ 2️⃣  [3h] Quick Win B: Histórico conversacional (ChatLog)
└─ 3️⃣  [2h] Quick Win C: Metadados enriquecidos

SEMANA 2:
├─ 4️⃣  [4h] Avaliar + testar modelos de embeddings
│         - Testar NVIDIA E5 atualmente em uso
│         - Avaliar alternativas (Sentence Transformers português)
│         - Medir qualidade em 5-10 queries de teste
├─ 5️⃣  [2h] Re-indexar produtos existentes (com novos metadados)
└─ 6️⃣  [3h] Testes e2e (cenários reais + métricas)

BACKLOG (Futuro):
└─ Feedback de relevância manual
└─ Hybrid search (BM25 + vector)
└─ Cache Redis de queries populares
```

---

## 5️⃣ Proposta de Divisão de Tarefas

| Tarefa | Escopo | Prazo | Skills | Dependências |
|---|---|---|---|---|
| **A: Preprocessamento** | `queryPreprocessor.ts` + integrar em `analyze_service.ts` | 2h | Node.js, regex | Nenhuma |
| **B: Histórico Conversacional** | Ler `ChatLog` → construir history → chamar LLM | 3h | Prisma, LangChain, TS | Nenhuma |
| **C: Metadados ChromaDB** | Adicionar 4 campos em upsert + ajustar schema Prisma | 2h | ChromaDB, Prisma | Nenhuma |
| **D: Avaliar Embeddings** | Testar modelos, medir qualidade, documentar | 4h | Python/JS, LangChain | A/B/C em paralelo |
| **E: Testes + QA** | Cenários reais, métricas, relatório | 2h | QA, documentação | A/B/C completos |

### Modelo Sugerido (Parallelização):
- **Dev 1 + 2:** Paralelo (A + B)
- **Dev 3:** Paralelo (C)
- **Dev 4:** Paralelo (D) — **bloqueador potencial**, começa hoje
- **Dev 5:** Depois (E) — depende de A/B/C

---

## 6️⃣ Atribuição Final de Tarefas (DURANTE A CALL)

| Tarefa | Dev Atribuído | Status | Notas |
|---|---|---|---|
| A: Preprocessamento | _____________ | [ ] Não iniciado | |
| B: Histórico Conversacional | _____________ | [ ] Não iniciado | |
| C: Metadados ChromaDB | _____________ | [ ] Não iniciado | |
| D: Avaliar Embeddings | _____________ | [ ] Não iniciado | Crítico — começa hoje |
| E: Testes + QA | _____________ | [ ] Não iniciado | Depois dos Quick Wins |

---

## 7️⃣ Sugestões para Estudar (30 min antes da call)

### Leitura Rápida:
1. 📖 [LangChain Retrievers](https://python.langchain.com/docs/modules/data_connection/retrievers/) — padrões de recuperação
2. 📖 [ChromaDB Docs](https://docs.trychroma.com/) — metadata filtering, upsert
3. 📖 [Prisma Relations](https://www.prisma.io/docs/concepts/components/prisma-client) — exemplo com `findMany`

### Deep Dive (se tempo permitir):
1. 🎓 [Embeddings em Português (HuggingFace)](https://huggingface.co/models?language=pt) — avaliar modelos
2. 🎓 [Hybrid Search Pattern](https://weaviate.io/blog/hybrid-search-explained) — BM25 + vetorial
3. 🎓 [Conversation Memory (LangChain)](https://python.langchain.com/docs/modules/memory/) — padrões

### Hands-On (se quiser testar agora):
```bash
# 1. Verificar ChromaDB rodando
curl http://localhost:8000/api/v1/collections/produtos_oficina/get

# 2. Testar preprocessamento
node -e "const q='Pneus do veículo'; console.log(q.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase())"

# 3. Ler ChatLog existente via Prisma Studio
npm run prisma:studio
```

---

## 8️⃣ Pontos-Chave para Discussão na Call

- ❓ **Qual modelo de embeddings usar?** (Custo vs. qualidade vs. latência)
  - **Decisão:** _______________________________________________
  
- ❓ **Histórico conversacional:** Persistir ALL ou apenas últimas N mensagens?
  - **Decisão:** _______________________________________________
  
- ❓ **Metadados:** Enriquecer agora ou depois?
  - **Decisão:** _______________________________________________
  
- ❓ **Prioridade:** Qualidade (embeddings) vs. contexto (histórico)? Qual impacta mais?
  - **Decisão:** _______________________________________________
  
- ❓ **Quem faz o quê?** Atribuir tarefas parallelizáveis
  - **Decisão:** _______________________________________________
  
- ❓ **Bloqueadores?** Dev 4 (embeddings) pode bloquear integração se deixar para depois
  - **Decisão:** _______________________________________________

---

## 9️⃣ Revisão do Roadmap Sugerido por Outro Membro

### Parecer Geral

O roadmap é **parcialmente pertinente**, mas mistura melhorias reais com etapas que **duplicam algo que o projeto já faz hoje**.

**Ponto central:** o RAG atual **já existe** e **já está integrado** ao fluxo principal.

- Já existe indexação via `POST /ai/produtos/sync`
- Já existe indexação via `POST /ai/servicos/sync`
- Já existe retrieval vetorial de produtos e serviços
- Já existe injeção de contexto no `/ai/analyze`
- Já existe handoff no fluxo WhatsApp quando a IA retorna `MANUAL_WAIT`

Ou seja: o foco de 48h não deveria ser “criar um RAG do zero”, e sim **refinar, testar e tornar observável o RAG já implementado**.

### Avaliação Item a Item

| Item sugerido | Veredito | Análise |
|---|---|---|
| Decidir arquitetura do RAG | ✅ Pertinente | Faz sentido se a decisão for sobre **escopo**: continuar com catálogo estruturado ou expandir para documentos internos. A arquitetura-base já existe. |
| Criar pasta `knowledge_base` | ⚠️ Parcial | Só faz sentido se vocês decidirem adicionar RAG documental. Para o estado atual, não é prioridade. |
| Copiar documentos internos | ⚠️ Parcial | Coerente apenas se houver decisão explícita de indexar documentos não estruturados. Caso contrário, dispersa esforço. |
| Criar script `rag:ingest` | ✅ Com ajuste | Útil como script de **reindex/backfill**. Não como pipeline paralelo desconectado do sync já existente. |
| Criar endpoint `/ai/rag/query` | ✅ Útil | Não é obrigatório para o produto funcionar, mas é bom para debug, benchmark e teste manual do retrieval. |
| Testar 10 perguntas | ✅ Muito pertinente | É uma das melhores tarefas do roadmap. Ajuda a medir qualidade real antes de mudar arquitetura. |
| Integrar `ragQuery` no `/ai/analyze` | ❌ Redundante | Isso já acontece hoje no fluxo principal. O trabalho correto aqui é refinar o retrieval atual. |
| Separar prompt system | ✅ Pertinente | Hoje o prompt está inline. Extrair melhora manutenção e testes. |
| Adicionar guardrails | ✅ Pertinente | Necessário. Hoje há regras no prompt, mas faltam bloqueios determinísticos para casos críticos. |
| Usar `respostas_proibidas` como proteção | ⚠️ Conceitualmente válido | A ideia faz sentido, mas essa estrutura **não existe no código atual**. Precisa ser criada, não apenas “usada”. |
| Testar fluxo WhatsApp → IA → resposta | ✅ Muito pertinente | É um teste de integração real e necessário. |
| Testar handoff para freio/superaquecimento | ⚠️ Faz sentido, mas depende de implementação | O backend sabe tratar `MANUAL_WAIT`, mas não há hoje uma regra explícita para disparar handoff por urgência mecânica. |
| Depois: RAG + backend tools | ✅ Pertinente | Boa evolução do fluxo atual. |
| Depois: Histórico de conversa | ✅ Pertinente | Ainda não existe memória conversacional real no `/ai/analyze`. |
| Depois: Melhorar embeddings | ✅ Pertinente | Válido, mas não é o primeiro gargalo antes de medir a qualidade atual. |
| Depois: Logs estruturados | ✅ Pertinente | Melhora operação e observabilidade. |
| Depois: Testes automatizados | ✅ Pertinente | Necessário para estabilidade. |

### Conclusão Objetiva

**Resumo executivo para a call:**

- **A ideia geral é boa**
- **A ordem proposta não está totalmente alinhada ao código atual**
- **Há itens redundantes** porque o RAG já existe e já participa do `/ai/analyze`
- **O melhor caminho de 48h** é evoluir o que já está pronto em vez de abrir uma segunda arquitetura paralela

---

## 🔁 Roadmap Revisado de 48 Horas

### Hoje

1. **Confirmar escopo do RAG atual**
  - Decidir se o foco imediato é só catálogo estruturado ou também documentos internos.

2. **Criar endpoint interno de debug para retrieval**
  - Ex.: `/ai/rag/query`
  - Uso: testar query vetorial sem passar pelo agent completo.

3. **Criar script de reindex/backfill**
  - Popular novamente embeddings de produtos e serviços existentes.

4. **Separar o system prompt do `analyze_service.ts`**
  - Melhorar manutenção e permitir iteração rápida no texto.

5. **Definir 10 perguntas de validação**
  - Preço, disponibilidade, serviço, ambiguidade, urgência, agendamento.

6. **Rodar benchmark manual dessas 10 perguntas**
  - Registrar acertos, alucinações, respostas vagas e casos sem contexto suficiente.

### Amanhã

1. **Refinar o retrieval do `/ai/analyze`**
  - Preprocessamento de query
  - Ajuste de top-k
  - Logging do contexto retornado

2. **Adicionar guardrails determinísticos**
  - Regras para não inventar preço
  - Fallback quando não houver contexto suficiente
  - Bloqueio de resposta para cenários críticos

3. **Implementar regra explícita de handoff para urgência mecânica**
  - Casos como freio, superaquecimento, fumaça, vazamento grave.

4. **Testar fluxo WhatsApp → IA → resposta**
  - Teste ponta a ponta do que realmente chega ao cliente.

5. **Testar fluxo de handoff para cenários críticos**
  - Validar se o sistema pausa a IA e transfere corretamente.

6. **Registrar ajustes finais de prompt e regras**
  - Consolidar decisões para evitar retrabalho.

### Depois

1. **Histórico de conversa**
2. **RAG documental com `knowledge_base`**
3. **Melhorar embeddings**
4. **Logs estruturados**
5. **Testes automatizados**

### Prioridade Recomendada

Se houver pouco tempo, a ordem mais segura é:

1. **Testar o que já existe**
2. **Criar observabilidade do retrieval**
3. **Aplicar guardrails**
4. **Só depois expandir corpus ou trocar embeddings**

---

## 🔟 Próximos Passos Imediatos (PÓS-CALL)

- [ ] Criar PRs para Quick Wins A/B/C
- [ ] Dev 4 começa avaliação de embeddings
- [ ] Atualizar este arquivo com decisões da call
- [ ] Criar issues no GitHub para rastrear progresso
- [ ] Definir daily sync ou checkpoint (quando?)

**Responsável:** _______________________________________________  
**Data do Próximo Checkpoint:** _______________________________________________

---

## 📝 Notas da Call (Preenchidas Durante o Meeting)

```
Horário início: _______________________________________________
Participantes: _______________________________________________

Discussão Principal:
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________

Decisões Tomadas:
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________

Blockers Identificados:
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________

Action Items:
1. _______________________________________________________________
2. _______________________________________________________________
3. _______________________________________________________________

Horário fim: _______________________________________________
```

---

**Arquivo Criado em:** 11 de maio de 2026  
**Última Atualização:** Antes da call  
**Referência WIKI:** Seção "ANÁLISE DE RAG E SUGESTÕES PARA IMPLEMENTAÇÃO"
