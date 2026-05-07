import { getDb } from '../config/database';
import type { OrcamentoDTO, CreateOrcamentoDTO, OrcamentoDetalhadoDTO } from '../../../shared/dtos/orcamentoDto';
import type { ItemOrcamentoServicoDTO, ItemOrcamentoProdutoDTO } from '../../../shared/dtos/itemOrcamentoSimplesDto';

export class OrcamentoModel {
  static async findAll(): Promise<OrcamentoDetalhadoDTO[]> {
    const db = getDb();
    const query = `
      SELECT 
        o.*,
        c.nome AS cliente_nome,
        (SELECT nome FROM oficinas ORDER BY criado_em ASC LIMIT 1) AS oficina_nome,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa,
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
      ORDER BY o.criado_em DESC
    `;
    const result = await db.query(query);
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

  static async create(data: CreateOrcamentoDTO): Promise<OrcamentoDTO> {
    const db = getDb();
    const { agendamento_id, cliente_id, funcionario_id } = data;

    const isInitialFromSchedule = Boolean(agendamento_id);
    const statusInicial = isInitialFromSchedule ? 'APROVADO' : 'RASCUNHO';
    const validoAte = isInitialFromSchedule
      ? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      : null;

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

    if (fields.length === 0) return this.findById(id);

    values.push(id);
    const query = `UPDATE orcamentos SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`;
    const result = await db.query(query, values);
    return result.rows[0] ?? null;
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
    const result = await db.query(
      `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [orcamento_id, servico_id, quantidade, preco_unitario]
    );
    return result.rows[0];
  }

  static async removeServico(item_id: string): Promise<boolean> {
    const db = getDb();
    const result = await db.query(
      'DELETE FROM itens_orcamento_servico WHERE id = $1',
      [item_id]
    );
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
    const result = await db.query(
      `INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [orcamento_id, produto_id, quantidade, preco_unitario]
    );
    return result.rows[0];
  }

  static async removeProduto(item_id: string): Promise<boolean> {
    const db = getDb();
    const result = await db.query(
      'DELETE FROM itens_orcamento_produto WHERE id = $1',
      [item_id]
    );
    return (result.rowCount ?? 0) > 0;
  }

  // ── Aprovação ─────────────────────────────────────────────────────────────

  /**
   * Transição de status válida para aprovação: RASCUNHO → ENVIADO → APROVADO.
   * Retorna null se o orçamento não existir ou já estiver em status final.
   */
  static async aprovar(id: string, valido_ate: Date): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'APROVADO', valido_ate = $1
       WHERE id = $2
         AND status IN ('RASCUNHO', 'ENVIADO')
       RETURNING *`,
      [valido_ate, id]
    );
    return result.rows[0] ?? null;
  }

  static async rejeitar(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'REJEITADO'
       WHERE id = $1
         AND status IN ('RASCUNHO', 'ENVIADO')
       RETURNING *`,
      [id]
    );
    return result.rows[0] ?? null;
  }

  static async enviarAddons(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'ENVIADO', valido_ate = NOW() + INTERVAL '7 days'
       WHERE id = $1
         AND status = 'APROVADO'
       RETURNING *`,
      [id]
    );
    return result.rows[0] ?? null;
  }

  static async rejeitarAddons(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE orcamentos
       SET status = 'APROVADO'
       WHERE id = $1
         AND status = 'ENVIADO'
       RETURNING *`,
      [id]
    );
    return result.rows[0] ?? null;
  }
}
