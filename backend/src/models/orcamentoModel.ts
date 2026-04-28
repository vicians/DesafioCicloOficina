import { getDb } from '../config/database';
import type { OrcamentoDTO, CreateOrcamentoDTO } from '../../../shared/dtos/orcamentoDto';

export class OrcamentoModel {
  static async findAll(): Promise<OrcamentoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM orcamentos');
    return result.rows;
  }

  static async create(data: CreateOrcamentoDTO): Promise<OrcamentoDTO> {
    const db = getDb();
    const { agendamento_id, cliente_id, funcionario_id, valido_ate } = data;
    const result = await db.query(
      `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [agendamento_id, cliente_id, funcionario_id, 'RASCUNHO', 0, valido_ate]
    );
    return result.rows[0];
  }
}
