import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { UsuarioModel } from '../models/usuarioModel';

const BCRYPT_ROUNDS = 10;

export class UsuarioController {
  static async index(req: Request, res: Response) {
    const { nome, cpf_cnpj, tipo_id } = req.query;

    const temFiltro = nome || cpf_cnpj || tipo_id;

    if (temFiltro) {
      const usuarios = await UsuarioModel.findWithFilters({
        nome: nome as string | undefined,
        cpf_cnpj: cpf_cnpj as string | undefined,
        tipo_id: tipo_id ? Number(tipo_id) : undefined,
      });
      return res.json(usuarios);
    }

    const usuarios = await UsuarioModel.findAll();
    return res.json(usuarios);
  }

  static async show(req: Request, res: Response) {
    const usuario = await UsuarioModel.findById(req.params.id);
    if (!usuario) return res.status(404).json({ error: 'Usuário não encontrado' });
    return res.json(usuario);
  }

  static async store(req: Request, res: Response) {
    const { tipo_id, cpf_cnpj, nome, telefone, email, senha } = req.body;

    if (!tipo_id || !cpf_cnpj || !nome || !telefone || !senha) {
      return res.status(400).json({ error: 'tipo_id, cpf_cnpj, nome, telefone e senha são obrigatórios' });
    }

    const [cpfExistente, emailExistente, telefoneExistente] = await Promise.all([
      UsuarioModel.findByCpfCnpj(cpf_cnpj),
      email ? UsuarioModel.findByEmail(email) : Promise.resolve(null),
      UsuarioModel.findByTelefone(telefone),
    ]);

    if (cpfExistente)    return res.status(409).json({ error: 'CPF/CNPJ já cadastrado' });
    if (emailExistente)  return res.status(409).json({ error: 'E-mail já cadastrado' });
    if (telefoneExistente) return res.status(409).json({ error: 'Telefone já cadastrado' });

    const senha_hash = await bcrypt.hash(senha, BCRYPT_ROUNDS);

    const usuario = await UsuarioModel.create({ tipo_id, cpf_cnpj, nome, telefone, email, senha_hash });
    return res.status(201).json(usuario);
  }

  static async update(req: Request, res: Response) {
    const { id } = req.params;
    const { nome, telefone, email, senha } = req.body;

    const usuario = await UsuarioModel.findById(id);
    if (!usuario) return res.status(404).json({ error: 'Usuário não encontrado' });

    // Valida unicidade apenas dos campos que foram enviados e pertencem a outro usuário
    if (email && email !== usuario.email) {
      const emailExistente = await UsuarioModel.findByEmail(email);
      if (emailExistente) return res.status(409).json({ error: 'E-mail já está em uso por outro usuário' });
    }

    if (telefone && telefone !== usuario.telefone) {
      const telefoneExistente = await UsuarioModel.findByTelefone(telefone);
      if (telefoneExistente) return res.status(409).json({ error: 'Telefone já está em uso por outro usuário' });
    }

    // Hash só se uma nova senha foi enviada
    const senha_hash = senha ? await bcrypt.hash(senha, BCRYPT_ROUNDS) : undefined;

    const atualizado = await UsuarioModel.update(id, { nome, telefone, email, senha_hash });
    return res.json(atualizado);
  }
}

