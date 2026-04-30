import 'express-async-errors';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
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

// ── Health ────────────────────────────────────────────────────────────────────

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'CicloOficina AI Service',
    model: process.env.AI_MODEL,
  });
});

// ── RAG: sincronizar produto no Vector DB ─────────────────────────────────────

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
  const { message } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'A mensagem é obrigatória.' });
  }

  // Busca produtos relevantes no Vector DB para enriquecer a resposta
  const ragDocs = await queryProdutos(message);
  const contextBlock =
    ragDocs.length > 0
      ? `\n\nProdutos e preços disponíveis na oficina:\n${ragDocs.map((d) => `- ${d}`).join('\n')}`
      : '';

  const response = await model.invoke([
    [
      'system',
      `És o assistente virtual da CicloOficina. O teu objetivo é identificar se o cliente precisa de Borracharia ou Oficina Mecânica com base no texto, e informar preços de produtos quando solicitado.${contextBlock}`,
    ],
    ['user', message],
  ]);

  return res.json({ result: response.content });
});

// ── Error handler ─────────────────────────────────────────────────────────────

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('AI_SERVICE_ERROR:', err.message);
  res.status(500).json({ error: 'Erro interno no processamento de IA.' });
});

app.listen(PORT, () => {
  console.log(`🚀 AI Service da CicloOficina online na porta ${PORT}`);
});
