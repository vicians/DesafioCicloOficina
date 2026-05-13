import { getDb } from '../config/database';
import type { NotificationDTO, CreateNotificationDTO } from '../../../shared/dtos/notificationDto';

export class NotificationModel {
  static async findInternalUserIds(): Promise<string[]> {
    const db = getDb();
    const result = await db.query(
      `SELECT id FROM usuarios WHERE tipo_id IN (1, 3)`
    );

    return result.rows.map((row: { id: string }) => row.id);
  }

  static async findClientUserIds(): Promise<string[]> {
    const db = getDb();
    const result = await db.query(
      `SELECT id FROM usuarios WHERE tipo_id = 2`
    );

    return result.rows.map((row: { id: string }) => row.id);
  }

  static async createForUsers(
    usuarioIds: string[],
    data: Omit<CreateNotificationDTO, 'usuario_id'>
  ): Promise<string[]> {
    if (usuarioIds.length === 0) return [];

    const notifications = await Promise.all(
      usuarioIds.map((usuario_id) =>
        this.create({
          usuario_id,
          ...data,
        })
      )
    );
    return notifications.map((n) => n.id);
  }

  static async findAll(usuario_id: string): Promise<NotificationDTO[]> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM notifications WHERE usuario_id = $1 ORDER BY criado_em DESC',
      [usuario_id]
    );
    return result.rows;
  }

  static async findUnread(usuario_id: string): Promise<NotificationDTO[]> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM notifications WHERE usuario_id = $1 AND lida = false ORDER BY criado_em DESC',
      [usuario_id]
    );
    return result.rows;
  }

  static async countPushSentToday(usuario_id: string): Promise<number> {
    const db = getDb();
    const result = await db.query(
      `SELECT COUNT(*) FROM notifications
       WHERE usuario_id = $1
         AND push_enviado = true
         AND DATE(push_enviado_em) = CURRENT_DATE`,
      [usuario_id]
    );
    return parseInt(result.rows[0].count, 10);
  }

  static async create(data: CreateNotificationDTO): Promise<NotificationDTO> {
    const db = getDb();
    const { usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo } = data;
    const result = await db.query(
      `INSERT INTO notifications (usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [usuario_id, tipo, titulo, mensagem, referencia_id ?? null, referencia_tipo ?? null]
    );
    return result.rows[0];
  }

  static async markAsRead(id: string, usuario_id: string): Promise<NotificationDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE notifications SET lida = true, lido_em = CURRENT_TIMESTAMP
       WHERE id = $1 AND usuario_id = $2 RETURNING *`,
      [id, usuario_id]
    );
    return result.rows[0] ?? null;
  }

  static async markPushSent(id: string): Promise<NotificationDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE notifications
       SET push_enviado = true,
           push_enviado_em = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    return result.rows[0] ?? null;
  }

  static async markAllAsRead(usuario_id: string): Promise<void> {
    const db = getDb();
    await db.query(
      `UPDATE notifications SET lida = true, lido_em = CURRENT_TIMESTAMP
       WHERE usuario_id = $1 AND lida = false`,
      [usuario_id]
    );
  }

  static async deleteAll(usuario_id: string): Promise<void> {
    const db = getDb();
    await db.query(
      `DELETE FROM notifications WHERE usuario_id = $1`,
      [usuario_id]
    );
  }
}
