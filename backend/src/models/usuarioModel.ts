import { getDb } from '../config/database';
import type { UsuarioDTO, CreateUsuarioDTO } from '../../../shared/dtos/usuarioDto';

// Campos seguros — senha_hash nunca é retornado em queries públicas
const SAFE_COLUMNS = 'id, tipo_id, cpf_cnpj, nome, telefone, email, criado_em';

export class UsuarioModel {
  static async findAll(): Promise<UsuarioDTO[]> {
    const db = getDb();
    const result = await db.query(`SELECT ${SAFE_COLUMNS} FROM usuarios ORDER BY nome ASC`);
    return result.rows;
  }

  /**
   * Filtros opcionais combinados via AND dinâmico.
   * ILIKE em nome para busca parcial case-insensitive.
   * cpf_cnpj e tipo_id são match exato.
   */
  static async findWithFilters(filters: {
    nome?: string;
    cpf_cnpj?: string;
    tipo_id?: number;
  }): Promise<UsuarioDTO[]> {
    const db = getDb();
    const conditions: string[] = [];
    const values: (string | number)[] = [];

    if (filters.nome) {
      values.push(`%${filters.nome}%`);
      conditions.push(`nome ILIKE $${values.length}`);
    }
    if (filters.cpf_cnpj) {
      values.push(filters.cpf_cnpj);
      conditions.push(`cpf_cnpj = $${values.length}`);
    }
    if (filters.tipo_id) {
      values.push(filters.tipo_id);
      conditions.push(`tipo_id = $${values.length}`);
    }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const result = await db.query(
      `SELECT ${SAFE_COLUMNS} FROM usuarios ${where} ORDER BY nome ASC`,
      values
    );
    return result.rows;
  }

  static async findById(id: string): Promise<UsuarioDTO | null> {
    const db = getDb();
    const result = await db.query(
      `SELECT ${SAFE_COLUMNS} FROM usuarios WHERE id = $1`,
      [id]
    );
    return result.rows[0] ?? null;
  }

  static async findByCpfCnpj(cpf_cnpj: string): Promise<UsuarioDTO | null> {
    const db = getDb();
    const result = await db.query(
      `SELECT ${SAFE_COLUMNS} FROM usuarios WHERE cpf_cnpj = $1`,
      [cpf_cnpj]
    );
    return result.rows[0] ?? null;
  }

  static async findByEmail(email: string): Promise<UsuarioDTO | null> {
    const db = getDb();
    const result = await db.query(
      `SELECT ${SAFE_COLUMNS} FROM usuarios WHERE email = $1`,
      [email]
    );
    return result.rows[0] ?? null;
  }

  static async findByTelefone(telefone: string): Promise<UsuarioDTO | null> {
    const db = getDb();
    
    // Normalize input: remove all non-digits
    const cleanPhone = telefone.replace(/\D/g, '');
    
    // Se começar com 55 (DDI do Brasil), cria uma versão sem o 55 para matching flexível
    const withoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;

    const result = await db.query(
      `SELECT ${SAFE_COLUMNS} FROM usuarios 
       WHERE regexp_replace(telefone, '\\D', '', 'g') = $1 
          OR regexp_replace(telefone, '\\D', '', 'g') = $2`,
      [cleanPhone, withoutCountryCode]
    );
    return result.rows[0] ?? null;
  }

  static async create(data: CreateUsuarioDTO): Promise<UsuarioDTO> {
    const db = getDb();
    const { tipo_id, cpf_cnpj, nome, telefone, email, senha_hash } = data;
    const result = await db.query(
      `INSERT INTO usuarios (tipo_id, cpf_cnpj, nome, telefone, email, senha_hash)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING ${SAFE_COLUMNS}`,
      [tipo_id, cpf_cnpj, nome, telefone, email, senha_hash]
    );
    return result.rows[0];
  }

  static async update(
    id: string,
    data: { nome?: string; telefone?: string; email?: string; senha_hash?: string }
  ): Promise<UsuarioDTO | null> {
    const db = getDb();
    const result = await db.query(
      `UPDATE usuarios
       SET nome     = COALESCE($1, nome),
           telefone = COALESCE($2, telefone),
           email    = COALESCE($3, email),
           senha_hash = COALESCE($4, senha_hash)
       WHERE id = $5
       RETURNING ${SAFE_COLUMNS}`,
      [data.nome ?? null, data.telefone ?? null, data.email ?? null, data.senha_hash ?? null, id]
    );
    return result.rows[0] ?? null;
  }
}

