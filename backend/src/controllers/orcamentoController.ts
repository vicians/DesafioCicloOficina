import { Request, Response } from 'express';
import { OrcamentoModel } from '../models/orcamentoModel';

export class OrcamentoController {
  static async index(req: Request, res: Response) {
    const orcamentos = await OrcamentoModel.findAll();
    return res.json(orcamentos);
  }

  static async store(req: Request, res: Response) {
    const data = req.body;

    if (!data.cliente_id || !data.funcionario_id) {
      return res.status(400).json({ error: 'Cliente e Funcionário são obrigatórios' });
    }

    const orcamento = await OrcamentoModel.create(data);
    return res.status(201).json(orcamento);
  }
}
