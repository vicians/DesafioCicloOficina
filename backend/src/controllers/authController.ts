import { Request, Response } from 'express';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { getDb } from '../config/database';
import { JWTUtils } from '../utils/JWTUtils';
import { PasswordUtils } from '../utils/passwordUtils';

const TOKEN_TTL_HOURS = 24;

export const generateMagicLink = async (req: Request, res: Response) => {
  const { telefone } = req.body;

  if (!telefone) {
    return res.status(400).json({ error: 'telefone é obrigatório' });
  }

  const db = getDb();

  const userResult = await db.query(
    'SELECT id, nome, email FROM usuarios WHERE telefone = $1',
    [telefone]
  );

  if (userResult.rowCount === 0) {
    return res.status(404).json({ error: 'Usuário não encontrado com este telefone' });
  }

  const user = userResult.rows[0];
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + TOKEN_TTL_HOURS * 60 * 60 * 1000);

  await db.query(
    `INSERT INTO magic_links (usuario_id, token, expires_at)
     VALUES ($1, $2, $3)`,
    [user.id, token, expiresAt]
  );

  const baseUrl = `${process.env.BASE_URL}${process.env.API_PORT}`;
  const url = `${baseUrl}/auth/magic-link/${token}`;

  return res.status(201).json({ token, url, expires_at: expiresAt });
};

export const validateMagicLink = async (req: Request, res: Response) => {
  const { token } = req.params;

  if (!token) {
    return res.status(400).json({ error: 'Token é obrigatório' });
  }

  const db = getDb();

  const linkResult = await db.query(
    `SELECT ml.id, ml.usuario_id, ml.expires_at, ml.used,
            u.email, u.nome, u.tipo_id
     FROM magic_links ml
     JOIN usuarios u ON u.id = ml.usuario_id
     WHERE ml.token = $1`,
    [token]
  );

  if (linkResult.rowCount === 0) {
    return res.status(404).json({ error: 'Link inválido' });
  }

  const link = linkResult.rows[0];

  if (link.used) {
    return res.status(410).json({ error: 'Este link já foi utilizado' });
  }

  if (new Date(link.expires_at) < new Date()) {
    return res.status(410).json({ error: 'Link expirado' });
  }

  await db.query(
    'UPDATE magic_links SET used = true WHERE id = $1',
    [link.id]
  );

  const jwt = JWTUtils.generateToken({
    id: link.usuario_id,
    email: link.email ?? '',
    role: String(link.tipo_id),
  });

  return res.json({ token: jwt, usuario: { id: link.usuario_id, nome: link.nome } });
};

export const login = async (req: Request, res: Response) => {
  const { email, senha } = req.body;

  if (!email || !senha) {
    return res.status(400).json({ error: 'E-mail e senha são obrigatórios' });
  }

  const db = getDb();

  const userResult = await db.query(
    'SELECT id, nome, email, senha_hash, tipo_id FROM usuarios WHERE email = $1',
    [email]
  );

  if (userResult.rowCount === 0) {
    return res.status(401).json({ error: 'E-mail ou senha inválidos' });
  }

  const user = userResult.rows[0];

  const isPasswordValid = await PasswordUtils.compare(senha, user.senha_hash);

  if (!isPasswordValid) {
    return res.status(401).json({ error: 'E-mail ou senha inválidos' });
  }

  const jwt = JWTUtils.generateToken({
    id: user.id,
    email: user.email,
    role: String(user.tipo_id),
  });

  return res.json({
    token: jwt,
    usuario: {
      id: user.id,
      nome: user.nome,
      email: user.email,
      tipo_id: user.tipo_id,
    },
  });
};

export const register = async (req: Request, res: Response) => {
  const { nome, email, senha } = req.body;

  if (!nome || !email || !senha) {
    return res.status(400).json({ error: 'nome, e-mail e senha são obrigatórios' });
  }

  const db = getDb();

  const existing = await db.query('SELECT id FROM usuarios WHERE email = $1', [email]);
  if (existing.rowCount && existing.rowCount > 0) {
    return res.status(409).json({ error: 'E-mail já cadastrado' });
  }

  const senha_hash = await bcrypt.hash(senha, 10);

  const result = await db.query(
    `INSERT INTO usuarios (tipo_id, nome, email, senha_hash)
     VALUES (2, $1, $2, $3)
     RETURNING id, tipo_id, nome, email`,
    [nome, email, senha_hash]
  );

  const usuario = result.rows[0];

  const jwt = JWTUtils.generateToken({
    id: usuario.id,
    email: usuario.email,
    role: String(usuario.tipo_id),
  });

  return res.status(201).json({
    token: jwt,
    usuario: {
      id: usuario.id,
      nome: usuario.nome,
      email: usuario.email,
      tipo_id: usuario.tipo_id,
    },
  });
};
