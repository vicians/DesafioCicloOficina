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

/** Máximo de pushes FCM enviados por usuário por dia (RN049). */
const PUSH_DAILY_LIMIT = 5;

/**
 * Busca FCM tokens apenas dos usuários que ainda não atingiram o limite diário
 * de push (RN049: 1 push/usuário/dia). A notificação interna já foi gravada no
 * DB antes desta chamada — o limite afeta apenas o disparo FCM, não o alerta.
 * Marca as notificações dos usuários que receberam o push como push_enviado=true.
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

  // Busca tokens junto com a contagem de pushes enviados hoje para cada usuário,
  // filtrando direto no SQL para evitar N queries.
  const { rows: tokenRows } = await db.query<{ usuario_id: string; fcm_registration_token: string }>(
    `SELECT upt.usuario_id, upt.fcm_registration_token
       FROM user_push_tokens upt
      WHERE upt.usuario_id = ANY($1::uuid[])
        AND (
          SELECT COUNT(*)
            FROM notifications n
           WHERE n.usuario_id = upt.usuario_id
             AND n.push_enviado = true
             AND DATE(n.push_enviado_em) = CURRENT_DATE
        ) < $2`,
    [userIds, PUSH_DAILY_LIMIT],
  );

  if (tokenRows.length === 0) return;

  const elegibleUserIds = tokenRows.map((r) => r.usuario_id);
  const tokens = tokenRows.map((r) => r.fcm_registration_token);

  await sendPushToTokens(tokens, title, body, data);

  // Marca apenas as notificações dos usuários que efetivamente receberam o push.
  if (notificationIds.length > 0 && elegibleUserIds.length > 0) {
    await db.query(
      `UPDATE notifications
          SET push_enviado = true, push_enviado_em = NOW()
        WHERE id = ANY($1::uuid[])
          AND usuario_id = ANY($2::uuid[])`,
      [notificationIds, elegibleUserIds],
    );
  }
};
