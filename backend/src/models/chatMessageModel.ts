import { getDb } from '../config/database';

export class ChatMessageModel {
  static async findByClienteId(clienteId: string): Promise<any[]> {
    const db = getDb();
    const result = await db.query(
      `SELECT id, cliente_id, tipo_remetente, conteudo, criado_em
       FROM mensagens_chat
       WHERE cliente_id = $1
       ORDER BY criado_em ASC`,
      [clienteId]
    );
    return result.rows;
  }

  static async createByClienteId(
    clienteId: string,
    tipoRemetente: string,
    conteudo: string
  ): Promise<any> {
    const db = getDb();
    const result = await db.query(
      `INSERT INTO mensagens_chat (cliente_id, tipo_remetente, conteudo)
       VALUES ($1, $2, $3)
       RETURNING id, cliente_id, tipo_remetente, conteudo, criado_em`,
      [clienteId, tipoRemetente, conteudo]
    );
    return result.rows[0];
  }
}
