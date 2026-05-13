import { getDb } from '../config/database';
import type { CatalogoServicoDTO, CreateCatalogoServicoDTO } from '../../../shared/dtos/catalogoServicoDto';

export class CatalogoServicoModel {
  static async findAll(): Promise<CatalogoServicoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM catalogo_servicos WHERE ativo = true ORDER BY nome ASC');
    return result.rows;
  }

  static async findById(id: string): Promise<CatalogoServicoDTO | null> {
    const db = getDb();
    const result = await db.query('SELECT * FROM catalogo_servicos WHERE id = $1', [id]);
    return result.rows[0] ?? null;
  }

  static async create(data: CreateCatalogoServicoDTO): Promise<CatalogoServicoDTO> {
    const db = getDb();
    const { nome, descricao, preco, duracao_minutos } = data;
    const result = await db.query(
      `INSERT INTO catalogo_servicos (nome, descricao, preco, duracao_minutos)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [nome, descricao, preco, duracao_minutos]
    );
    return result.rows[0];
  }

  static async update(id: string, data: Partial<CreateCatalogoServicoDTO>): Promise<CatalogoServicoDTO | null> {
    const db = getDb();
    const { nome, descricao, preco, duracao_minutos } = data;
    const result = await db.query(
      `UPDATE catalogo_servicos
       SET nome = COALESCE($1, nome),
           descricao = COALESCE($2, descricao),
           preco = COALESCE($3, preco),
           duracao_minutos = COALESCE($4, duracao_minutos)
       WHERE id = $5 RETURNING *`,
      [nome, descricao, preco, duracao_minutos, id]
    );
    return result.rows[0] ?? null;
  }

  // Soft delete: preserva histórico de itens_orcamento_servico que referenciam este serviço
  static async deactivate(id: string): Promise<CatalogoServicoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'UPDATE catalogo_servicos SET ativo = false WHERE id = $1 RETURNING *',
      [id]
    );
    return result.rows[0] ?? null;
  }
}

