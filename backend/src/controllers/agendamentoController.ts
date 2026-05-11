import { Request, Response } from 'express';
import { AgendamentoModel } from '../models/agendamentoModel';
import { OrcamentoModel } from '../models/orcamentoModel';
import { ExecucaoServicoModel } from '../models/execucaoServicoModel';
import { NotificationModel } from '../models/notificationModel';
import { sendPushToUsers } from '../services/pushService';

const STATUS_PERMITIDOS = ['PENDENTE', 'CONFIRMADO', 'CONCLUIDO', 'CANCELADO'] as const;
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
    const { cliente_id, veiculo_id, funcionario_id, notas_cliente, para_avaliacao } = req.body;
    const servicos = req.body.servicos as Array<{ servico_id: string; quantidade?: number }> | undefined;

    // Contrato: cliente envia data (YYYY-MM-DD) + hora (int 7-18) como intenção pura.
    // O backend constrói o TIMESTAMPTZ no fuso da oficina — sem depender do timezone do dispositivo.
    const data: string = req.body.data;
    const hora: number = Number(req.body.hora);
    const duracao = Number(req.body.duracao_total_minutos);

    if (!cliente_id || !veiculo_id || !data || !Number.isFinite(hora)) {
      return res.status(400).json({ error: 'cliente_id, veiculo_id, data e hora são obrigatórios' });
    }

    if (!req.user) {
      return res.status(401).json({ error: 'Não autorizado' });
    }

    if (req.user.role === '2' && req.user.id !== cliente_id) {
      return res.status(403).json({ error: 'Você não tem permissão para agendar para este cliente' });
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(data)) {
      return res.status(400).json({ error: 'data deve estar no formato YYYY-MM-DD' });
    }

    if (!Number.isFinite(hora) || hora < 7 || hora > 18) {
      return res.status(400).json({ error: 'hora deve ser um inteiro entre 7 e 18' });
    }

    if (!Number.isFinite(duracao) || duracao <= 0) {
      return res.status(400).json({ error: 'duracao_total_minutos deve ser maior que zero' });
    }

    // Regra de negócio: pelo menos um serviço ou flag de avaliação é obrigatório
    const temServicos = Array.isArray(servicos) && servicos.length > 0;
    const ehAvaliacao = para_avaliacao === true;
    if (!temServicos && !ehAvaliacao) {
      return res.status(400).json({
        error: 'Selecione pelo menos um serviço ou solicite avaliação do veículo.',
      });
    }

    const clienteVeiculoOk = await AgendamentoModel.clienteVeiculoRelacionados(cliente_id, veiculo_id);
    if (!clienteVeiculoOk) {
      return res.status(400).json({ error: 'veiculo_id não pertence ao cliente informado' });
    }

    // Constrói o TIMESTAMPTZ no fuso do servidor (oficina) — data + hora local → UTC correto.
    const { inicio, fim } = await AgendamentoModel.buildSlotTimestamps(data, hora, duracao);

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

    const agendamentoData = {
      cliente_id,
      veiculo_id,
      funcionario_id,
      inicio,
      fim,
      duracao_total_minutos: duracao,
      notas_cliente,
    };

    let agendamento;
    try {
      if (ehAvaliacao) {
        agendamento = await AgendamentoModel.create(agendamentoData);
        await OrcamentoModel.create({
          agendamento_id: agendamento.id,
          cliente_id,
          funcionario_id: funcionario_id ?? null,
        });
      } else {
        const created = await AgendamentoModel.createWithApprovedInitialBudget(agendamentoData);
        agendamento = created.agendamento;

        const { CatalogoServicoModel } = await import('../models/catalogoServicoModel');
        for (const item of servicos!) {
          if (!item.servico_id) continue;
          const catalogo = await CatalogoServicoModel.findById(item.servico_id);
          if (!catalogo) continue;
          await OrcamentoModel.addServico(created.orcamento.id, item.servico_id, item.quantidade ?? 1, catalogo.preco);
        }
        await OrcamentoModel.recalcularTotal(created.orcamento.id);
      }
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
      const mensagem = `Agendamento ${agendamento.id} criado para ${data} às ${hora}:00.`;
      const notifIds = await NotificationModel.createForUsers(internalUserIds, {
        tipo: 'new_schedule',
        titulo,
        mensagem,
        referencia_id: agendamento.id,
        referencia_tipo: 'agendamento',
      });
      await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem);
    } catch (error) {
      console.error('Falha ao criar notificações internas de agendamento:', error);
    }

    return res.status(201).json(agendamento);
  }


  static async confirmarRecebimento(req: Request, res: Response) {
    const { id } = req.params;
    const { funcionario_id } = req.body ?? {};

    const agendamento = await AgendamentoModel.findById(id);
    if (!agendamento) {
      return res.status(404).json({ error: 'Agendamento não encontrado' });
    }

    let orcamento = await OrcamentoModel.findByAgendamentoId(id);
    if (!orcamento) {
      orcamento = await OrcamentoModel.create({
        agendamento_id: id,
        cliente_id: agendamento.cliente_id,
        funcionario_id: funcionario_id ?? agendamento.funcionario_id,
      });
    }

    if (orcamento.status === 'ENVIADO') {
      return res.status(409).json({
        error: 'Este agendamento possui add-ons pendentes de aprovação do cliente',
      });
    }

    if (orcamento.status === 'REJEITADO') {
      return res.status(409).json({
        error: 'Não é possível iniciar OS com orçamento rejeitado',
      });
    }

    if (orcamento.status !== 'APROVADO') {
      const aprovado = await OrcamentoModel.aprovar(
        orcamento.id,
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      );
      if (!aprovado) {
        return res.status(409).json({ error: 'Não foi possível aprovar o orçamento automaticamente' });
      }
      orcamento = aprovado;
    }

    await ExecucaoServicoModel.ensureByOrcamentoId(
      orcamento.id,
      funcionario_id ?? orcamento.funcionario_id ?? agendamento.funcionario_id ?? null,
    );

    await AgendamentoModel.updateStatus(id, 'CONCLUIDO');

    const execucao = await ExecucaoServicoModel.findByOrcamentoId(orcamento.id);
    return res.status(201).json(execucao);
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

