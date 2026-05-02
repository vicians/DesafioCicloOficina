import { Request, Response } from 'express';
import { AgendamentoModel } from '../models/agendamentoModel';
import { NotificationModel } from '../models/notificationModel';
import { sendPushToUsers } from '../services/pushService';

const STATUS_PERMITIDOS = ['CONFIRMADO', 'CANCELADO'] as const;
type StatusPermitido = typeof STATUS_PERMITIDOS[number];

export class AgendamentoController {
  static async index(req: Request, res: Response) {
    const agendamentos = await AgendamentoModel.findAll();
    return res.json(agendamentos);
  }

  static async listByCliente(req: Request, res: Response) {
    const { clienteId } = req.params;
    const agendamentos = await AgendamentoModel.findByClienteId(clienteId);
    return res.json(agendamentos);
  }

  static async disponibilidade(req: Request, res: Response) {
    const data = String(req.query.data ?? '');
    const formatoValido = /^\d{4}-\d{2}-\d{2}$/.test(data);

    if (!formatoValido) {
      return res.status(400).json({ error: 'Query param data é obrigatório no formato YYYY-MM-DD' });
    }

    const horasIndisponiveis = await AgendamentoModel.findUnavailableHoursByDate(data);
    return res.json({ data, horas_indisponiveis: horasIndisponiveis });
  }

  static async store(req: Request, res: Response) {
    const { cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, notas_cliente } = req.body;

    if (!cliente_id || !veiculo_id || !agendado_para || !duracao_total_minutos) {
      return res.status(400).json({ error: 'cliente_id, veiculo_id, agendado_para e duracao_total_minutos são obrigatórios' });
    }

    const duracao = Number(duracao_total_minutos);
    if (!Number.isFinite(duracao) || duracao <= 0) {
      return res.status(400).json({ error: 'duracao_total_minutos deve ser maior que zero' });
    }

    const inicio = new Date(agendado_para);
    if (Number.isNaN(inicio.getTime())) {
      return res.status(400).json({ error: 'agendado_para inválido' });
    }

    const hora = inicio.getHours();
    if (inicio.getMinutes() !== 0 || inicio.getSeconds() !== 0 || hora < 7 || hora > 18) {
      return res.status(400).json({ error: 'agendado_para deve ser em hora cheia entre 07:00 e 18:00' });
    }

    const clienteVeiculoOk = await AgendamentoModel.clienteVeiculoRelacionados(cliente_id, veiculo_id);
    if (!clienteVeiculoOk) {
      return res.status(400).json({ error: 'veiculo_id não pertence ao cliente informado' });
    }

    const fim = new Date(inicio.getTime() + duracao * 60000);

    const conflitoOficina = await AgendamentoModel.checkWorkshopConflict(inicio, fim);
    if (conflitoOficina) {
      return res.status(409).json({ error: 'Horário já indisponível para agendamento' });
    }

    const conflito = await AgendamentoModel.checkConflict(veiculo_id, funcionario_id ?? null, inicio, fim);

    if (conflito.veiculo) {
      return res.status(409).json({ error: 'Veículo já possui agendamento nesse horário' });
    }
    if (conflito.funcionario) {
      return res.status(409).json({ error: 'Funcionário já possui agendamento nesse horário' });
    }

    let agendamento;
    try {
      agendamento = await AgendamentoModel.create({
        cliente_id,
        veiculo_id,
        funcionario_id,
        agendado_para,
        duracao_total_minutos: duracao,
        notas_cliente,
      });
    } catch (error: unknown) {
      const dbError = error as { code?: string; constraint?: string };
      if (dbError.code === '23505' && dbError.constraint === 'ux_agendamentos_slot_ativo') {
        return res.status(409).json({ error: 'Horário já indisponível para agendamento' });
      }
      throw error;
    }

    try {
      const internalUserIds = await NotificationModel.findInternalUserIds();
      const titulo = 'Novo agendamento recebido';
      const mensagem = `Agendamento ${agendamento.id} criado para ${new Date(agendado_para).toLocaleString('pt-BR')}.`;
      const notifIds = await NotificationModel.createForUsers(internalUserIds, {
        tipo: 'new_schedule',
        titulo,
        mensagem,
        referencia_id: agendamento.id,
        referencia_tipo: 'agendamento',
      });
      await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem);
    } catch (error) {
      // Não interrompe o fluxo principal de agendamento por falha de notificação.
      console.error('Falha ao criar notificações internas de agendamento:', error);
    }

    return res.status(201).json(agendamento);
  }

  static async updateStatus(req: Request, res: Response) {
    const { id } = req.params;
    const { status } = req.body;

    if (!STATUS_PERMITIDOS.includes(status as StatusPermitido)) {
      return res.status(400).json({
        error: `Status inválido. Valores aceitos: ${STATUS_PERMITIDOS.join(', ')}`,
      });
    }

    const agendamento = await AgendamentoModel.updateStatus(id, status);

    if (!agendamento) {
      return res.status(404).json({ error: 'Agendamento não encontrado' });
    }

    return res.json(agendamento);
  }

  /**
   * Cria ou atualiza a execução de serviço em execucoes_servico.
   * Requer que o agendamento tenha um orçamento APROVADO — a validação
   * de negócio (orçamento aprovado) fica na camada de serviço futura;
   * aqui apenas vincula o mecânico e registra o início.
   */
  static async iniciarExecucao(req: Request, res: Response) {
    const { id } = req.params;
    const { orcamento_id, funcionario_id } = req.body;

    if (!orcamento_id || !funcionario_id) {
      return res.status(400).json({ error: 'orcamento_id e funcionario_id são obrigatórios' });
    }

    const execucao = await AgendamentoModel.iniciarExecucao(orcamento_id, funcionario_id);
    return res.status(201).json(execucao);
  }
}

