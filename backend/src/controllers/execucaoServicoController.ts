import { Request, Response } from 'express';
import { ExecucaoServicoModel } from '../models/execucaoServicoModel';

const STATUS_PERMITIDOS = [
  'AGUARDANDO',
  'EM_EXECUCAO',
  'REVISAO_TECNICA',
  'AGUARDANDO_RETIRADA',
  'CONCLUIDO',
  'CANCELADO',
];

export class ExecucaoServicoController {
  static async index(req: Request, res: Response) {
    const execucoes = await ExecucaoServicoModel.findAll();
    return res.json(execucoes);
  }

  static async show(req: Request, res: Response) {
    const execucao = await ExecucaoServicoModel.findById(req.params.id);
    if (!execucao) return res.status(404).json({ error: 'Execução não encontrada' });
    return res.json(execucao);
  }

  static async showByOrcamento(req: Request, res: Response) {
    const execucao = await ExecucaoServicoModel.findByOrcamentoId(req.params.orcamentoId);
    if (!execucao) return res.status(404).json({ error: 'Execução não encontrada para este orçamento' });
    return res.json(execucao);
  }

  static async updateNotas(req: Request, res: Response) {
    const { notas_internas } = req.body;

    if (!notas_internas) {
      return res.status(400).json({ error: 'notas_internas é obrigatório' });
    }

    const execucao = await ExecucaoServicoModel.updateNotas(req.params.id, notas_internas);
    if (!execucao) return res.status(404).json({ error: 'Execução não encontrada' });
    return res.json(execucao);
  }

  static async updateStatus(req: Request, res: Response) {
    const rawStatus = req.body?.status;

    if (!rawStatus || typeof rawStatus !== 'string') {
      return res.status(400).json({ error: 'status é obrigatório' });
    }

    const status = rawStatus.trim().toUpperCase();
    if (!STATUS_PERMITIDOS.includes(status)) {
      return res.status(400).json({
        error: `status inválido. Permitidos: ${STATUS_PERMITIDOS.join(', ')}`,
      });
    }

    const execucaoAtual = await ExecucaoServicoModel.findById(req.params.id);
    if (!execucaoAtual) {
      return res.status(404).json({ error: 'Execução não encontrada' });
    }

    const execucao = await ExecucaoServicoModel.updateStatus(req.params.id, status);
    return res.json(execucao);
  }

  /**
   * Finaliza a execução e registra o histórico de serviço concluído.
   * Rejeita finalização se o status atual não permitir transição para CONCLUIDO.
   */
  static async finalizar(req: Request, res: Response) {
    const execucao = await ExecucaoServicoModel.findById(req.params.id);

    if (!execucao) {
      return res.status(404).json({ error: 'Execução não encontrada' });
    }

    const statusFinalizaveis = ['EM_EXECUCAO', 'REVISAO_TECNICA', 'AGUARDANDO_RETIRADA'];
    if (!statusFinalizaveis.includes(execucao.status)) {
      return res.status(409).json({
        error: `Não é possível finalizar uma execução com status "${execucao.status}". Status permitidos: ${statusFinalizaveis.join(', ')}`,
      });
    }

    const finalizada = await ExecucaoServicoModel.finalizar(req.params.id);
    return res.json(finalizada);
  }
}
