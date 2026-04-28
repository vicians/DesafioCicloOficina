import { getDb } from '../config/database';
import type { VeiculoDTO, CreateVeiculoDTO } from '../../../shared/dtos/veiculoDto';

export class VeiculoModel {
  static async findAll(): Promise<VeiculoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM veiculos');
    return result.rows;
  }

  static async findById(id: string): Promise<VeiculoDTO | undefined> {
    const db = getDb();
    const result = await db.query('SELECT * FROM veiculos WHERE id = $1', [id]);
    return result.rows[0];
  }

  static async findByPlaca(placa: string): Promise<VeiculoDTO | undefined> {
    const db = getDb();
    const result = await db.query('SELECT * FROM veiculos WHERE placa = $1', [placa]);
    return result.rows[0];
  }

  static async findByClienteId(clienteId: string): Promise<VeiculoDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT * FROM veiculos WHERE cliente_id = $1', [clienteId]);
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
