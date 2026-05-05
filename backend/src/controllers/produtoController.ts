import { Request, Response } from 'express';
import { ProdutoModel } from '../models/produtoModel';
import { NotificationModel } from '../models/notificationModel';
import { sendPushToUsers } from '../services/pushService';
import { RagSyncService } from '../services/ragSyncService';

const ESTOQUE_BAIXO_LIMIAR = 5;

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
    const { nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade } = req.body;

    if (!nome || !valor) {
      return res.status(400).json({ error: 'nome e valor são obrigatórios' });
    }

    const produto = await ProdutoModel.create({ nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade });
    RagSyncService.syncProduto(produto); // fire-and-forget: indexa no Vector DB
    return res.status(201).json(produto);
  }

  static async update(req: Request, res: Response) {
    const produto = await ProdutoModel.update(req.params.id, req.body);
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });

    const limiar = produto.min_estoque ?? ESTOQUE_BAIXO_LIMIAR;
    if (produto.quantidade_estoque <= limiar) {
      try {
        const internalUserIds = await NotificationModel.findInternalUserIds();
        const titulo = 'Peça com estoque baixo';
        const mensagem = `${produto.nome} está com ${produto.quantidade_estoque} unid. em estoque.`;
        const notifIds = await NotificationModel.createForUsers(internalUserIds, {
          tipo: 'low_stock',
          titulo,
          mensagem,
          referencia_id: produto.id,
          referencia_tipo: 'produto',
        });
        await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem);
      } catch (error) {
        // Não interrompe atualização de produto por falha de notificação.
        console.error('Falha ao criar notificações internas de estoque baixo:', error);
      }
    }

    RagSyncService.syncProduto(produto); // fire-and-forget: atualiza no Vector DB
    return res.json(produto);
  }

  static async destroy(req: Request, res: Response) {
    const produto = await ProdutoModel.deactivate(req.params.id);
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });
    return res.status(204).send();
  }
}
