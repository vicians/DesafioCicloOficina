import { Request, Response } from 'express';
import { AgendamentoModel } from '../models/agendamentoModel';
import { OrcamentoModel } from '../models/orcamentoModel';
import { ExecucaoServicoModel } from '../models/execucaoServicoModel';
import { NotificationModel } from '../models/notificationModel';
import { UsuarioModel } from '../models/usuarioModel';
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

    if (!cliente_id || !veiculo_id || !data || !Number.isFinite(hora)) {
      return res.status(400).json({ error: 'cliente_id, veiculo_id, data e hora são obrigatórios' });
    }

    if (!req.user) {
      return res.status(401).json({ error: 'Não autorizado' });
    }

    if (req.user.role === '2' && req.user.id !== cliente_id) {
      return res.status(403).json({ error: 'Você não tem permissão para agendar para este cliente' });
    }

    const cliente = await UsuarioModel.findById(cliente_id);
    if (!cliente || cliente.tipo_id !== 2) {
      return res.status(422).json({ error: 'cliente_id inválido: o usuário informado não é um cliente.' });
    }

    if (funcionario_id !== undefined && funcionario_id !== null && String(funcionario_id).trim() !== '') {
      const funcionario = await UsuarioModel.findById(String(funcionario_id));
      if (!funcionario || funcionario.tipo_id !== 3) {
        return res.status(422).json({ error: 'funcionario_id inválido: o usuário informado não é um mecânico.' });
      }
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(data)) {
      return res.status(400).json({ error: 'data deve estar no formato YYYY-MM-DD' });
    }

    if (!Number.isFinite(hora) || hora < 7 || hora > 18) {
      return res.status(400).json({ error: 'hora deve ser um inteiro entre 7 e 18' });
    }

    // Regra de negócio: pelo menos um serviço ou flag de avaliação é obrigatório
    const temServicos = Array.isArray(servicos) && servicos.length > 0;
    const ehAvaliacao = para_avaliacao === true;
    if (!temServicos && !ehAvaliacao) {
      return res.status(400).json({
        error: 'Selecione pelo menos um serviço ou solicite avaliação do veículo.',
      });
    }

    // Calcula duração real somando duracao_minutos de cada serviço selecionado.
    // Ignora o valor enviado pelo frontend (duracao_total_minutos) por segurança (RN de Duração).
    let duracao = 60; // Duração padrão para avaliação
    if (temServicos) {
      const { CatalogoServicoModel } = await import('../models/catalogoServicoModel');
      let soma = 0;
      for (const item of servicos!) {
        if (!item.servico_id) continue;
        const catalogo = await CatalogoServicoModel.findById(item.servico_id);
        if (catalogo) {
          // A quantidade não multiplica a duração se assumirmos que a duração é por item, mas vamos deixar como 1 se não enviado.
          // Aqui a regra de negócio dita soma das durações dos serviços no catálogo
          soma += (catalogo.duracao_minutos ?? 60);
        }
      }
      if (soma > 0) duracao = soma;
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
          status: 'RASCUNHO',
        });
      } else {
        const created = await AgendamentoModel.createWithInitialBudget({
          ...agendamentoData,
          status: 'RASCUNHO', // Inicia como RASCUNHO para adicionar os itens
        });
        agendamento = created.agendamento;

        const { CatalogoServicoModel } = await import('../models/catalogoServicoModel');
        for (const item of servicos!) {
          if (!item.servico_id) continue;
          const catalogo = await CatalogoServicoModel.findById(item.servico_id);
          if (!catalogo) continue;
          // addServico vai manter em RASCUNHO
          await OrcamentoModel.addServico(created.orcamento.id, item.servico_id, item.quantidade ?? 1, catalogo.preco);
        }
        await OrcamentoModel.recalcularTotal(created.orcamento.id);
        
        // Agora que terminou de adicionar, se for escolha do cliente, marca como APROVADO
        await OrcamentoModel.update(created.orcamento.id, { status: 'APROVADO' });
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

    const orcamento = await OrcamentoModel.findByAgendamentoId(id);
    if (!orcamento) {
      return res.status(400).json({ error: 'Este agendamento não possui um orçamento vinculado.' });
    }

    // REGRA 1 e 4: Se não houver serviços E não estiver aprovado, bloqueia (é uma análise pendente).
    // Se houver serviços, permitimos a conclusão direta (Flow A).
    const orcamentoDetalhado = await OrcamentoModel.findById(orcamento.id);
    const temItens = (orcamentoDetalhado?.servicos?.length || 0) > 0 || (orcamentoDetalhado?.produtos?.length || 0) > 0;
    const isAprovado = orcamento.status === 'APROVADO';

    if (!temItens && !isAprovado) {
      return res.status(400).json({ 
        error: 'Agendamento sem serviços não pode ser concluído. Realize a análise e adicione os itens primeiro.' 
      });
    }

    if (orcamento.status === 'ENVIADO') {
      return res.status(409).json({
        error: 'Este agendamento possui orçamento pendente de aprovação do cliente',
      });
    }

    if (orcamento.status === 'REJEITADO' || orcamento.status === 'CANCELADO') {
      return res.status(409).json({
        error: `Não é possível concluir agendamento com orçamento ${orcamento.status.toLowerCase()}`,
      });
    }

    if (orcamento.status !== 'APROVADO') {
      return res.status(409).json({
        error: 'O orçamento precisa ser aprovado pelo cliente antes de concluir o agendamento',
      });
    }

    try {
      await ExecucaoServicoModel.ensureByOrcamentoId(
        orcamento.id,
        null // Força o backend a sempre buscar um mecânico livre
      );
    } catch (error: any) {
      if (error.message === 'Não é possivél iniciar serviço pois todos os mecanicos estão ocupados no momento') {
        return res.status(409).json({ error: error.message });
      }
      throw error;
    }

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

    const user = req.user;
    const existing = await AgendamentoModel.findById(id);

    if (!existing) {
      return res.status(404).json({ error: 'Agendamento não encontrado' });
    }

    // Regra de segurança: Cliente (role 2) só pode alterar seus próprios agendamentos
    if (user?.role === '2' && existing.cliente_id !== user.id) {
      return res.status(403).json({ error: 'Forbidden: Você não tem permissão para alterar este agendamento' });
    }

    const agendamento = await AgendamentoModel.updateStatus(id, status);

    // Se o atendimento for cancelado, cancelamos também o orçamento
    if (status === 'CANCELADO') {
      const orcamento = await OrcamentoModel.findByAgendamentoId(id);
      if (orcamento) {
        await OrcamentoModel.update(orcamento.id, { 
          status: 'CANCELADO',
          observacoes: (orcamento.observacoes ?? '') + '\n[SISTEMA] Orçamento cancelado devido ao cancelamento do agendamento.'
        });
      }
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
    const { orcamento_id } = req.body;

    if (!orcamento_id) {
      return res.status(400).json({ error: 'orcamento_id é obrigatório' });
    }

    try {
      const execucao = await AgendamentoModel.iniciarExecucao(orcamento_id, null); // Força mecânico livre
      return res.status(201).json(execucao);
    } catch (error: any) {
      if (error.message === 'Não é possivél iniciar serviço pois todos os mecanicos estão ocupados no momento') {
        return res.status(409).json({ error: error.message });
      }
      throw error;
    }
  }
}

