import { Request, Response } from 'express';
import { CatalogoServicoModel } from '../models/catalogoServicoModel';

export class CatalogoServicoController {
  static async index(req: Request, res: Response) {
    const servicos = await CatalogoServicoModel.findAll();
    return res.json(servicos);
  }

  static async store(req: Request, res: Response) {
    const data = req.body;

    if (!data.nome || !data.preco || !data.duracao_minutos) {
      return res.status(400).json({ error: 'Nome, Preço e Duração são obrigatórios' });
    }

    const servico = await CatalogoServicoModel.create(data);
    return res.status(201).json(servico);
  }
}
