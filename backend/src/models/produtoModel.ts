import { getDb } from '../config/database';
import type { ProdutoDTO, CreateProdutoDTO } from '../../../shared/dtos/produtoDto';

export class ProdutoModel {
  static async findAll(): Promise<ProdutoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM produtos WHERE ativo = true');
    return result.rows;
  }

  static async create(data: CreateProdutoDTO): Promise<ProdutoDTO> {
    const db = getDb();
    const { nome, marca, valor, quantidade_estoque } = data;
    const result = await db.query(
      `INSERT INTO produtos (nome, marca, valor, quantidade_estoque) 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [nome, marca, valor, quantidade_estoque]
    );
    return result.rows[0];
  }
}
