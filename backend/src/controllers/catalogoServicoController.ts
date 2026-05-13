import { Request, Response } from 'express';
import { CatalogoServicoModel } from '../models/catalogoServicoModel';

export class CatalogoServicoController {
  static async index(req: Request, res: Response) {
    const servicos = await CatalogoServicoModel.findAll();
    return res.json(servicos);
  }

  static async show(req: Request, res: Response) {
    const servico = await CatalogoServicoModel.findById(req.params.id);
    if (!servico) return res.status(404).json({ error: 'Serviço não encontrado' });
    return res.json(servico);
  }

  static async store(req: Request, res: Response) {
    const { nome, preco, duracao_minutos, descricao } = req.body;

    if (!nome || !preco || !duracao_minutos) {
      return res.status(400).json({ error: 'nome, preco e duracao_minutos são obrigatórios' });
    }

    const servico = await CatalogoServicoModel.create({ nome, preco, duracao_minutos, descricao });
    return res.status(201).json(servico);
  }

  static async update(req: Request, res: Response) {
    const servico = await CatalogoServicoModel.update(req.params.id, req.body);
    if (!servico) return res.status(404).json({ error: 'Serviço não encontrado' });
    return res.json(servico);
  }

  static async destroy(req: Request, res: Response) {
    const servico = await CatalogoServicoModel.deactivate(req.params.id);
    if (!servico) return res.status(404).json({ error: 'Serviço não encontrado' });
    return res.status(204).send();
  }
}

