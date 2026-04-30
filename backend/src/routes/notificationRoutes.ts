import { Router } from 'express';
import { NotificationController } from '../controllers/notificationController';

const notificationRouter = Router();

/**
 * @openapi
 * /notifications:
 *   get:
 *     tags:
 *       - Notifications
 *     summary: Lista todas as notificações de um usuário
 *     description: Retorna histórico completo de notificações do usuário (RN047, RN048)
 *     parameters:
 *       - in: query
 *         name: usuario_id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 *       400:
 *         description: usuario_id ausente
 */
notificationRouter.get('/', NotificationController.index);

/**
 * @openapi
 * /notifications/unread:
 *   get:
 *     tags:
 *       - Notifications
 *     summary: Lista notificações não lidas de um usuário
 *     description: Retorna apenas notificações não lidas, usada para badge (RN047, RN048)
 *     parameters:
 *       - in: query
 *         name: usuario_id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 *       400:
 *         description: usuario_id ausente
 */
notificationRouter.get('/unread', NotificationController.listUnread);

/**
 * @openapi
 * /notifications/{id}/read:
 *   patch:
 *     tags:
 *       - Notifications
 *     summary: Marca uma notificação como lida
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_id
 *             properties:
 *               usuario_id:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: Sucesso
 *       404:
 *         description: Notificação não encontrada
 */
notificationRouter.patch('/:id/read', NotificationController.markAsRead);

/**
 * @openapi
 * /notifications/read-all:
 *   patch:
 *     tags:
 *       - Notifications
 *     summary: Marca todas as notificações de um usuário como lidas
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_id
 *             properties:
 *               usuario_id:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       204:
 *         description: Sem conteúdo
 */
notificationRouter.patch('/read-all', NotificationController.markAllAsRead);

export { notificationRouter };
