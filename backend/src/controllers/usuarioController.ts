import { Request, Response } from 'express';
import { UsuarioModel } from '../models/usuarioModel';

export class UsuarioController {
  static async index(req: Request, res: Response) {
    const usuarios = await UsuarioModel.findAll();
    return res.json(usuarios);
  }

  static async show(req: Request, res: Response) {
    const { id } = req.params;
    const usuario = await UsuarioModel.findById(id);

    if (!usuario) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    return res.json(usuario);
  }

  static async showByCpf(req: Request, res: Response) {
    const { cpf } = req.params;
    const usuario = await UsuarioModel.findByCpfCnpj(cpf);

    if (!usuario) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    return res.json(usuario);
  }

  static async store(req: Request, res: Response) {
    const data = req.body;

    if (!data.nome || !data.cpf_cnpj || !data.email) {
      return res.status(400).json({ error: 'Nome, CPF/CNPJ e E-mail são obrigatórios' });
    }

    // Validação de CPF/CNPJ Único
    const cpfExistente = await UsuarioModel.findByCpfCnpj(data.cpf_cnpj);
    if (cpfExistente) {
      return res.status(400).json({ error: 'CPF/CNPJ já cadastrado' });
    }

    // Validação de E-mail Único
    const emailExistente = await UsuarioModel.findByEmail(data.email);
    if (emailExistente) {
      return res.status(400).json({ error: 'E-mail já cadastrado' });
    }

    const usuario = await UsuarioModel.create(data);
    return res.status(201).json(usuario);
  }
}
