import { getDb } from '../config/database';
import type { VeiculoDTO, CreateVeiculoDTO } from '../../../shared/dtos/veiculoDto';

export class VeiculoModel {
  static async findAll(): Promise<VeiculoDTO[]> {
    const db = getDb();
    const result = await db.query(
      'SELECT v.*, u.nome AS nome_cliente FROM veiculos v JOIN usuarios u ON v.cliente_id = u.id ORDER BY v.criado_em DESC'
    );
    return result.rows;
  }

  /**
   * Busca combinada por placa (ILIKE parcial) e/ou nome do dono (ILIKE via JOIN).
   * Sem filtros retorna todos — o controller decide quando chamar findAll vs findWithFilters.
   */
  static async findWithFilters(filters: {
    placa?: string;
    nome_cliente?: string;
  }): Promise<VeiculoDTO[]> {
    const db = getDb();
    const conditions: string[] = [];
    const values: string[] = [];

    if (filters.placa) {
      values.push(`%${filters.placa}%`);
      conditions.push(`v.placa ILIKE $${values.length}`);
    }
    if (filters.nome_cliente) {
      values.push(`%${filters.nome_cliente}%`);
      conditions.push(`u.nome ILIKE $${values.length}`);
    }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const result = await db.query(
      `SELECT v.*, u.nome AS nome_cliente
       FROM veiculos v
       JOIN usuarios u ON v.cliente_id = u.id
       ${where}
       ORDER BY v.criado_em DESC`,
      values
    );
    return result.rows;
  }

  static async findById(id: string): Promise<VeiculoDTO | null> {
    const db = getDb();
    const result = await db.query(
      'SELECT v.*, u.nome AS nome_cliente FROM veiculos v JOIN usuarios u ON v.cliente_id = u.id WHERE v.id = $1',
      [id]
    );
    return result.rows[0] ?? null;
  }

  static async findByPlaca(placa: string): Promise<VeiculoDTO | null> {
    const db = getDb();
    const result = await db.query('SELECT * FROM veiculos WHERE placa = $1', [placa]);
    return result.rows[0] ?? null;
  }

  static async findByClienteId(clienteId: string): Promise<VeiculoDTO[]> {
    const db = getDb();
    const result = await db.query(
      'SELECT v.*, u.nome AS nome_cliente FROM veiculos v JOIN usuarios u ON v.cliente_id = u.id WHERE v.cliente_id = $1 ORDER BY v.criado_em DESC',
      [clienteId]
    );
    return result.rows;
  }

  static async create(data: CreateVeiculoDTO): Promise<VeiculoDTO> {
    const db = getDb();
    const { cliente_id, placa, marca, modelo, ano, quilometragem_atual } = data;
    const result = await db.query(
      `INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano, quilometragem_atual) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [cliente_id, placa, marca, modelo, ano, quilometragem_atual]
    );
    return result.rows[0];
  }
}
