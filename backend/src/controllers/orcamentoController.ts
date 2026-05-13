import { Request, Response } from 'express';
import { OrcamentoModel } from '../models/orcamentoModel';
import { ExecucaoServicoModel } from '../models/execucaoServicoModel';
import { CatalogoServicoModel } from '../models/catalogoServicoModel';
import { ProdutoModel } from '../models/produtoModel';
import { NotificationModel } from '../models/notificationModel';
import { sendPushToUsers } from '../services/pushService';

export class OrcamentoController {
  static async index(req: Request, res: Response) {
    const orcamentos = await OrcamentoModel.findAll();
    return res.json(orcamentos);
  }

  static async show(req: Request, res: Response) {
    const orcamento = await OrcamentoModel.findById(req.params.id);
    if (!orcamento) return res.status(404).json({ error: 'Orçamento não encontrado' });
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

    await OrcamentoModel.addServico(id, servico_id, quantidade, servico.preco);
    await OrcamentoModel.recalcularTotal(id);

    const orcamento = await OrcamentoModel.findById(id);
    return res.status(201).json(orcamento);
  }

  static async removeServico(req: Request, res: Response) {
    const { item_id } = req.params;

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

    await OrcamentoModel.addProduto(id, produto_id, quantidade, produto.valor);
    await OrcamentoModel.recalcularTotal(id);

    const orcamento = await OrcamentoModel.findById(id);
    return res.status(201).json(orcamento);
  }

  static async removeProduto(req: Request, res: Response) {
    const { item_id } = req.params;

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

    try {
      const internalUserIds = await NotificationModel.findInternalUserIds();
      const titulo = 'Orçamento recusado pelo cliente';
      const mensagem = `Orçamento ${orcamento.id} foi recusado e precisa de revisão ou contato com o cliente.`;
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
      const mensagem = `Orçamento ${orcamento.id} foi aprovado e está pronto para execução.`;
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

    // Cria (ou garante) a execução de serviço vinculada ao orçamento aprovado.
    // Retorna os dados detalhados da execução para que o app já exiba a OS gerada.
    const execucao = await ExecucaoServicoModel.iniciarDeAprovacao(
      orcamento.id,
      orcamento.funcionario_id ?? null
    );

    return res.json(execucao ?? orcamento);
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

}

