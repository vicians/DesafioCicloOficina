import { getDb } from '../config/database';
import type { ExecucaoServicoDTO, ExecucaoServicoDetalhadaDTO } from '../../../shared/dtos/execucaoServicoDto';

export class ExecucaoServicoModel {
  static async findAll(): Promise<ExecucaoServicoDetalhadaDTO[]> {
    const db = getDb();
    const query = `
      SELECT 
        e.*,
        o.valor_total,
        c.nome AS cliente_nome,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa,
        COALESCE(
          (SELECT json_agg(json_build_object('id', ios.id, 'item_id', ios.servico_id, 'nome', cs.nome, 'quantidade', ios.quantidade, 'preco_unitario', ios.preco_unitario, 'preco_total', ios.quantidade * ios.preco_unitario))
           FROM itens_orcamento_servico ios JOIN catalogo_servicos cs ON ios.servico_id = cs.id WHERE ios.orcamento_id = o.id),
          '[]'::json
        ) AS itens_servico,
        COALESCE(
          (SELECT json_agg(json_build_object('id', iop.id, 'item_id', iop.produto_id, 'nome', p.nome, 'quantidade', iop.quantidade, 'preco_unitario', iop.preco_unitario, 'preco_total', iop.quantidade * iop.preco_unitario))
           FROM itens_orcamento_produto iop JOIN produtos p ON iop.produto_id = p.id WHERE iop.orcamento_id = o.id),
          '[]'::json
        ) AS itens_produto,
        (SELECT cs.nome FROM itens_orcamento_servico ios JOIN catalogo_servicos cs ON ios.servico_id = cs.id WHERE ios.orcamento_id = o.id LIMIT 1) AS servico_resumo
      FROM execucoes_servico e
      JOIN orcamentos o ON e.orcamento_id = o.id
      JOIN usuarios c ON o.cliente_id = c.id
      LEFT JOIN agendamentos a ON o.agendamento_id = a.id
      LEFT JOIN veiculos v ON a.veiculo_id = v.id
      ORDER BY e.iniciado_em DESC NULLS LAST
    `;
    const result = await db.query(query);
    return result.rows;
  }

  static async findById(id: string): Promise<ExecucaoServicoDetalhadaDTO | null> {
    const db = getDb();
    const query = `
      SELECT 
        e.*,
        o.valor_total,
        c.nome AS cliente_nome,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa,
        COALESCE(
          (SELECT json_agg(json_build_object('id', ios.id, 'item_id', ios.servico_id, 'nome', cs.nome, 'quantidade', ios.quantidade, 'preco_unitario', ios.preco_unitario))
           FROM itens_orcamento_servico ios JOIN catalogo_servicos cs ON ios.servico_id = cs.id WHERE ios.orcamento_id = o.id),
          '[]'::json
        ) AS servicos,
        COALESCE(
          (SELECT json_agg(json_build_object('id', iop.id, 'item_id', iop.produto_id, 'nome', p.nome, 'quantidade', iop.quantidade, 'preco_unitario', iop.preco_unitario))
           FROM itens_orcamento_produto iop JOIN produtos p ON iop.produto_id = p.id WHERE iop.orcamento_id = o.id),
          '[]'::json
        ) AS produtos
      FROM execucoes_servico e
      JOIN orcamentos o ON e.orcamento_id = o.id
      JOIN usuarios c ON o.cliente_id = c.id
      LEFT JOIN agendamentos a ON o.agendamento_id = a.id
      LEFT JOIN veiculos v ON a.veiculo_id = v.id
      WHERE e.id = $1
    `;
    const result = await db.query(query, [id]);
    return result.rows[0] ?? null;
  }

  static async findByOrcamentoId(orcamento_id: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM execucoes_servico WHERE orcamento_id = $1',
      [orcamento_id]
    );
    return result.rows[0] ?? null;
  }

  static async updateNotas(id: string, notas_internas: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'UPDATE execucoes_servico SET notas_internas = $1 WHERE id = $2 RETURNING *',
      [notas_internas, id]
    );
    return result.rows[0] ?? null;
  }

  /**
   * Finaliza a execução: seta finalizado_em = NOW() e status = CONCLUIDO.
   * Só deve ser chamado quando o status atual for EM_EXECUCAO ou REVISAO_TECNICA.
   * A validação do status anterior é feita no controller para retornar 409 semântico.
   */
  static async finalizar(id: string): Promise<ExecucaoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE execucoes_servico
       SET status = 'CONCLUIDO', finalizado_em = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );
    return result.rows[0] ?? null;
  }
}
