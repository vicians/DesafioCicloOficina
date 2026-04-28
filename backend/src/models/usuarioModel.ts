import { getDb } from '../config/database';
import type { UsuarioDTO, CreateUsuarioDTO } from '../../../shared/dtos/usuarioDto';

export class UsuarioModel {
  static async findAll(): Promise<UsuarioDTO[]> {
    const db = getDb();
    const result = await db.query('SELECT id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em FROM usuarios');
    return result.rows;
  }

  static async findById(id: string): Promise<UsuarioDTO | undefined> {
    const db = getDb();
    const result = await db.query(
      'SELECT id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em FROM usuarios WHERE id = $1',
      [id]
    );
    return result.rows[0];
  }

  static async findByTelefone(telefone: string): Promise<UsuarioDTO | undefined> {
    const db = getDb();
    const result = await db.query(
      'SELECT id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em FROM usuarios WHERE telefone = $1',
      [telefone]
    );
    return result.rows[0];
  }

  static async findByCpfCnpj(cpf_cnpj: string): Promise<UsuarioDTO | undefined> {
    const db = getDb();
    const result = await db.query(
      'SELECT id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em FROM usuarios WHERE cpf_cnpj = $1',
      [cpf_cnpj]
    );
    return result.rows[0];
  }

  static async findByEmail(email: string): Promise<UsuarioDTO | undefined> {
    const db = getDb();
    const result = await db.query(
      'SELECT id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em FROM usuarios WHERE email = $1',
      [email]
    );
    return result.rows[0];
  }

  static async create(data: CreateUsuarioDTO): Promise<UsuarioDTO> {
    const db = getDb();
    const { tipo_id, cpf_cnpj, nome, telefone, email, senha_hash } = data;
    const result = await db.query(
      `INSERT INTO usuarios (tipo_id, cpf_cnpj, nome, telefone, email, senha_hash) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em`,
      [tipo_id, cpf_cnpj, nome, telefone, email, senha_hash]
    );
    return result.rows[0];
  }
}
