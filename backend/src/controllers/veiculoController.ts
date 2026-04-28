import { Request, Response } from 'express';
import { VeiculoModel } from '../models/veiculoModel';

export class VeiculoController {
  static async index(req: Request, res: Response) {
    const veiculos = await VeiculoModel.findAll();
    return res.json(veiculos);
  }

  static async show(req: Request, res: Response) {
    const { id } = req.params;
    const veiculo = await VeiculoModel.findById(id);

    if (!veiculo) {
      return res.status(404).json({ error: 'Veículo não encontrado' });
    }

    return res.json(veiculo);
  }

  static async showByPlaca(req: Request, res: Response) {
    const { placa } = req.params;
    const veiculo = await VeiculoModel.findByPlaca(placa);

    if (!veiculo) {
      return res.status(404).json({ error: 'Veículo não encontrado' });
    }

    return res.json(veiculo);
  }

  static async listByCliente(req: Request, res: Response) {
    const { clienteId } = req.params;
    const veiculos = await VeiculoModel.findByClienteId(clienteId);
    return res.json(veiculos);
  }

  static async store(req: Request, res: Response) {
    const data = req.body;

    if (!data.cliente_id || !data.placa || !data.modelo) {
      return res.status(400).json({ error: 'Cliente, Placa e Modelo são obrigatórios' });
    }

    const veiculoExistente = await VeiculoModel.findByPlaca(data.placa);
    if (veiculoExistente) {
      return res.status(400).json({ error: 'Placa já cadastrada' });
    }

    const veiculo = await VeiculoModel.create(data);
    return res.status(201).json(veiculo);
  }
}
