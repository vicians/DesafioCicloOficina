import { getDb } from '../config/database';

export interface ExecucaoServicoDTO {
  id: string;
  orcamento_id: string;
  funcionario_id: string | null;
  status: string;
  iniciado_em: string | null;
  finalizado_em: string | null;
  notas_internas: string | null;
}

export class ExecucaoServicoModel {
  static async findById(id: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query('SELECT * FROM execucoes_servico WHERE id = $1', [id]);
    return result.rows[0] ?? null;
  }

  static async findByOrcamentoId(orcamento_id: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM execucoes_servico WHERE orcamento_id = $1',
      [orcamento_id]
    );
    return result.rows[0] ?? null;
  }

  static async updateNotas(id: string, notas_internas: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'UPDATE execucoes_servico SET notas_internas = $1 WHERE id = $2 RETURNING *',
      [notas_internas, id]
    );
    return result.rows[0] ?? null;
  }

  /**
   * Finaliza a execução: seta finalizado_em = NOW() e status = CONCLUIDO.
   * Só deve ser chamado quando o status atual for EM_EXECUCAO ou REVISAO_TECNICA.
   * A validação do status anterior é feita no controller para retornar 409 semântico.
   */
  static async finalizar(id: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE execucoes_servico
       SET status = 'CONCLUIDO', finalizado_em = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );
    return result.rows[0] ?? null;
  }
}
