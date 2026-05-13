import { Request, Response } from 'express';
import { ConversationModel } from '../models/conversationModel';
import { UsuarioModel } from '../models/usuarioModel';
import { sendWhatsAppMessage } from '../webhook/controller';

export class ConversationController {
  static async list(req: Request, res: Response) {
    try {
      const conversacoes = await ConversationModel.findAll();
      return res.json(conversacoes);
    } catch (error: any) {
      console.error('[ConversationController] list error:', error);
      return res.status(500).json({ error: 'Erro ao listar conversas' });
    }
  }

  static async getMessages(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const mensagens = await ConversationModel.getMessages(id);
      return res.json(mensagens);
    } catch (error: any) {
      console.error('[ConversationController] getMessages error:', error);
      return res.status(500).json({ error: 'Erro ao buscar mensagens' });
    }
  }

  static async sendMessage(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const { conteudo, tipo_remetente } = req.body;

      if (!conteudo || !conteudo.trim()) {
        return res.status(400).json({ error: 'conteudo é obrigatório' });
      }

      // We need to know the cliente_id for the conversation to add the message
      const conversacoes = await ConversationModel.findAll();
      const conversation = conversacoes.find((c: any) => c.id === id);

      if (!conversation) {
        return res.status(404).json({ error: 'Conversa não encontrada' });
      }

      const tipo = tipo_remetente || 'employee';

      const mensagem = await ConversationModel.addMessage(
        id,
        conversation.cliente_id,
        tipo,
        conteudo.trim()
      );

      // If the employee (or system/bot) is sending a message via the dashboard,
      // we need to forward it to WhatsApp if the user has a phone number.
      if (['employee', 'bot', 'system'].includes(tipo)) {
        const cliente = await UsuarioModel.findById(conversation.cliente_id);
        if (cliente && cliente.telefone) {
          await sendWhatsAppMessage(cliente.telefone, conteudo.trim());
        }
      }

      return res.status(201).json(mensagem);
    } catch (error: any) {
      console.error('[ConversationController] sendMessage error:', error);
      return res.status(500).json({ error: 'Erro ao enviar mensagem' });
    }
  }

  static async markAsRead(req: Request, res: Response) {
    try {
      const { id } = req.params;
      await ConversationModel.markAsRead(id);
      return res.sendStatus(204);
    } catch (error: any) {
      console.error('[ConversationController] markAsRead error:', error);
      return res.status(500).json({ error: 'Erro ao marcar como lida' });
    }
  }

  static async toggleHandoff(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const { ia_pausada } = req.body;

      if (typeof ia_pausada !== 'boolean') {
        return res.status(400).json({ error: 'ia_pausada deve ser boolean' });
      }

      const conversacao = await ConversationModel.updateHandoff(id, ia_pausada);
      return res.json(conversacao);
    } catch (error: any) {
      console.error('[ConversationController] toggleHandoff error:', error);
      return res.status(500).json({ error: 'Erro ao atualizar handoff' });
    }
  }
}
