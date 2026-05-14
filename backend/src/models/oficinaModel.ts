import { getDb } from '../config/database';
import type { OficinaDTO, CreateOficinaDTO } from '../../../shared/dtos/oficinaDto';

export class OficinaModel {
  static async findAll(): Promise<OficinaDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM oficinas ORDER BY nome');
    return result.rows;
  }

  static async findById(id: string): Promise<OficinaDTO | undefined> {
    const db = getDb();
    const result = await db.query('SELECT * FROM oficinas WHERE id = $1', [id]);
    return result.rows[0];
  }

  static async create(data: CreateOficinaDTO): Promise<OficinaDTO> {
    const db = getDb();
    const { nome, quantidade_boxes } = data;
    const result = await db.query(
      'INSERT INTO oficinas (nome, quantidade_boxes) VALUES ($1, $2) RETURNING *',
      [nome, quantidade_boxes]
    );
    return result.rows[0];
  }

  static async update(id: string, data: Partial<CreateOficinaDTO>): Promise<OficinaDTO | undefined> {
    const db = getDb();
    const fields: string[] = [];
    const values: any[] = [];
    let i = 1;

    if (data.nome !== undefined) {
      fields.push(`nome = $${i++}`);
      values.push(data.nome);
    }
    if (data.quantidade_boxes !== undefined) {
      fields.push(`quantidade_boxes = $${i++}`);
      values.push(data.quantidade_boxes);
    }

    if (fields.length === 0) return this.findById(id);

    values.push(id);
    const result = await db.query(
      `UPDATE oficinas SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      values
    );
    return result.rows[0];
  }
}
