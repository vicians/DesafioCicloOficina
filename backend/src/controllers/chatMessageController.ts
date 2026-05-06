import { Request, Response } from 'express';
import { ChatMessageModel } from '../models/chatMessageModel';

const TIPOS_PERMITIDOS = ['client', 'employee', 'system', 'bot'];

export class ChatMessageController {
  static async listByCliente(req: Request, res: Response) {
    const { clienteId } = req.params;
    const mensagens = await ChatMessageModel.findByClienteId(clienteId);
    return res.json(mensagens);
  }

  static async sendByCliente(req: Request, res: Response) {
    const { clienteId } = req.params;
    const { tipo_remetente, conteudo } = req.body;

    if (!conteudo || typeof conteudo !== 'string' || !conteudo.trim()) {
      return res.status(400).json({ error: 'conteudo é obrigatório' });
    }

    const tipo = (tipo_remetente as string | undefined)?.trim().toLowerCase() || 'employee';
    if (!TIPOS_PERMITIDOS.includes(tipo)) {
      return res.status(400).json({
        error: `tipo_remetente inválido. Permitidos: ${TIPOS_PERMITIDOS.join(', ')}`,
      });
    }

    const mensagem = await ChatMessageModel.createByClienteId(clienteId, tipo, conteudo.trim());
    return res.status(201).json(mensagem);
  }
}
