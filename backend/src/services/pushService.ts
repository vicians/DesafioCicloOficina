import { getMessaging } from '../config/firebase';
import { getDb } from '../config/database';

/**
 * Envia notificação FCM para um conjunto de tokens.
 * Retorna silenciosamente se o Firebase não estiver configurado.
 */
export const sendPushToTokens = async (
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> => {
  if (tokens.length === 0) return;

  const messaging = getMessaging();
  if (!messaging) return;

  const message: Parameters<typeof messaging.sendEachForMulticast>[0] = {
    tokens,
    notification: { title, body },
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
    data: data ?? {},
  };

  const response = await messaging.sendEachForMulticast(message);
  if (response.failureCount > 0) {
    response.responses.forEach((r, i) => {
      if (!r.success) {
        console.warn(`[FCM] Falha ao enviar para token[${i}]:`, r.error?.message);
      }
    });
  }
};

/**
 * Busca todos os FCM tokens ativos dos usuários informados e envia o push.
 * Marca as notificações como push_enviado=true após o envio.
 */
export const sendPushToUsers = async (
  userIds: string[],
  notificationIds: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> => {
  if (userIds.length === 0) return;

  const db = getDb();

  const { rows: tokenRows } = await db.query<{ usuario_id: string; fcm_registration_token: string }>(
    `SELECT usuario_id, fcm_registration_token
       FROM user_push_tokens
      WHERE usuario_id = ANY($1::uuid[])`,
    [userIds],
  );

  if (tokenRows.length === 0) return;

  const tokens = tokenRows.map((r) => r.fcm_registration_token);
  await sendPushToTokens(tokens, title, body, data);

  if (notificationIds.length > 0) {
    await db.query(
      `UPDATE notifications
          SET push_enviado = true, push_enviado_em = NOW()
        WHERE id = ANY($1::uuid[])`,
      [notificationIds],
    );
  }
};
