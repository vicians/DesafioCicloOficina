import { Request, Response } from 'express';
import { AgendamentoModel } from '../models/agendamentoModel';

export class AgendamentoController {
  static async index(req: Request, res: Response) {
    const agendamentos = await AgendamentoModel.findAll();
    return res.json(agendamentos);
  }

  static async listByCliente(req: Request, res: Response) {
    const { clienteId } = req.params;
    const agendamentos = await AgendamentoModel.findByClienteId(clienteId);
    return res.json(agendamentos);
  }

  static async store(req: Request, res: Response) {
    const data = req.body;

    if (!data.cliente_id || !data.veiculo_id || !data.agendado_para) {
      return res.status(400).json({ error: 'Cliente, Veículo e Data são obrigatórios' });
    }

    const agendamento = await AgendamentoModel.create(data);
    return res.status(201).json(agendamento);
  }
}
