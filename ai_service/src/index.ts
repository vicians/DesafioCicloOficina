import 'express-async-errors';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import dotenv from 'dotenv';
import { ChatOpenAI } from '@langchain/openai';
import { upsertProduto, queryProdutos, ProdutoPayload } from './vectorstore/productVectorStore';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;

const model = new ChatOpenAI({
  apiKey: process.env.NVIDIA_API_KEY,
  configuration: {
    baseURL: process.env.NVIDIA_BASE_URL,
  },
  modelName: process.env.AI_MODEL,
  temperature: 0.3,
});

// 4. Rotas de Monitorização e Processamento
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'CicloOficina AI Service',
    model: process.env.AI_MODEL
  });
});

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

/**
 * Chamado pelo backend sempre que um produto é criado ou atualizado.
 * Indexa o produto no ChromaDB para que a IA possa responder perguntas
 * sobre preços com informações sempre atualizadas.
 */
app.post('/ai/produtos/sync', async (req: Request, res: Response) => {
  const produto = req.body as Partial<ProdutoPayload>;

  if (!produto.id || !produto.nome) {
    return res.status(400).json({ error: 'id e nome são obrigatórios' });
  }

  await upsertProduto({
    id: produto.id,
    nome: produto.nome,
    valor: produto.valor ?? 0,
    quantidade_estoque: produto.quantidade_estoque ?? 0,
    marca: produto.marca,
  });

  return res.json({
    ok: true,
    message: `Produto "${produto.nome}" indexado no Vector DB`,
  });
});

// ── Análise de mensagem com contexto RAG ──────────────────────────────────────

app.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message, number } = req.body;

  // 1. Validação de entrada (Ambas as branches pediam message, feat pedia number)
  if (!message || !number) {
    return res.status(400).json({ error: "Mensagem e número são obrigatórios." });
  }

  try {
    // 2. Consulta o status do cliente no Prisma (Lógica da feat/AiWebhook)
    let customer = await prisma.customer.findUnique({
      where: { whatsappNumber: number }
    });

    // 3. Bloqueio se o atendimento for humano
    if (customer?.status === 'HUMAN') {
      return res.json({
        result: null,
        action: 'MANUAL_WAIT',
        info: 'O atendimento está sendo realizado por um humano.'
      });
    }

    // 4. Busca de contexto no Vector DB (Lógica RAG da developer)
    const ragDocs = await queryProdutos(message);
    const contextBlock =
      ragDocs.length > 0
        ? `\n\nProdutos e preços disponíveis na oficina:\n${ragDocs.map((d) => `- ${d}`).join('\n')}`
        : '';

    // 5. Chamada do Modelo com System Prompt unificado
    const response = await model.invoke([
      [
        'system',
        `És o assistente virtual da CicloOficina. O teu objetivo é identificar se o cliente precisa de Borracharia ou Oficina Mecânica com base no texto, e informar preços de produtos quando solicitado.${contextBlock}`,
      ],
      ['user', message],
    ]);

    // 6. Retorno formatado (Unindo o conteúdo da IA com a estrutura de ação)
    return res.json({ 
      result: response.content,
      action: 'REPLY' 
    });

  } catch (error) {
    console.error("Erro no fluxo do ai_service:", error);
    return res.status(500).json({ error: "Erro ao processar consulta." });
  }
});

// ── Error handler ─────────────────────────────────────────────────────────────

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('AI_SERVICE_ERROR:', err.message);
  res.status(500).json({ error: 'Erro interno no processamento de IA.' });
});

app.listen(PORT, () => {
  console.log(`🚀 AI Service da CicloOficina online na porta ${PORT}`);
});
