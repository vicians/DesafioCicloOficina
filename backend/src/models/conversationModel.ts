import { getDb } from '../config/database';

export class ConversationModel {
  static async findOrCreateByClienteId(clienteId: string): Promise<any> {
    const db = getDb();
    
    // Attempt to find
    const res = await db.query(
      `SELECT * FROM conversacoes_chat WHERE cliente_id = $1`,
      [clienteId]
    );

    if (res.rows.length > 0) {
      return res.rows[0];
    }

    // Create if not exists
    const createRes = await db.query(
      `INSERT INTO conversacoes_chat (cliente_id, ia_pausada)
       VALUES ($1, false)
       RETURNING *`,
      [clienteId]
    );
    
    return createRes.rows[0];
  }

  static async findAll(): Promise<any[]> {
    const db = getDb();
    
    // Join with usuarios; use subquery for plate to avoid duplicate rows per vehicle
    const res = await db.query(`
      SELECT 
        c.id, 
        c.cliente_id, 
        c.ia_pausada, 
        c.atualizado_em as updated_at,
        u.nome as "clientName",
        (SELECT v.placa FROM veiculos v WHERE v.cliente_id = u.id ORDER BY v.criado_em DESC LIMIT 1) as plate,
        (
          SELECT conteudo 
          FROM mensagens_chat m2 
          WHERE m2.conversacao_id = c.id
             OR (m2.conversacao_id IS NULL AND m2.cliente_id = c.cliente_id)
          ORDER BY m2.criado_em DESC 
          LIMIT 1
        ) as "lastMessage",
        (
          SELECT COUNT(*)
          FROM mensagens_chat m3
          WHERE (m3.conversacao_id = c.id OR (m3.conversacao_id IS NULL AND m3.cliente_id = c.cliente_id))
            AND m3.lida = false AND m3.tipo_remetente = 'client'
        )::int as "unreadCount"
      FROM conversacoes_chat c
      JOIN usuarios u ON c.cliente_id = u.id
      ORDER BY c.atualizado_em DESC
    `);
    
    return res.rows;
  }

  static async getMessages(conversacaoId: string): Promise<any[]> {
    const db = getDb();
    // Include messages linked by conversacao_id AND orphan messages stored by cliente_id only
    const res = await db.query(
      `SELECT id, conversacao_id, cliente_id, tipo_remetente, conteudo, criado_em, lida
       FROM mensagens_chat
       WHERE conversacao_id = $1
          OR (conversacao_id IS NULL AND cliente_id = (
                SELECT cliente_id FROM conversacoes_chat WHERE id = $1
             ))
       ORDER BY criado_em ASC`,
      [conversacaoId]
    );
    return res.rows;
  }

  static async addMessage(
    conversacaoId: string,
    clienteId: string,
    tipoRemetente: string,
    conteudo: string
  ): Promise<any> {
    const db = getDb();
    const res = await db.query(
      `INSERT INTO mensagens_chat (conversacao_id, cliente_id, tipo_remetente, conteudo)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [conversacaoId, clienteId, tipoRemetente, conteudo]
    );

    // Update conversation's atualizado_em
    await db.query(
      `UPDATE conversacoes_chat SET atualizado_em = CURRENT_TIMESTAMP WHERE id = $1`,
      [conversacaoId]
    );

    return res.rows[0];
  }

  static async updateHandoff(id: string, iaPausada: boolean): Promise<any> {
    const db = getDb();
    const res = await db.query(
      `UPDATE conversacoes_chat
       SET ia_pausada = $1, atualizado_em = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [iaPausada, id]
    );
    return res.rows[0];
  }

  static async markAsRead(id: string): Promise<void> {
    const db = getDb();
    await db.query(
      `UPDATE mensagens_chat
       SET lida = true
       WHERE conversacao_id = $1 AND tipo_remetente = 'client' AND lida = false`,
      [id]
    );
  }
}
