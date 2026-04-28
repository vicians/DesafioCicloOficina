import { getDb } from '../config/database';
import type { AgendamentoDTO, CreateAgendamentoDTO } from '../../../shared/dtos/agendamentoDto';

export class AgendamentoModel {
  static async findAll(): Promise<AgendamentoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM agendamentos');
    return result.rows;
  }

  static async findByClienteId(clienteId: string): Promise<AgendamentoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM agendamentos WHERE cliente_id = $1', [clienteId]);
    return result.rows;
  }

  static async create(data: CreateAgendamentoDTO): Promise<AgendamentoDTO> {
    const db = getDb();
    const { cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, notas_cliente } = data;

    // Cálculo do fim estimado (RN023)
    const agendadoParaDate = new Date(agendado_para);
    const fimEstimado = new Date(agendadoParaDate.getTime() + duracao_total_minutos * 60000);

    const result = await db.query(
      `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fimEstimado, 'PENDENTE', notas_cliente]
    );
    return result.rows[0];
  }
}
