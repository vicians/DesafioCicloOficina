import { getDb } from '../config/database';
import type { OrcamentoDTO, CreateOrcamentoDTO, OrcamentoDetalhadoDTO } from '../../../shared/dtos/orcamentoDto';
import type { ItemOrcamentoServicoDTO, ItemOrcamentoProdutoDTO } from '../../../shared/dtos/itemOrcamentoSimplesDto';

export class OrcamentoModel {
  static async findAll(cliente_id?: string): Promise<OrcamentoDetalhadoDTO[]> {
    const db = getDb();
    const values: any[] = [];
    let whereClause = '';

    if (cliente_id) {
      whereClause = 'WHERE o.cliente_id = $1';
      values.push(cliente_id);
    }

    const query = `
      SELECT 
        o.*,
        c.nome AS cliente_nome,
        (SELECT nome FROM oficinas ORDER BY criado_em ASC LIMIT 1) AS oficina_nome,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa,
        a.notas_cliente,
        (o.status = 'RASCUNHO' AND NOT EXISTS (
          SELECT 1 FROM itens_orcamento_servico ios WHERE ios.orcamento_id = o.id
        )) AS is_avaliacao,
        COALESCE(
          (SELECT json_agg(json_build_object('id', ios.id, 'item_id', ios.servico_id, 'nome', cs.nome, 'quantidade', ios.quantidade, 'preco_unitario', ios.preco_unitario, 'preco_total', ios.quantidade * ios.preco_unitario))
           FROM itens_orcamento_servico ios JOIN catalogo_servicos cs ON ios.servico_id = cs.id WHERE ios.orcamento_id = o.id),
          '[]'::json
        ) AS itens_servico,
        COALESCE(
          (SELECT json_agg(json_build_object('id', iop.id, 'item_id', iop.produto_id, 'nome', p.nome, 'quantidade', iop.quantidade, 'preco_unitario', iop.preco_unitario, 'preco_total', iop.quantidade * iop.preco_unitario))
           FROM itens_orcamento_produto iop JOIN produtos p ON iop.produto_id = p.id WHERE iop.orcamento_id = o.id),
          '[]'::json
        ) AS itens_produto,
        (SELECT cs.nome FROM itens_orcamento_servico ios JOIN catalogo_servicos cs ON ios.servico_id = cs.id WHERE ios.orcamento_id = o.id LIMIT 1) AS servico_resumo
      FROM orcamentos o
      JOIN usuarios c ON o.cliente_id = c.id
      LEFT JOIN agendamentos a ON o.agendamento_id = a.id
      LEFT JOIN veiculos v ON a.veiculo_id = v.id
      ${whereClause}
      ORDER BY o.criado_em DESC
    `;
    const result = await db.query(query, values);
    return result.rows;
  }

  static async findById(id: string): Promise<OrcamentoDetalhadoDTO | null> {
    const db = getDb();
    const query = `
      SELECT 
        o.*,
        c.nome AS cliente_nome,
        (SELECT nome FROM oficinas ORDER BY criado_em ASC LIMIT 1) AS oficina_nome,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa,
        a.notas_cliente,
        (o.status = 'RASCUNHO' AND NOT EXISTS (
          SELECT 1 FROM itens_orcamento_servico ios WHERE ios.orcamento_id = o.id
        )) AS is_avaliacao,
        COALESCE(
          (SELECT json_agg(json_build_object('id', ios.id, 'item_id', ios.servico_id, 'nome', cs.nome, 'quantidade', ios.quantidade, 'preco_unitario', ios.preco_unitario))
           FROM itens_orcamento_servico ios JOIN catalogo_servicos cs ON ios.servico_id = cs.id WHERE ios.orcamento_id = o.id),
          '[]'::json
        ) AS servicos,
        COALESCE(
          (SELECT json_agg(json_build_object('id', iop.id, 'item_id', iop.produto_id, 'nome', p.nome, 'quantidade', iop.quantidade, 'preco_unitario', iop.preco_unitario))
           FROM itens_orcamento_produto iop JOIN produtos p ON iop.produto_id = p.id WHERE iop.orcamento_id = o.id),
          '[]'::json
        ) AS produtos
      FROM orcamentos o
      JOIN usuarios c ON o.cliente_id = c.id
      LEFT JOIN agendamentos a ON o.agendamento_id = a.id
      LEFT JOIN veiculos v ON a.veiculo_id = v.id
      WHERE o.id = $1
    `;
    const result = await db.query(query, [id]);
    return result.rows[0] ?? null;
  }

  static async findByAgendamentoId(agendamentoId: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM orcamentos WHERE agendamento_id = $1 ORDER BY criado_em DESC LIMIT 1',
      [agendamentoId]
    );
    return result.rows[0] ?? null;
  }

  static async create(data: CreateOrcamentoDTO & { status?: string }): Promise<OrcamentoDTO> {
    const db = getDb();
    const { agendamento_id, cliente_id, funcionario_id, status } = data;

    const statusInicial = status ?? 'RASCUNHO';
    const validoAte = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const result = await db.query(
      `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
       VALUES ($1, $2, $3, $4, 0, $5) RETURNING *`,
      [agendamento_id ?? null, cliente_id, funcionario_id ?? null, statusInicial, validoAte]
    );
    return result.rows[0];
  }

  static async update(id: string, data: Partial<OrcamentoDTO>): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (data.observacoes !== undefined) {
      fields.push(`observacoes = $${idx++}`);
      values.push(data.observacoes);
    }

    if (data.status !== undefined) {
      fields.push(`status = $${idx++}`);
      values.push(data.status);
    }

    if (data.valido_ate !== undefined) {
      fields.push(`valido_ate = $${idx++}`);
      values.push(data.valido_ate);
    }

    // Se houver qualquer alteração e o status for APROVADO, move para RASCUNHO
    // Isso garante que o gerente precise enviar as mudanças para aprovação.
    if (data.status === undefined) {
      fields.push(`status = CASE WHEN status = 'APROVADO' THEN 'RASCUNHO' ELSE status END`);
    }

    if (fields.length === 0) return this.findById(id);

    values.push(id);
    const query = `UPDATE orcamentos SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`;
    const result = await db.query(query, values);
    return result.rows[0] ?? null;
  }

  static async updateStatus(id: string, status: string): Promise<void> {
    const db = getDb();
    await db.query('UPDATE orcamentos SET status = $1 WHERE id = $2', [status, id]);
  }

  // Recalcula valor_total somando todos os itens de serviço e produto em SQL
  static async recalcularTotal(orcamento_id: string): Promise<void> {
    const db = getDb();
    await db.query(
      `UPDATE orcamentos
       SET valor_total = (
         SELECT COALESCE(SUM(quantidade * preco_unitario), 0)
         FROM itens_orcamento_servico
         WHERE orcamento_id = $1
       ) + (
         SELECT COALESCE(SUM(quantidade * preco_unitario), 0)
         FROM itens_orcamento_produto
         WHERE orcamento_id = $1
       )
       WHERE id = $1`,
      [orcamento_id]
    );
  }

  // ── Itens de Serviço ─────────────────────────────────────────────────────

  static async addServico(
    orcamento_id: string,
    servico_id: string,
    quantidade: number,
    preco_unitario: number
  ): Promise<ItemOrcamentoServicoDTO> {
    const db = getDb();
    
    // Se o orçamento não for RASCUNHO, o item entra em revisão (add-on)
    const orcamento = await db.query('SELECT status FROM orcamentos WHERE id = $1', [orcamento_id]);
    const emRevisao = orcamento.rows[0]?.status !== 'RASCUNHO';

    const result = await db.query(
      `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario, em_revisao)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [orcamento_id, servico_id, quantidade, preco_unitario, emRevisao]
    );

    await this.recalcularTotal(orcamento_id);

    // Se o orçamento estava em APROVADO, ele deve voltar para RASCUNHO (pendente de nova aprovação)
    await db.query(
      `UPDATE orcamentos 
       SET status = 'RASCUNHO'
       WHERE id = $1 AND status = 'APROVADO'`,
      [orcamento_id]
    );

    return result.rows[0];
  }

  static async removeServico(item_id: string): Promise<boolean> {
    const db = getDb();
    const item = await db.query('SELECT orcamento_id FROM itens_orcamento_servico WHERE id = $1', [item_id]);
    const orcamento_id = item.rows[0]?.orcamento_id;

    const result = await db.query(
      'DELETE FROM itens_orcamento_servico WHERE id = $1',
      [item_id]
    );

    if (orcamento_id) {
      await this.recalcularTotal(orcamento_id);
      await db.query(
        `UPDATE orcamentos SET status = 'RASCUNHO' WHERE id = $1 AND status = 'APROVADO'`,
        [orcamento_id]
      );
    }

    return (result.rowCount ?? 0) > 0;
  }

  // ── Itens de Produto ─────────────────────────────────────────────────────

  static async addProduto(
    orcamento_id: string,
    produto_id: string,
    quantidade: number,
    preco_unitario: number
  ): Promise<ItemOrcamentoProdutoDTO> {
    const db = getDb();

    // Se o orçamento não for RASCUNHO, o item entra em revisão (add-on)
    const orcamento = await db.query('SELECT status FROM orcamentos WHERE id = $1', [orcamento_id]);
    const emRevisao = orcamento.rows[0]?.status !== 'RASCUNHO';

    const result = await db.query(
      `INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario, em_revisao)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [orcamento_id, produto_id, quantidade, preco_unitario, emRevisao]
    );

    await this.recalcularTotal(orcamento_id);

    // Se o orçamento estava em APROVADO, ele deve voltar para RASCUNHO (pendente de nova aprovação)
    await db.query(
      `UPDATE orcamentos 
       SET status = 'RASCUNHO'
       WHERE id = $1 AND status = 'APROVADO'`,
      [orcamento_id]
    );

    return result.rows[0];
  }

  static async removeProduto(item_id: string): Promise<boolean> {
    const db = getDb();
    const item = await db.query('SELECT orcamento_id FROM itens_orcamento_produto WHERE id = $1', [item_id]);
    const orcamento_id = item.rows[0]?.orcamento_id;

    const result = await db.query(
      'DELETE FROM itens_orcamento_produto WHERE id = $1',
      [item_id]
    );

    if (orcamento_id) {
      await this.recalcularTotal(orcamento_id);
      await db.query(
        `UPDATE orcamentos SET status = 'RASCUNHO' WHERE id = $1 AND status = 'APROVADO'`,
        [orcamento_id]
      );
    }

    return (result.rowCount ?? 0) > 0;
  }

  // ── Aprovação ─────────────────────────────────────────────────────────────

  /**
   * Transição de status válida para aprovação: RASCUNHO → ENVIADO → APROVADO.
   * Retorna null se o orçamento não existir ou já estiver em status final.
   */
  static async aprovar(id: string, valido_ate: Date): Promise<OrcamentoDTO | null> {
    const db = getDb();
    
    // Ao aprovar (seja add-ons ou rascunho), os itens deixam de estar em revisão
    await db.query('UPDATE itens_orcamento_servico SET em_revisao = false WHERE orcamento_id = $1', [id]);
    await db.query('UPDATE itens_orcamento_produto SET em_revisao = false WHERE orcamento_id = $1', [id]);

    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'APROVADO', valido_ate = $1
       WHERE id = $2
         AND status IN ('RASCUNHO', 'ENVIADO')
       RETURNING *`,
      [valido_ate, id]
    );

    if (result.rows && result.rows.length > 0) {
      return result.rows[0];
    }

    // Idempotência: Se já está aprovado, retornamos sucesso
    const orcamento = await this.findById(id);
    if (orcamento && orcamento.status.toUpperCase() === 'APROVADO') {
      return orcamento as any;
    }

    return null;
  }

  static async rejeitar(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    
    // Tenta atualizar orçamentos que ainda não estão finalizados
    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'REJEITADO'
       WHERE id = $1
         AND status IN ('RASCUNHO', 'ENVIADO', 'APROVADO')
       RETURNING *`,
      [id]
    );

    if (result.rows && result.rows.length > 0) {
      return result.rows[0];
    }

    // Idempotência: Se já está rejeitado ou cancelado, retornamos o objeto atual como sucesso
    const orcamento = await this.findById(id);
    if (orcamento && ['REJEITADO', 'CANCELADO'].includes(orcamento.status.toUpperCase())) {
      return orcamento as any; // Cast para DTO simples
    }

    return null;
  }

  static async enviarAddons(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'ENVIADO', valido_ate = NOW() + INTERVAL '7 days'
       WHERE id = $1
         AND status IN ('APROVADO', 'RASCUNHO')
       RETURNING *`,
      [id]
    );
    return result.rows[0] ?? null;
  }

  static async rejeitarAddons(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const client = await db.connect();

    try {
      await client.query('BEGIN');

      // 1. Busca o estado atual para decidir para onde voltar
      const orcRes = await client.query('SELECT status FROM orcamentos WHERE id = $1', [id]);
      if (!orcRes.rows || orcRes.rows.length === 0) {
        await client.query('ROLLBACK');
        return null;
      }
      
      const currentStatus = orcRes.rows[0].status.toUpperCase();
      const statusFinais = ['REJEITADO', 'PAGO', 'CANCELADO'];
      
      if (currentStatus === 'APROVADO') {
        // Já foi revertido ou aprovado, retornamos sucesso
        await client.query('COMMIT');
        return this.findById(id);
      }

      if (statusFinais.includes(currentStatus)) {
        await client.query('ROLLBACK');
        return null; // Não pode reverter se já foi finalizado (exceto se for para voltar ao APROVADO)
      }

      // 2. Remove itens que foram adicionados durante a revisão
      await client.query('DELETE FROM itens_orcamento_servico WHERE orcamento_id = $1 AND em_revisao = true', [id]);
      await client.query('DELETE FROM itens_orcamento_produto WHERE orcamento_id = $1 AND em_revisao = true', [id]);

      // 3. Decide o status de retorno:
      // Se sobraram itens (em_revisao = false), volta para APROVADO.
      // Se não sobrou nada (era o orçamento inicial sendo rejeitado), volta para RASCUNHO.
      const hasItemsRes = await client.query(`
        SELECT 
          (SELECT COUNT(*) FROM itens_orcamento_servico WHERE orcamento_id = $1) +
          (SELECT COUNT(*) FROM itens_orcamento_produto WHERE orcamento_id = $1) as total
      `, [id]);
      
      const totalRemanescente = parseInt(hasItemsRes.rows[0].total, 10);
      const novoStatus = totalRemanescente > 0 ? 'APROVADO' : 'RASCUNHO';

      // 4. Atualiza o orçamento
      const result = await client.query(
        `UPDATE orcamentos
         SET status = $1,
             observacoes = COALESCE(observacoes, '') || '\n[CLIENTE] Rejeitou as alterações do orçamento.'
         WHERE id = $2
         RETURNING *`,
        [novoStatus, id]
      );

      await client.query('COMMIT');

      // 5. Recalcula o total para refletir a remoção dos itens
      await this.recalcularTotal(id);

      return this.findById(id);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  static async enviar(id: string): Promise<OrcamentoDetalhadoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE orcamentos 
       SET status = 'ENVIADO', 
           valido_ate = NOW() + INTERVAL '7 days'
       WHERE id = $1 AND status = 'RASCUNHO'
       RETURNING id`,
      [id]
    );

    if (result.rows && result.rows.length > 0) {
      return this.findById(id);
    }
    return null;
  }
}
