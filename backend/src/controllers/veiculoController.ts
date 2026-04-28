import { Request, Response } from 'express';
import { VeiculoModel } from '../models/veiculoModel';
import { UsuarioModel } from '../models/usuarioModel';

export class VeiculoController {
  static async index(req: Request, res: Response) {
    const { placa, nome_cliente } = req.query;

    if (placa || nome_cliente) {
      const veiculos = await VeiculoModel.findWithFilters({
        placa: placa as string | undefined,
        nome_cliente: nome_cliente as string | undefined,
      });
      return res.json(veiculos);
    }

    const veiculos = await VeiculoModel.findAll();
    return res.json(veiculos);
  }

  static async show(req: Request, res: Response) {
    const veiculo = await VeiculoModel.findById(req.params.id);
    if (!veiculo) return res.status(404).json({ error: 'Veículo não encontrado' });
    return res.json(veiculo);
  }

  static async listByCliente(req: Request, res: Response) {
    const veiculos = await VeiculoModel.findByClienteId(req.params.clienteId);
    return res.json(veiculos);
  }

  static async store(req: Request, res: Response) {
    const { cliente_id, placa, marca, modelo, ano, quilometragem_atual } = req.body;

    if (!cliente_id || !placa) {
      return res.status(400).json({ error: 'cliente_id e placa são obrigatórios' });
    }

    // Garante FK válida antes de inserir — evita erro 500 por violação de constraint
    const clienteExiste = await UsuarioModel.findById(cliente_id);
    if (!clienteExiste) {
      return res.status(404).json({ error: 'Cliente não encontrado' });
    }

    const placaExistente = await VeiculoModel.findByPlaca(placa);
    if (placaExistente) {
      return res.status(409).json({ error: 'Placa já cadastrada' });
    }

    const veiculo = await VeiculoModel.create({ cliente_id, placa, marca, modelo, ano, quilometragem_atual });
    return res.status(201).json(veiculo);
  }
}

