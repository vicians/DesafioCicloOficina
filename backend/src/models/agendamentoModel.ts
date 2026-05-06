import { getDb } from '../config/database';
import type { AgendamentoDTO, CreateAgendamentoDTO } from '../../../shared/dtos/agendamentoDto';
import type { ExecucaoServicoDTO } from '../../../shared/dtos/execucaoServicoDto';

export class AgendamentoModel {
  static async findAll(): Promise<any[]> {
    const db = getDb();
    const query = `
      SELECT 
        a.*,
        c.nome AS cliente_nome,
        EXISTS (SELECT 1 FROM orcamentos o WHERE o.agendamento_id = a.id) AS possui_orcamento,
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
      'SELECT * FROM agendamentos WHERE cliente_id = $1 ORDER BY agendado_para ASC',
      [clienteId]
    );
    return result.rows;
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

    const oficinaResult = await db.query(
      `SELECT quantidade_boxes FROM oficinas LIMIT 1`
    );
    const quantidadeBoxes: number = (oficinaResult.rowCount ?? 0) > 0
      ? (oficinaResult.rows[0].quantidade_boxes as number)
      : 1;

    const countResult = await db.query(
      `SELECT COUNT(*) AS total
       FROM agendamentos
       WHERE status IN ('PENDENTE', 'CONFIRMADO')
         AND $1 < fim_estimado_em
         AND $2 > agendado_para
         AND id != $3`,
      [inicio, fim, excludeParam]
    );

    const total = parseInt(countResult.rows[0].total as string, 10);
    return total >= quantidadeBoxes;
  }

  static async findUnavailableHoursByDate(dataIso: string): Promise<number[]> {
    const db = getDb();

    const [ano, mes, dia] = dataIso.split('-').map(Number);
    const inicioDia = new Date(ano, mes - 1, dia, 0, 0, 0, 0);
    const fimDia = new Date(ano, mes - 1, dia + 1, 0, 0, 0, 0);

    const [agendamentosResult, oficinaResult] = await Promise.all([
      db.query(
        `SELECT agendado_para, fim_estimado_em
         FROM agendamentos
         WHERE status IN ('PENDENTE', 'CONFIRMADO')
           AND agendado_para < $2
           AND fim_estimado_em > $1`,
        [inicioDia, fimDia]
      ),
      db.query(`SELECT quantidade_boxes FROM oficinas LIMIT 1`),
    ]);

    const quantidadeBoxes: number = (oficinaResult.rowCount ?? 0) > 0
      ? (oficinaResult.rows[0].quantidade_boxes as number)
      : 1;

    const indisponiveis = new Set<number>();

    for (let hora = 7; hora <= 18; hora++) {
      const slotInicio = new Date(ano, mes - 1, dia, hora, 0, 0, 0);
      const slotFim = new Date(ano, mes - 1, dia, hora + 1, 0, 0, 0);

      const ocupados = agendamentosResult.rows.filter((row) => {
        const inicio = new Date(row.agendado_para as string | Date);
        const fim = new Date(row.fim_estimado_em as string | Date);
        return inicio < slotFim && fim > slotInicio;
      }).length;

      if (ocupados >= quantidadeBoxes) {
        indisponiveis.add(hora);
      }
    }

    return Array.from(indisponiveis).sort((a, b) => a - b);
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

