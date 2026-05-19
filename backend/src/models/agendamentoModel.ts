import { getDb } from '../config/database';
import type { AgendamentoDTO, CreateAgendamentoDTO } from '../../../shared/dtos/agendamentoDto';
import type { ExecucaoServicoDTO } from '../../../shared/dtos/execucaoServicoDto';
import type { OrcamentoDTO } from '../../../shared/dtos/orcamentoDto';

export class AgendamentoModel {
  private static readonly WORKSHOP_TIMEZONE = 'America/Sao_Paulo';

  static async findAll(): Promise<any[]> {
    const db = getDb();
    const query = `
      SELECT 
        a.*,
        c.nome AS cliente_nome,
        EXISTS (SELECT 1 FROM orcamentos o WHERE o.agendamento_id = a.id) AS possui_orcamento,
        EXISTS (
          SELECT 1
          FROM orcamentos o
          JOIN execucoes_servico e ON e.orcamento_id = o.id
          WHERE o.agendamento_id = a.id
        ) AS possui_execucao,
        (SELECT o.status FROM orcamentos o WHERE o.agendamento_id = a.id ORDER BY o.criado_em DESC LIMIT 1) AS orcamento_status,
        (
          SELECT EXISTS (SELECT 1 FROM itens_orcamento_servico ios WHERE ios.orcamento_id = o2.id) OR
                 EXISTS (SELECT 1 FROM itens_orcamento_produto iop WHERE iop.orcamento_id = o2.id)
          FROM orcamentos o2 
          WHERE o2.agendamento_id = a.id 
          ORDER BY o2.criado_em DESC
          LIMIT 1
        ) AS orcamento_tem_itens,
        (SELECT nome FROM oficinas ORDER BY criado_em ASC LIMIT 1) AS oficina_nome,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa
      FROM agendamentos a
      JOIN usuarios c ON a.cliente_id = c.id
      JOIN veiculos v ON a.veiculo_id = v.id
      ORDER BY a.agendado_para ASC
    `;
    const result = await db.query(query);
    return result.rows;
  }

  static async findByClienteId(clienteId: string): Promise<AgendamentoDTO[]> {
    const db = getDb();
    const result = await db.query(
      `SELECT a.*,
              v.marca AS veiculo_marca,
              v.modelo AS veiculo_modelo,
              v.placa AS veiculo_placa
       FROM agendamentos a
       LEFT JOIN veiculos v ON a.veiculo_id = v.id
       WHERE a.cliente_id = $1
       ORDER BY a.agendado_para ASC`,
      [clienteId]
    );
    return result.rows;
  }

  static async findById(id: string): Promise<AgendamentoDTO | null> {
    const db = getDb();
    const result = await db.query('SELECT * FROM agendamentos WHERE id = $1 LIMIT 1', [id]);
    return result.rows[0] ?? null;
  }

  static async clienteVeiculoRelacionados(clienteId: string, veiculoId: string): Promise<boolean> {
    const db = getDb();
    const result = await db.query(
      'SELECT 1 FROM veiculos WHERE id = $1 AND cliente_id = $2 LIMIT 1',
      [veiculoId, clienteId]
    );
    return (result.rowCount ?? 0) > 0;
  }

  /**
   * Verifica sobreposição de horário para o mesmo veículo ou funcionário.
   * Um conflito existe quando o novo intervalo [inicio, fim) se sobrepõe a qualquer
   * agendamento ativo no mesmo recurso.
   * Status terminais (CONCLUIDO, CANCELADO) liberam o recurso — todos os outros bloqueiam.
   */
  static async checkConflict(
    veiculo_id: string,
    funcionario_id: string | null,
    inicio: Date,
    fim: Date,
    excludeId?: string
  ): Promise<{ veiculo: boolean; funcionario: boolean }> {
    const db = getDb();
    const excludeParam = excludeId ?? '00000000-0000-0000-0000-000000000000';

    // Colunas TIMESTAMPTZ vs parâmetros TIMESTAMPTZ: comparação direta é correta.
    const baseCondition = `
      status NOT IN ('CONCLUIDO', 'CANCELADO')
      AND $1 < fim_estimado_em
      AND $2 > agendado_para
      AND id != $3
    `;

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

  /**
   * Regra do fluxo de agendamento do cliente:
   * o slot fica indisponível quando o número de agendamentos ativos no intervalo
   * atinge a capacidade da oficina (oficinas.quantidade_boxes).
   */
  static async checkWorkshopConflict(
    inicio: Date,
    fim: Date,
    excludeId?: string
  ): Promise<boolean> {
    const db = getDb();
    const excludeParam = excludeId ?? '00000000-0000-0000-0000-000000000000';

    const oficinaResult = await db.query(`SELECT quantidade_boxes FROM oficinas LIMIT 1`);
    const quantidadeBoxes: number = (oficinaResult.rowCount ?? 0) > 0
      ? (oficinaResult.rows[0].quantidade_boxes as number)
      : 1;

    // Colunas TIMESTAMPTZ vs parâmetros TIMESTAMPTZ: comparação direta correta.
    const countResult = await db.query(
      `SELECT COUNT(*) AS total
       FROM agendamentos
       WHERE status NOT IN ('CONCLUIDO', 'CANCELADO')
         AND $1 < fim_estimado_em
         AND $2 > agendado_para
         AND id != $3`,
      [inicio, fim, excludeParam]
    );

    const total = parseInt(countResult.rows[0].total as string, 10);
    return total >= quantidadeBoxes;
  }

  /**
   * Constrói os timestamps de início e fim de um slot no fuso da oficina.
   * Recebe data (YYYY-MM-DD) + hora (int) como intenção local — sem depender
   * do timezone do dispositivo do cliente.
   */
  static async buildSlotTimestamps(
    dataIso: string,
    hora: number,
    duracaoMinutos: number
  ): Promise<{ inicio: Date; fim: Date }> {
    const db = getDb();

    const result = await db.query(
      `SELECT
         ($1::date + ($2::int || ':00:00')::time) AT TIME ZONE $3 AS inicio,
         ($1::date + ($2::int || ':00:00')::time) AT TIME ZONE $3
           + ($4::int * interval '1 minute') AS fim`,
      [dataIso, hora, AgendamentoModel.WORKSHOP_TIMEZONE, duracaoMinutos]
    );

    return {
      inicio: result.rows[0].inicio as Date,
      fim: result.rows[0].fim as Date,
    };
  }

  static async findUnavailableHoursByDate(dataIso: string): Promise<number[]> {
    const db = getDb();

    const [quantidadeBoxesResult, slotsResult] = await Promise.all([
      db.query(`SELECT quantidade_boxes FROM oficinas LIMIT 1`),
      db.query(
        `SELECT EXTRACT(HOUR FROM slot_inicio AT TIME ZONE $2)::int AS hora,
                COUNT(a.id) AS ocupados
         FROM generate_series(
               ($1::date + time '07:00') AT TIME ZONE $2,
               ($1::date + time '18:00') AT TIME ZONE $2,
               interval '1 hour'
             ) AS slot_inicio
         LEFT JOIN agendamentos a
           ON a.status NOT IN ('CONCLUIDO', 'CANCELADO')
          AND a.agendado_para  < slot_inicio + interval '1 hour'
          AND a.fim_estimado_em > slot_inicio
         GROUP BY slot_inicio
         ORDER BY slot_inicio`,
        [dataIso, AgendamentoModel.WORKSHOP_TIMEZONE]
      ),
    ]);

    const quantidadeBoxes: number = (quantidadeBoxesResult.rowCount ?? 0) > 0
      ? (quantidadeBoxesResult.rows[0].quantidade_boxes as number)
      : 1;

    const indisponiveis: number[] = [];
    for (const row of slotsResult.rows) {
      const hora = row.hora as number;
      const ocupados = parseInt(row.ocupados as string, 10);
      if (ocupados >= quantidadeBoxes) {
        indisponiveis.push(hora);
      }
    }

    return indisponiveis;
  }

  static async create(data: {
    cliente_id: string;
    veiculo_id: string;
    funcionario_id?: string;
    inicio: Date;
    fim: Date;
    duracao_total_minutos: number;
    notas_cliente?: string;
  }): Promise<AgendamentoDTO> {
    const db = getDb();
    const { cliente_id, veiculo_id, funcionario_id, inicio, fim, duracao_total_minutos, notas_cliente } = data;

    const result = await db.query(
      `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
       VALUES ($1, $2, $3, $4, $5, $6, 'PENDENTE', $7) RETURNING *`,
      [cliente_id, veiculo_id, funcionario_id, inicio, duracao_total_minutos, fim, notas_cliente]
    );
    return result.rows[0];
  }

  static async createWithInitialBudget(
    data: {
      cliente_id: string;
      veiculo_id: string;
      funcionario_id?: string;
      inicio: Date;
      fim: Date;
      duracao_total_minutos: number;
      notas_cliente?: string;
      status?: string;
    }
  ): Promise<{ agendamento: AgendamentoDTO; orcamento: OrcamentoDTO }> {
    const db = getDb();
    const client = await db.connect();
    const { cliente_id, veiculo_id, funcionario_id, inicio, fim, duracao_total_minutos, notas_cliente, status } = data;

    try {
      await client.query('BEGIN');

      const agendamentoResult = await client.query(
        `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
         VALUES ($1, $2, $3, $4, $5, $6, 'PENDENTE', $7)
         RETURNING *`,
        [cliente_id, veiculo_id, funcionario_id, inicio, duracao_total_minutos, fim, notas_cliente]
      );

      const agendamento = agendamentoResult.rows[0] as AgendamentoDTO;

      const orcamentoResult = await client.query(
        `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
         VALUES ($1, $2, $3, $4, 0, NOW() + INTERVAL '7 days')
         RETURNING *`,
        [agendamento.id, cliente_id, funcionario_id ?? null, status ?? 'RASCUNHO']
      );

      await client.query('COMMIT');
      return {
        agendamento,
        orcamento: orcamentoResult.rows[0] as OrcamentoDTO,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
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
  ): Promise<ExecucaoServicoDTO> {
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

