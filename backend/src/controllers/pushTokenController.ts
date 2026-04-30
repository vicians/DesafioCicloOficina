import { Request, Response } from 'express';
import { PushTokenModel } from '../models/pushTokenModel';

export class PushTokenController {
  static async upsert(req: Request, res: Response) {
    const { usuario_id, fcm_registration_token } = req.body;

    if (!usuario_id || !fcm_registration_token) {
      return res.status(400).json({
        error: 'usuario_id e fcm_registration_token são obrigatórios',
      });
    }

    const pushToken = await PushTokenModel.upsert({
      usuario_id,
      fcm_registration_token,
    });

    return res.status(201).json(pushToken);
  }

  static async remove(req: Request, res: Response) {
    const { usuario_id, fcm_registration_token } = req.body;

    if (!usuario_id || !fcm_registration_token) {
      return res.status(400).json({
        error: 'usuario_id e fcm_registration_token são obrigatórios',
      });
    }

    const pushToken = await PushTokenModel.removeByToken(
      usuario_id,
      fcm_registration_token
    );

    if (!pushToken) {
      return res.status(404).json({ error: 'Token não encontrado' });
    }

    return res.status(204).send();
  }
}
