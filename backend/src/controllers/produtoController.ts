import { Request, Response } from 'express';
import { ProdutoModel } from '../models/produtoModel';

export class ProdutoController {
  static async index(req: Request, res: Response) {
    const produtos = await ProdutoModel.findAll();
    return res.json(produtos);
  }

  static async search(req: Request, res: Response) {
    const { nome } = req.params;
    const produtos = await ProdutoModel.findByNome(nome);
    return res.json(produtos);
  }

  static async store(req: Request, res: Response) {
    const data = req.body;
    
    // Simples validação básica (Pode ser expandida com Zod depois)
    if (!data.nome || !data.valor) {
      return res.status(400).json({ error: 'Nome e valor são obrigatórios' });
    }

    const produto = await ProdutoModel.create(data);
    return res.status(201).json(produto);
  }
}
