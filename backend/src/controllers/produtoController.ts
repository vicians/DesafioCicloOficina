import { Request, Response } from 'express';
import { ProdutoModel } from '../models/produtoModel';
import { RagSyncService } from '../services/ragSyncService';

export class ProdutoController {
  static async index(req: Request, res: Response) {
    const produtos = await ProdutoModel.findAll();
    return res.json(produtos);
  }

  static async show(req: Request, res: Response) {
    const produto = await ProdutoModel.findById(req.params.id);
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });
    return res.json(produto);
  }

  static async search(req: Request, res: Response) {
    const { nome } = req.params;
    const produtos = await ProdutoModel.findByNome(nome);
    return res.json(produtos);
  }

  static async store(req: Request, res: Response) {
    const { nome, marca, valor, quantidade_estoque } = req.body;

    if (!nome || !valor) {
      return res.status(400).json({ error: 'nome e valor são obrigatórios' });
    }

    const produto = await ProdutoModel.create({ nome, marca, valor, quantidade_estoque });
    RagSyncService.syncProduto(produto); // fire-and-forget: indexa no Vector DB
    return res.status(201).json(produto);
  }

  static async update(req: Request, res: Response) {
    const produto = await ProdutoModel.update(req.params.id, req.body);
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });
    RagSyncService.syncProduto(produto); // fire-and-forget: atualiza no Vector DB
    return res.json(produto);
  }

  static async destroy(req: Request, res: Response) {
    const produto = await ProdutoModel.deactivate(req.params.id);
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });
    return res.status(204).send();
  }
}
