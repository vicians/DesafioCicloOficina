import { getDb } from '../config/database';
import type { CatalogoServicoDTO, CreateCatalogoServicoDTO } from '../../../shared/dtos/catalogoServicoDto';

export class CatalogoServicoModel {
  static async findAll(): Promise<CatalogoServicoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM catalogo_servicos WHERE ativo = true');
    return result.rows;
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
}
