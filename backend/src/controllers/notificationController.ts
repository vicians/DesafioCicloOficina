import { Request, Response } from 'express';
import { NotificationModel } from '../models/notificationModel';

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
}
