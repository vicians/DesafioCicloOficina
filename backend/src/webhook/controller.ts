import { Request, Response } from 'express';
import axios from 'axios';
import { UsuarioModel } from '../models/usuarioModel';
import { ConversationModel } from '../models/conversationModel';
import { PasswordUtils } from '../utils/passwordUtils';

// Configurações extraídas do seu .env
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:3001';
const WA_ACCESS_TOKEN = process.env.WA_ACCESS_TOKEN;
const WA_PHONE_NUMBER_ID = process.env.WA_PHONE_NUMBER_ID;
const MESSAGE_ID_TTL_MS = 5 * 60 * 1000;

const recentMessageIds = new Map<string, ReturnType<typeof setTimeout>>();

const messageBuffer = new Map<string, string[]>();
const debounceTimers = new Map<string, NodeJS.Timeout>();

const trackMessageId = (messageId: string): boolean => {
  if (recentMessageIds.has(messageId)) {
    return false;
  }

  const timeout = setTimeout(() => {
    recentMessageIds.delete(messageId);
  }, MESSAGE_ID_TTL_MS);

  timeout.unref?.();
  recentMessageIds.set(messageId, timeout);
  return true;
};

/**
 * Envia uma mensagem de texto de volta para o usuário via API da Meta
 */
export const sendWhatsAppMessage = async (to: string, text: string) => {
  try {
    await axios.post(
      `https://graph.facebook.com/v21.0/${WA_PHONE_NUMBER_ID}/messages`,
      {
        messaging_product: "whatsapp",
        to: to,
        type: "text",
        text: { body: text },
      },
      {
        headers: {
          Authorization: `Bearer ${WA_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
      }
    );
    console.log(`[WhatsApp] Mensagem enviada para ${to}`);
  } catch (error: any) {
    console.error('[WhatsApp] Erro ao enviar mensagem:', error.response?.data || error.message);
  }
};

/**
 * Ativa o balão de "está digitando..." e marca a mensagem como lida na API da Meta
 */
export const send_whatsapp_typing = async (message_id: string): Promise<void> => {
  try {
    await axios.post(
      `https://graph.facebook.com/v21.0/${WA_PHONE_NUMBER_ID}/messages`,
      {
        messaging_product: "whatsapp",
        status: "read",
        message_id: message_id,
        typing_indicator: {
          type: "text"
        }
      },
      {
        headers: {
          Authorization: `Bearer ${WA_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
      }
    );
    console.log(`[WhatsApp] Indicador de digitação ativado para a mensagem ${message_id}`);
  } catch (error: any) {
    console.error('[WhatsApp] Erro ao enviar indicador de digitação:', error.response?.data || error.message);
  }
};

/**
 * Processa mensagens no buffer após debounce
 */
const processBufferedMessages = async (customerNumber: string, conversacaoId: string, clienteId: string, message_id?: string) => {
  const messages = messageBuffer.get(customerNumber) || [];
  if (messages.length === 0) return;

  const combinedText = messages.join('\n');
  
  // Limpa os buffers
  messageBuffer.delete(customerNumber);
  debounceTimers.delete(customerNumber);

  console.log(`[Webhook] Processando lote de mensagens para ${customerNumber}:\n${combinedText}`);

  // Envia o indicador visual de digitação nativo imediatamente
  if (message_id) {
    send_whatsapp_typing(message_id).catch((err) => {
      console.error('[Webhook] Falha ao acionar indicador de digitação:', err.message);
    });
  }

  let is_ai_done = false;
  // 1. Timeout de Fallback: Envia mensagem física se a resposta da IA demorar mais de 25 segundos
  const processando_timeout = setTimeout(async () => {
    if (!is_ai_done) {
      await sendWhatsAppMessage(customerNumber, "Estou processando sua solicitação, só um instante... ⚙️");
    }
  }, 25000);

  try {
    const aiResponse = await axios.post(`${AI_SERVICE_URL}/ai/analyze`, {
      message: combinedText,
      number: customerNumber,
      conversacaoId,
    });

    is_ai_done = true;
    clearTimeout(processando_timeout);

    const { action, result, demand } = aiResponse.data;

    if (action === 'REPLY') {
      await sendWhatsAppMessage(customerNumber, result);
      if (conversacaoId) {
        await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', result);
      }
      const magicLinkUrl = aiResponse.data.magic_link_url;
      if (magicLinkUrl) {
        await sendWhatsAppMessage(customerNumber, magicLinkUrl);
        if (conversacaoId) {
          await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', magicLinkUrl);
        }
      }

    } else if (action === 'CREATE_OS') {
      console.log(`[Webhook] Solicitando criação de OS para ${customerNumber}...`);

      try {
        const osResponse = await axios.post(`${AI_SERVICE_URL}/ai/create-os`, demand);
        const { message: osMsg, magic_link_url: magicLinkUrl } = osResponse.data;

        await sendWhatsAppMessage(customerNumber, osMsg);
        if (conversacaoId) {
          await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', osMsg);
        }

        if (magicLinkUrl) {
          await sendWhatsAppMessage(customerNumber, magicLinkUrl);
          if (conversacaoId) {
            await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', magicLinkUrl);
          }
        }
      } catch (osErr: any) {
        console.error('[Webhook] Erro ao criar OS no ai_service:', osErr.response?.data ?? osErr.message);
        const errMsg = "Ops, tive um problema ao gerar sua Ordem de Serviço. Tente novamente em instantes.";
        await sendWhatsAppMessage(customerNumber, errMsg);
        if (conversacaoId) {
          await ConversationModel.addMessage(conversacaoId, clienteId, 'system', errMsg);
        }
      }

    } else if (action === 'MANUAL_WAIT') {
      console.log(`[Webhook] Atendimento manual para ${customerNumber}`);
      const waitMsg = "Entendido. Vou passar seu caso para um de nossos mecânicos. Um momento, por favor!";
      await sendWhatsAppMessage(customerNumber, waitMsg);
      
      if (conversacaoId) {
        await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', waitMsg);
        await ConversationModel.updateHandoff(conversacaoId, true); // Automatic handoff triggered by bot
      }
    }

  } catch (error: any) {
    is_ai_done = true;
    clearTimeout(processando_timeout);
    console.error('[Webhook] Erro na comunicação com AI_SERVICE:', error.message);
  }
};

/**
 * Valida o Webhook no painel da Meta (GET)
 */
export const validateWebhook = (req: Request, res: Response) => {
  const VERIFY_TOKEN = process.env.VERIFY_TOKEN;
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    console.log('✅ WEBHOOK_VERIFIED');
    return res.status(200).send(challenge);
  }
  return res.sendStatus(403);
};

/**
 * Processa as mensagens recebidas (POST)
 */
export const handleMessage = async (req: Request, res: Response) => {
  const body = req.body;

  // Verifica se o objeto é da conta do WhatsApp
  if (body.object !== 'whatsapp_business_account') {
    return res.sendStatus(404);
  }

  const message = body.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
  const message_id: string | undefined = message?.id;

  if (message_id && !trackMessageId(message_id)) {
    console.log(`[Webhook] Dropped duplicate message ID: ${message_id}`);
    return res.sendStatus(200);
  }

  // Ignora se não houver mensagem de texto
  if (!message?.text?.body) {
    return res.sendStatus(200);
  }

  const customerText: string = message.text.body;
  const customerNumber: string = message.from;

  try {
    console.log(`[Webhook] Recebido de ${customerNumber}: ${customerText}`);

    // Híbrido: Verifica se o cliente existe para registrar a conversa
    let cliente = await UsuarioModel.findByTelefone(customerNumber);
    
    if (!cliente) {
      console.log(`[Webhook] Cliente não encontrado para o número ${customerNumber}. Criando novo cliente on-the-fly...`);
      const defaultPassword = await PasswordUtils.hash('whatsapp_client_123');
      cliente = await UsuarioModel.create({
        tipo_id: 2,
        cpf_cnpj: customerNumber,
        nome: 'New Client (WhatsApp)',
        telefone: customerNumber,
        senha_hash: defaultPassword,
      });
      console.log(`[Webhook] Novo cliente criado on-the-fly com ID: ${cliente.id}`);
    }

    const conversacao = await ConversationModel.findOrCreateByClienteId(cliente.id);
    const conversacaoId: string = conversacao.id;
    const iaPausada = conversacao.ia_pausada;

    // Guaranteed Persistence: Salva a mensagem recebida do cliente antes do processamento da IA
    await ConversationModel.addMessage(conversacaoId, cliente.id, 'client', customerText);

    if (iaPausada) {
      console.log(`[Webhook] IA pausada para ${customerNumber}. Mensagem registrada. Aguardando atendente.`);
      return res.sendStatus(200);
    }

    // Buffer the message
    if (!messageBuffer.has(customerNumber)) {
      messageBuffer.set(customerNumber, []);
    }
    messageBuffer.get(customerNumber)!.push(customerText);

    // Debounce timer
    if (debounceTimers.has(customerNumber)) {
      clearTimeout(debounceTimers.get(customerNumber)!);
    }

    const timer = setTimeout(() => {
      processBufferedMessages(customerNumber, conversacaoId, cliente.id, message_id);
    }, 4500);

    debounceTimers.set(customerNumber, timer);

  } catch (error: any) {
    console.error('[Webhook] Erro no processamento principal:', error.message);
  }

  // Sempre retorna 200 para a Meta não reenviar a mesma mensagem
  return res.sendStatus(200);
};
