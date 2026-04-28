import { getDb } from '../config/database';
import type { OrcamentoDTO, CreateOrcamentoDTO } from '../../../shared/dtos/orcamentoDto';

export class OrcamentoModel {
  static async findAll(): Promise<OrcamentoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM orcamentos ORDER BY criado_em DESC');
    return result.rows;
  }

  static async findById(id: string): Promise<OrcamentoDTO | null> {
    const db = getDb();
    const result = await db.query('SELECT * FROM orcamentos WHERE id = $1', [id]);
    return result.rows[0] ?? null;
  }

  static async create(data: CreateOrcamentoDTO): Promise<OrcamentoDTO> {
    const db = getDb();
    const { agendamento_id, cliente_id, funcionario_id } = data;
    const result = await db.query(
      `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total)
       VALUES ($1, $2, $3, 'RASCUNHO', 0) RETURNING *`,
      [agendamento_id ?? null, cliente_id, funcionario_id ?? null]
    );
    return result.rows[0];
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
  ): Promise<object> {
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
  ): Promise<object> {
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
}

