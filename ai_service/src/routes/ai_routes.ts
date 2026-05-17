import { Router, Request, Response } from 'express';
import { analyzeMessage } from '../services/analyze_service';
import { createOsWorkflow } from '../services/appointment_service';
import { upsertProduto } from '../vectorstore/productVectorStore';
import { upsertServico } from '../vectorstore/serviceVectorStore';
import { upsertAgendamento } from '../vectorstore/agendamentoVectorStore';
import { upsertOrcamento } from '../vectorstore/orcamentoVectorStore';
import { upsertExecucao } from '../vectorstore/execucaoServicoVectorStore';
import { AnalyzeRequestBody, CreateOsBody, ProdutoPayload, ServicoPayload, AgendamentoPayload, OrcamentoPayload, ExecucaoServicoPayload } from '../schemas/ai_schemas';
import { extractBackendErrorMessage, getBackendErrorStatus } from '../utils/backend_error';
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
 * Chamado pelo backend sempre que um agendamento é criado ou atualizado.
 */
router.post('/ai/agendamentos/sync', async (req: Request, res: Response) => {
  const agendamento = req.body as Partial<AgendamentoPayload>;

  if (!agendamento.id || !agendamento.cliente_id) {
    return res.status(400).json({ error: 'id e cliente_id são obrigatórios' });
  }

  await upsertAgendamento(agendamento as AgendamentoPayload);

  return res.json({
    ok: true,
    message: `Agendamento indexado no Vector DB`,
  });
});

/**
 * Chamado pelo backend sempre que um orçamento é criado ou atualizado.
 */
router.post('/ai/orcamentos/sync', async (req: Request, res: Response) => {
  const orcamento = req.body as Partial<OrcamentoPayload>;

  if (!orcamento.id || !orcamento.cliente_id) {
    return res.status(400).json({ error: 'id e cliente_id são obrigatórios' });
  }

  await upsertOrcamento({
    ...orcamento,
    itens_descricao: orcamento.itens_descricao ?? []
  } as OrcamentoPayload);

  return res.json({
    ok: true,
    message: `Orçamento indexado no Vector DB`,
  });
});

/**
 * Chamado pelo backend sempre que uma execução de serviço é criada ou atualizada.
 */
router.post('/ai/execucoes/sync', async (req: Request, res: Response) => {
  const execucao = req.body as Partial<ExecucaoServicoPayload>;

  if (!execucao.id || !execucao.cliente_id) {
    return res.status(400).json({ error: 'id e cliente_id são obrigatórios' });
  }

  await upsertExecucao(execucao as ExecucaoServicoPayload);

  return res.json({
    ok: true,
    message: `Execução de serviço indexada no Vector DB`,
  });
});

/**
 * Análise de mensagem com contexto RAG
 */

router.post('/ai/analyze', async (req: Request, res: Response) => {
  const { message, number, conversacaoId } = req.body as AnalyzeRequestBody;

  if (!message || !number) {
    return res.status(400).json({ error: 'Mensagem e número são obrigatórios.' });
  }

  try {
    const result = await analyzeMessage(message, number, conversacaoId);
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
    const status = getBackendErrorStatus(err);
    const message = extractBackendErrorMessage(err, 'Erro ao criar OS.');
    console.error('[OS] Erro no sub-agente de criação de OS:', { status, message });
    return res.status(status).json({ error: message });
  }
});

export default router;
