import { Router, Request, Response } from 'express';
import { analyzeMessage } from '../services/analyze_service';
import { createOsWorkflow } from '../services/appointment_service';
import { upsertProduto } from '../vectorstore/productVectorStore';
import { upsertServico } from '../vectorstore/serviceVectorStore';
import { AnalyzeRequestBody, CreateOsBody, ProdutoPayload, ServicoPayload } from '../schemas/ai_schemas';

const router = Router();

/**
 * Chamado pelo backend sempre que um produto é criado ou atualizado.
 */

router.post('/ai/produtos/sync', async (req: Request, res: Response) => {
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

/**
 * Chamado pelo backend sempre que um serviço do catálogo é criado ou atualizado.
 */

router.post('/ai/servicos/sync', async (req: Request, res: Response) => {
  const servico = req.body as Partial<ServicoPayload>;

  if (!servico.id || !servico.nome) {
    return res.status(400).json({ error: 'id e nome são obrigatórios' });
  }

  await upsertServico({
    id: servico.id,
    nome: servico.nome,
    descricao: servico.descricao ?? '',
    preco: servico.preco ?? 0,
    duracao_minutos: servico.duracao_minutos ?? 0,
  });

  return res.json({
    ok: true,
    message: `Serviço "${servico.nome}" indexado no Vector DB`,
  });
});

/**
 * Análise de mensagem com contexto RAG
 */

router.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message, number } = req.body as AnalyzeRequestBody;

  if (!message || !number) {
    return res.status(400).json({ error: 'Mensagem e número são obrigatórios.' });
  }

  try {
    const result = await analyzeMessage(message, number);
    return res.json(result);
  } catch (error) {
    console.error('Erro no fluxo do ai_service:', error);
    return res.status(500).json({ error: 'Erro ao processar consulta.' });
  }
});

/**
 * Sub-Agent: Criação de OS
 */

router.post('/ai/create-os', async (req: Request, res: Response) => {
  const body = req.body as CreateOsBody;

  try {
    const result = await createOsWorkflow(body);
    return res.status(201).json({
      ok: true,
      ...result,
    });
  } catch (err: any) {
    console.error('[OS] Erro no sub-agente de criação de OS:', err.message);
    return res.status(err.response?.status ?? 500).json({ error: err.message });
  }
});

export default router;