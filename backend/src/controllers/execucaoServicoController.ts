import { Request, Response } from 'express';
import { ExecucaoServicoModel } from '../models/execucaoServicoModel';

const STATUS_FINALIZAVEIS = ['EM_EXECUCAO', 'REVISAO_TECNICA'];

export class ExecucaoServicoController {
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

  /**
   * Finaliza a execução e registra o histórico de serviço concluído.
   * Rejeita finalização se o status atual não permitir transição para CONCLUIDO.
   */
  static async finalizar(req: Request, res: Response) {
    const execucao = await ExecucaoServicoModel.findById(req.params.id);

    if (!execucao) {
      return res.status(404).json({ error: 'Execução não encontrada' });
    }

    if (!STATUS_FINALIZAVEIS.includes(execucao.status)) {
      return res.status(409).json({
        error: `Não é possível finalizar uma execução com status "${execucao.status}". Status permitidos: ${STATUS_FINALIZAVEIS.join(', ')}`,
      });
    }

    const finalizada = await ExecucaoServicoModel.finalizar(req.params.id);
    return res.json(finalizada);
  }
}
