import { Request, Response } from 'express';
import { OrcamentoModel } from '../models/orcamentoModel';
import { CatalogoServicoModel } from '../models/catalogoServicoModel';
import { ProdutoModel } from '../models/produtoModel';

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

    return res.json(orcamento);
  }
}

