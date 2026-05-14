import { Request, Response } from 'express';
import { OrcamentoModel } from '../models/orcamentoModel';
import { AgendamentoModel } from '../models/agendamentoModel';
import { ExecucaoServicoModel } from '../models/execucaoServicoModel';
import { CatalogoServicoModel } from '../models/catalogoServicoModel';
import { ProdutoModel } from '../models/produtoModel';
import { NotificationModel } from '../models/notificationModel';
import { sendPushToUsers } from '../services/pushService';

export class OrcamentoController {
  static async index(req: Request, res: Response) {
    const user = req.user;
    let clientIdFilter: string | undefined = undefined;

    // Se o usuário for cliente (role '2'), só pode ver os próprios orçamentos
    if (user?.role === '2') {
      clientIdFilter = user.id;
    }

    const orcamentos = await OrcamentoModel.findAll(clientIdFilter);
    return res.json(orcamentos);
  }

  static async show(req: Request, res: Response) {
    const orcamento = await OrcamentoModel.findById(req.params.id);
    if (!orcamento) return res.status(404).json({ error: 'Orçamento não encontrado' });

    // Verificação de segurança para clientes
    if (req.user?.role === '2' && orcamento.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden: Você não tem permissão para acessar este orçamento' });
    }

    return res.json(orcamento);
  }

  static async store(req: Request, res: Response) {
    const { cliente_id, funcionario_id, agendamento_id } = req.body;

    if (!cliente_id) {
      return res.status(400).json({ error: 'cliente_id é obrigatório' });
    }

    if (agendamento_id) {
      const existing = await OrcamentoModel.findByAgendamentoId(agendamento_id);
      if (existing) {
        return res.status(409).json({
          error: 'Este agendamento já foi enviado para orçamentos',
          orcamento_id: existing.id,
        });
      }
    }

    const orcamento = await OrcamentoModel.create({ cliente_id, funcionario_id, agendamento_id });
    return res.status(201).json(orcamento);
  }

  // ── Itens de Serviço ──────────────────────────────────────────────────────

  static async addServico(req: Request, res: Response) {
    const { id } = req.params;
    const { servico_id, quantidade = 1 } = req.body;

    if (!servico_id) {
      return res.status(400).json({ error: 'servico_id é obrigatório' });
    }

    // Congela o preco_unitario do catálogo no momento da adição (RN de histórico financeiro)
    const servico = await CatalogoServicoModel.findById(servico_id);
    if (!servico) return res.status(404).json({ error: 'Serviço não encontrado no catálogo' });

    const orcamentoExistente = await OrcamentoModel.findById(id);
    if (orcamentoExistente && (orcamentoExistente.status === 'ENVIADO' || orcamentoExistente.status === 'APROVADO')) {
      await OrcamentoModel.updateStatus(id, 'RASCUNHO');
    }

    await OrcamentoModel.addServico(id, servico_id, quantidade, servico.preco);
    await OrcamentoModel.recalcularTotal(id);

    const orcamento = await OrcamentoModel.findById(id);
    return res.status(201).json(orcamento);
  }

  static async removeServico(req: Request, res: Response) {
    const { item_id } = req.params;

    const orcamentoExistente = await OrcamentoModel.findById(req.params.id);
    if (orcamentoExistente && (orcamentoExistente.status === 'ENVIADO' || orcamentoExistente.status === 'APROVADO')) {
      await OrcamentoModel.updateStatus(req.params.id, 'RASCUNHO');
    }

    const removido = await OrcamentoModel.removeServico(item_id);
    if (!removido) return res.status(404).json({ error: 'Item de serviço não encontrado' });

    await OrcamentoModel.recalcularTotal(req.params.id);

    const orcamento = await OrcamentoModel.findById(req.params.id);
    return res.json(orcamento);
  }

  // ── Itens de Produto ──────────────────────────────────────────────────────

  static async addProduto(req: Request, res: Response) {
    const { id } = req.params;
    const { produto_id, quantidade } = req.body;

    if (!produto_id || !quantidade) {
      return res.status(400).json({ error: 'produto_id e quantidade são obrigatórios' });
    }

    // Congela o preco_unitario do estoque no momento da adição
    const produto = await ProdutoModel.findById(produto_id);
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });

    const orcamentoExistente = await OrcamentoModel.findById(id);
    if (orcamentoExistente && (orcamentoExistente.status === 'ENVIADO' || orcamentoExistente.status === 'APROVADO')) {
      await OrcamentoModel.updateStatus(id, 'RASCUNHO');
    }

    await OrcamentoModel.addProduto(id, produto_id, quantidade, produto.valor);
    await OrcamentoModel.recalcularTotal(id);

    const orcamento = await OrcamentoModel.findById(id);
    return res.status(201).json(orcamento);
  }

  static async removeProduto(req: Request, res: Response) {
    const { item_id } = req.params;

    const orcamentoExistente = await OrcamentoModel.findById(req.params.id);
    if (orcamentoExistente && (orcamentoExistente.status === 'ENVIADO' || orcamentoExistente.status === 'APROVADO')) {
      await OrcamentoModel.updateStatus(req.params.id, 'RASCUNHO');
    }

    const removido = await OrcamentoModel.removeProduto(item_id);
    if (!removido) return res.status(404).json({ error: 'Item de produto não encontrado' });

    await OrcamentoModel.recalcularTotal(req.params.id);

    const orcamento = await OrcamentoModel.findById(req.params.id);
    return res.json(orcamento);
  }

  // ── Aprovação ─────────────────────────────────────────────────────────────

  static async rejeitar(req: Request, res: Response) {
    const orcamento = await OrcamentoModel.rejeitar(req.params.id);

    if (!orcamento) {
      return res.status(409).json({
        error: 'Orçamento não encontrado ou já está em status final (APROVADO, REJEITADO ou PAGO)',
      });
    }

    // Regra: Se o orçamento for rejeitado, o agendamento também é cancelado (RN 8)
    if (orcamento.agendamento_id) {
      try {
        await AgendamentoModel.updateStatus(orcamento.agendamento_id, 'CANCELADO');
      } catch (error) {
        console.error('Falha ao cancelar agendamento vinculado ao orçamento rejeitado:', error);
      }
    }

    try {
      const internalUserIds = await NotificationModel.findInternalUserIds();
      const titulo = 'Orçamento recusado pelo cliente';
      const mensagem = `Orçamento ${orcamento.id} foi recusado e o agendamento foi cancelado automaticamente.`;
      const notifIds = await NotificationModel.createForUsers(internalUserIds, {
        tipo: 'rejected_budget',
        titulo,
        mensagem,
        referencia_id: orcamento.id,
        referencia_tipo: 'orcamento',
      });
      await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem);
    } catch (error) {
      // Não interrompe o fluxo principal por falha de notificação.
      console.error('Falha ao criar notificações internas de orçamento recusado:', error);
    }

    return res.json(orcamento);
  }

  static async aprovar(req: Request, res: Response) {
    const { valido_ate } = req.body;

    if (!valido_ate) {
      return res.status(400).json({ error: 'valido_ate é obrigatório para aprovação' });
    }

    const orcamento = await OrcamentoModel.aprovar(req.params.id, new Date(valido_ate));

    if (!orcamento) {
      return res.status(409).json({
        error: 'Orçamento não encontrado ou já está em status final (APROVADO, REJEITADO ou PAGO)',
      });
    }

    try {
      const internalUserIds = await NotificationModel.findInternalUserIds();
      const titulo = 'Orçamento aprovado pelo cliente';
      const mensagem = `Orçamento ${orcamento.id} foi aprovado e o agendamento está pronto para conclusão na oficina.`;
      const notifIds = await NotificationModel.createForUsers(internalUserIds, {
        tipo: 'approved_budget',
        titulo,
        mensagem,
        referencia_id: orcamento.id,
        referencia_tipo: 'orcamento',
      });
      await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem);
    } catch (error) {
      // Não interrompe o fluxo principal de aprovação por falha de notificação.
      console.error('Falha ao criar notificações internas de orçamento aprovado:', error);
    }

    // Regra: Ao aprovar, já cria a entrada de execução para aparecer na lista de serviços
    try {
      await ExecucaoServicoModel.ensureByOrcamentoId(
        orcamento.id,
        orcamento.funcionario_id
      );
    } catch (error) {
      console.error('Falha ao criar execução automática após aprovação:', error);
    }

    return res.json(orcamento);
  }

  static async enviarAddons(req: Request, res: Response) {
    const orcamento = await OrcamentoModel.enviarAddons(req.params.id);

    if (!orcamento) {
      return res.status(409).json({
        error: 'Somente orçamentos rascunho ou já aprovados podem ser enviados para o cliente',
      });
    }

    try {
      const internalUserIds = await NotificationModel.findInternalUserIds();
      const titulo = 'Add-ons enviados para aprovação';
      const mensagem = `Orçamento ${orcamento.id} possui itens extras pendentes de aprovação do cliente.`;
      const notifIds = await NotificationModel.createForUsers(internalUserIds, {
        tipo: 'addons_sent',
        titulo,
        mensagem,
        referencia_id: orcamento.id,
        referencia_tipo: 'orcamento',
      });
      await sendPushToUsers(internalUserIds, notifIds, titulo, mensagem);
    } catch (error) {
      console.error('Falha ao criar notificações de add-ons enviados:', error);
    }

    return res.json(orcamento);
  }

  static async rejeitarAddons(req: Request, res: Response) {
    const orcamento = await OrcamentoModel.rejeitarAddons(req.params.id);

    if (!orcamento) {
      return res.status(409).json({
        error: 'Somente orçamentos em ENVIADO podem ter add-ons rejeitados',
      });
    }

    return res.json(orcamento);
  }

  static async update(req: Request, res: Response) {
    const { id } = req.params;
    const data = req.body;

    const orcamento = await OrcamentoModel.update(id, data);
    if (!orcamento) {
      return res.status(404).json({ error: 'Orçamento não encontrado' });
    }

    return res.json(orcamento);
  }

  static async enviar(req: Request, res: Response) {
    const { id } = req.params;
    const orcamento = await OrcamentoModel.enviar(id);

    if (!orcamento) {
      return res.status(409).json({
        error: 'Somente orçamentos em RASCUNHO podem ser enviados para aprovação inicial',
      });
    }

    try {
      const titulo = 'Orçamento disponível para aprovação';
      const mensagem = `O orçamento para o seu veículo ${orcamento.veiculo_modelo || ''} está pronto para revisão.`;
      
      const notif = await NotificationModel.create({
        usuario_id: orcamento.cliente_id,
        tipo: 'budget_sent',
        titulo,
        mensagem,
        referencia_id: orcamento.id,
        referencia_tipo: 'orcamento',
      });

      await sendPushToUsers([orcamento.cliente_id], [notif.id], titulo, mensagem);
    } catch (error) {
      console.error('Falha ao notificar cliente sobre orçamento enviado:', error);
    }

    return res.json(orcamento);
  }

}

