import { getDb } from '../config/database';
import type { ProdutoDTO, CreateProdutoDTO } from '../../../shared/dtos/produtoDto';

export class ProdutoModel {
  static async findAll(): Promise<ProdutoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM produtos WHERE ativo = true ORDER BY nome ASC');
    return result.rows;
  }

  static async findById(id: string): Promise<ProdutoDTO | null> {
    const db = getDb();
    const result = await db.query('SELECT * FROM produtos WHERE id = $1', [id]);
    return result.rows[0] ?? null;
  }

  static async findByNome(nome: string): Promise<ProdutoDTO[]> {
    const db = getDb();
    const result = await db.query(
      'SELECT * FROM produtos WHERE nome ILIKE $1 AND ativo = true',
      [`%${nome}%`]
    );
    return result.rows;
  }

  static async create(data: CreateProdutoDTO): Promise<ProdutoDTO> {
    const db = getDb();
    const { nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade } = data;
    const result = await db.query(
      `INSERT INTO produtos (nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6, 10), COALESCE($7, 'unid.')) RETURNING *`,
      [nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade]
    );
    return result.rows[0];
  }

  static async update(id: string, data: Partial<CreateProdutoDTO>): Promise<ProdutoDTO | null> {
    const db = getDb();
    const { nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade } = data;
    const result = await db.query(
      `UPDATE produtos
       SET nome = COALESCE($1, nome),
           marca = COALESCE($2, marca),
           categoria = COALESCE($3, categoria),
           valor = COALESCE($4, valor),
           quantidade_estoque = COALESCE($5, quantidade_estoque),
           min_estoque = COALESCE($6, min_estoque),
           unidade = COALESCE($7, unidade)
       WHERE id = $8 RETURNING *`,
      [nome, marca, categoria, valor, quantidade_estoque, min_estoque, unidade, id]
    );
    return result.rows[0] ?? null;
  }

  // Soft delete: preserva integridade de itens_orcamento_produto com este produto
  static async deactivate(id: string): Promise<ProdutoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'UPDATE produtos SET ativo = false WHERE id = $1 RETURNING *',
      [id]
    );
    return result.rows[0] ?? null;
  }
}

