import { Router } from 'express';
import { PushTokenController } from '../controllers/pushTokenController';

const pushTokenRouter = Router();

/**
 * @openapi
 * /push-tokens:
 *   post:
 *     tags:
 *       - Push Tokens
 *     summary: Registra/atualiza token de push FCM por usuário
 *     description: Salva o fcm_registration_token para permitir envio de notificações push (RN047, RN048)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_id
 *               - fcm_registration_token
 *             properties:
 *               usuario_id:
 *                 type: string
 *                 format: uuid
 *               fcm_registration_token:
 *                 type: string
 *                 description: Firebase Cloud Messaging registration token do dispositivo
 *     responses:
 *       201:
 *         description: Criado/atualizado com sucesso
 *       400:
 *         description: Campos obrigatórios ausentes
 */
pushTokenRouter.post('/', PushTokenController.upsert);

/**
 * @openapi
 * /push-tokens:
 *   delete:
 *     tags:
 *       - Push Tokens
 *     summary: Remove token de push FCM de um usuário
 *     description: Remove o fcm_registration_token no logout/desativação do dispositivo
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_id
 *               - fcm_registration_token
 *             properties:
 *               usuario_id:
 *                 type: string
 *                 format: uuid
 *               fcm_registration_token:
 *                 type: string
 *     responses:
 *       204:
 *         description: Removido com sucesso
 *       404:
 *         description: Token não encontrado
 */
pushTokenRouter.delete('/', PushTokenController.remove);

export { pushTokenRouter };
