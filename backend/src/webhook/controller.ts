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
  const messageId: string | undefined = message?.id;

  if (messageId && !trackMessageId(messageId)) {
    console.log(`[Webhook] Dropped duplicate message ID: ${messageId}`);
    return res.sendStatus(200);
  }

  // Ignora se não houver mensagem de texto
  if (!message?.text?.body) {
    return res.sendStatus(200);
  }

  const customerText: string = message.text.body;
  const customerNumber: string = message.from;

  let isAiDone = false;
  let processandoTimeout: ReturnType<typeof setTimeout> | undefined;

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

    // 1. Envia a mensagem para o serviço de IA (ai_service) se não estiver pausado
    processandoTimeout = setTimeout(async () => {
      if (!isAiDone && !iaPausada) {
        await sendWhatsAppMessage(customerNumber, "Estou processando sua solicitação, só um instante... ⚙️");
      }
    }, 4000);

    const aiResponse = await axios.post(`${AI_SERVICE_URL}/ai/analyze`, {
      message: customerText,
      number: customerNumber,
      conversacaoId,
    });

    isAiDone = true;
    if (processandoTimeout) clearTimeout(processandoTimeout);

    const { action, result, demand } = aiResponse.data;

    // 2. Trata a ação decidida pela IA
    if (action === 'REPLY') {
      // Resposta direta do Bot (Pistão)
      await sendWhatsAppMessage(customerNumber, result);
      
      if (conversacaoId) {
        await ConversationModel.addMessage(conversacaoId, cliente.id, 'bot', result);
      }

    } else if (action === 'CREATE_OS') {
      console.log(`[Webhook] Solicitando criação de OS para ${customerNumber}...`);

      try {
        // Chama a criação de Ordem de Serviço
        const osResponse = await axios.post(`${AI_SERVICE_URL}/ai/create-os`, demand);
        const { message: osMsg, magic_link_url } = osResponse.data;

        // Monta a mensagem final com o link de acompanhamento
        const finalMsg = `${osMsg}\n\nAcompanhe seu serviço por aqui: ${magic_link_url}`;

        await sendWhatsAppMessage(customerNumber, finalMsg);
        
        if (conversacaoId) {
          await ConversationModel.addMessage(conversacaoId, cliente.id, 'bot', finalMsg);
        }
      } catch (osErr: any) {
        console.error('[Webhook] Erro ao criar OS no ai_service:', osErr.response?.data ?? osErr.message);
        const errMsg = "Ops, tive um problema ao gerar sua Ordem de Serviço. Tente novamente em instantes.";
        await sendWhatsAppMessage(customerNumber, errMsg);
        if (conversacaoId) {
          await ConversationModel.addMessage(conversacaoId, cliente.id, 'system', errMsg);
        }
      }

    } else if (action === 'MANUAL_WAIT') {
      console.log(`[Webhook] Atendimento manual para ${customerNumber}`);
      const waitMsg = "Entendido. Vou passar seu caso para um de nossos mecânicos. Um momento, por favor!";
      await sendWhatsAppMessage(customerNumber, waitMsg);
      
      if (conversacaoId) {
        await ConversationModel.addMessage(conversacaoId, cliente.id, 'bot', waitMsg);
        await ConversationModel.updateHandoff(conversacaoId, true); // Automatic handoff triggered by bot
      }
    }

  } catch (error: any) {
    isAiDone = true;
    if (processandoTimeout) clearTimeout(processandoTimeout);
    console.error('[Webhook] Erro na comunicação com AI_SERVICE:', error.message);
  }

  // Sempre retorna 200 para a Meta não reenviar a mesma mensagem
  return res.sendStatus(200);
};
