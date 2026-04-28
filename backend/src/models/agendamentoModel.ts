import { getDb } from '../config/database';
import type { AgendamentoDTO, CreateAgendamentoDTO } from '../../../shared/dtos/agendamentoDto';

export class AgendamentoModel {
  static async findAll(): Promise<AgendamentoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM agendamentos ORDER BY agendado_para ASC');
    return result.rows;
  }

  static async findByClienteId(clienteId: string): Promise<AgendamentoDTO[]> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM agendamentos WHERE cliente_id = $1 ORDER BY agendado_para ASC',
      [clienteId]
    );
    return result.rows;
  }

  /**
   * Verifica sobreposição de horário para o mesmo veículo ou funcionário.
   * Um conflito existe quando o novo intervalo [inicio, fim) se sobrepõe a qualquer
   * agendamento ativo (PENDENTE ou CONFIRMADO) no mesmo recurso.
   * Condição de sobreposição: inicio < fim_existente AND fim > inicio_existente
   */
  static async checkConflict(
    veiculo_id: string,
    funcionario_id: string | null,
    inicio: Date,
    fim: Date,
    excludeId?: string
  ): Promise<{ veiculo: boolean; funcionario: boolean }> {
    const db = getDb();

    const baseCondition = `
      status IN ('PENDENTE', 'CONFIRMADO')
      AND $1 < fim_estimado_em
      AND $2 > agendado_para
      AND id != $3
    `;

    const excludeParam = excludeId ?? '00000000-0000-0000-0000-000000000000';

    const veiculoResult = await db.query(
      `SELECT 1 FROM agendamentos WHERE veiculo_id = $4 AND ${baseCondition} LIMIT 1`,
      [inicio, fim, excludeParam, veiculo_id]
    );

    let funcionarioConflict = false;
    if (funcionario_id) {
      const funcionarioResult = await db.query(
        `SELECT 1 FROM agendamentos WHERE funcionario_id = $4 AND ${baseCondition} LIMIT 1`,
        [inicio, fim, excludeParam, funcionario_id]
      );
      funcionarioConflict = (funcionarioResult.rowCount ?? 0) > 0;
    }

    return {
      veiculo: (veiculoResult.rowCount ?? 0) > 0,
      funcionario: funcionarioConflict,
    };
  }

  static async create(data: CreateAgendamentoDTO): Promise<AgendamentoDTO> {
    const db = getDb();
    const { cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, notas_cliente } = data;

    // Cálculo do fim estimado (RN023)
    const agendadoParaDate = new Date(agendado_para);
    const fimEstimado = new Date(agendadoParaDate.getTime() + duracao_total_minutos * 60000);

    const result = await db.query(
      `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
       VALUES ($1, $2, $3, $4, $5, $6, 'PENDENTE', $7) RETURNING *`,
      [cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fimEstimado, notas_cliente]
    );
    return result.rows[0];
  }

  static async updateStatus(id: string, status: string): Promise<AgendamentoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE agendamentos SET status = $1 WHERE id = $2 RETURNING *`,
      [status, id]
    );
    return result.rows[0] ?? null;
  }

  /**
   * Cria a execução de serviço vinculada ao orçamento aprovado do agendamento.
   * A execução só existe após orçamento APROVADO — o funcionario_id aqui é o
   * mecânico que vai executar (pode diferir do responsável pelo agendamento).
   */
  static async iniciarExecucao(
    orcamento_id: string,
    funcionario_id: string
  ): Promise<object> {
    const db = getDb();

    // Garante idempotência: upsert via ON CONFLICT na constraint UNIQUE de orcamento_id
    const result = await db.query(
      `INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em)
       VALUES ($1, $2, 'EM_EXECUCAO', NOW())
       ON CONFLICT (orcamento_id)
       DO UPDATE SET funcionario_id = EXCLUDED.funcionario_id,
                     status = 'EM_EXECUCAO',
                     iniciado_em = NOW()
       RETURNING *`,
      [orcamento_id, funcionario_id]
    );
    return result.rows[0];
  }
}

