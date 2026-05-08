import { Request, Response } from 'express';
import { NotificationModel } from '../models/notificationModel';
import { sendPushToUsers } from '../services/pushService';

export class NotificationController {
  static async index(req: Request, res: Response) {
    const { usuario_id } = req.query;

    if (!usuario_id || typeof usuario_id !== 'string') {
      return res.status(400).json({ error: 'usuario_id é obrigatório' });
    }

    const notifications = await NotificationModel.findAll(usuario_id);
    return res.json(notifications);
  }

  static async listUnread(req: Request, res: Response) {
    const { usuario_id } = req.query;

    if (!usuario_id || typeof usuario_id !== 'string') {
      return res.status(400).json({ error: 'usuario_id é obrigatório' });
    }

    const notifications = await NotificationModel.findUnread(usuario_id);
    return res.json(notifications);
  }

  static async markAsRead(req: Request, res: Response) {
    const { id } = req.params;
    const { usuario_id } = req.body;

    if (!usuario_id) {
      return res.status(400).json({ error: 'usuario_id é obrigatório' });
    }

    const notification = await NotificationModel.markAsRead(id, usuario_id);

    if (!notification) {
      return res.status(404).json({ error: 'Notificação não encontrada' });
    }

    return res.json(notification);
  }

  static async markAllAsRead(req: Request, res: Response) {
    const { usuario_id } = req.body;

    if (!usuario_id) {
      return res.status(400).json({ error: 'usuario_id é obrigatório' });
    }

    await NotificationModel.markAllAsRead(usuario_id);
    return res.status(204).send();
  }

  static async deleteAll(req: Request, res: Response) {
    const { usuario_id } = req.query;

    if (!usuario_id || typeof usuario_id !== 'string') {
      return res.status(400).json({ error: 'usuario_id é obrigatório' });
    }

    await NotificationModel.deleteAll(usuario_id);
    return res.status(204).send();
  }

  static async devSeedLowStock(req: Request, res: Response) {
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ error: 'Endpoint disponível apenas fora de produção' });
    }

    const { produto_nome, quantidade_estoque } = req.body ?? {};
    const productName = typeof produto_nome === 'string' && produto_nome.trim().length > 0
      ? produto_nome.trim()
      : 'Bateria 60Ah MF';
    const stockQty = Number.isFinite(Number(quantidade_estoque))
      ? Number(quantidade_estoque)
      : 2;

    const internalUserIds = await NotificationModel.findInternalUserIds();
    if (internalUserIds.length === 0) {
      return res.status(404).json({ error: 'Nenhum usuário interno encontrado para seed' });
    }

    const titulo = 'Peça com estoque baixo';
    const mensagem = `${productName} está com ${stockQty} unid. em estoque.`;

    const notifIds = await NotificationModel.createForUsers(internalUserIds, {
      tipo: 'low_stock',
      titulo,
      mensagem,
      referencia_tipo: 'produto',
    });

    await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem, {
      tipo: 'low_stock',
      seed: 'true',
    });

    return res.status(201).json({
      message: 'Seed de low_stock enviada para usuários internos',
      created_for_users: internalUserIds.length,
      notification_ids: notifIds,
    });
  }

  static async devSeedClientAlert(req: Request, res: Response) {
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ error: 'Endpoint disponível apenas fora de produção' });
    }

    const clientUserIds = await NotificationModel.findClientUserIds();
    if (clientUserIds.length === 0) {
      return res.status(404).json({ error: 'Nenhum cliente encontrado para seed' });
    }

    const titulo = 'Orçamento pronto para revisão';
    const mensagem = 'Seu orçamento está pronto para aprovação no app.';

    const notifIds = await NotificationModel.createForUsers(clientUserIds, {
      tipo: 'budget',
      titulo,
      mensagem,
      referencia_tipo: 'orcamento',
    });

    await sendPushToUsers(clientUserIds, notifIds, titulo, mensagem, {
      tipo: 'budget',
      seed: 'true',
      audience: 'client',
    });

    return res.status(201).json({
      message: 'Seed de alerta do cliente enviada',
      created_for_users: clientUserIds.length,
      notification_ids: notifIds,
    });
  }
}
