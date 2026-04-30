import { getDb } from '../config/database';
import type { PushTokenDTO, UpsertPushTokenDTO } from '../../../shared/dtos/pushTokenDto';

export class PushTokenModel {
  static async upsert(data: UpsertPushTokenDTO): Promise<PushTokenDTO> {
    const db = getDb();
    const { usuario_id, fcm_registration_token } = data;

    const result = await db.query(
      `INSERT INTO user_push_tokens (usuario_id, fcm_registration_token)
       VALUES ($1, $2)
       ON CONFLICT (fcm_registration_token)
       DO UPDATE SET
         usuario_id = EXCLUDED.usuario_id,
         atualizado_em = CURRENT_TIMESTAMP
       RETURNING *`,
      [usuario_id, fcm_registration_token]
    );

    return result.rows[0];
  }

  static async removeByToken(
    usuario_id: string,
    fcm_registration_token: string
  ): Promise<PushTokenDTO | null> {
    const db = getDb();

    const result = await db.query(
      `DELETE FROM user_push_tokens
       WHERE usuario_id = $1 AND fcm_registration_token = $2
       RETURNING *`,
      [usuario_id, fcm_registration_token]
    );

    return result.rows[0] ?? null;
  }
}
