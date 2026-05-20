import { Request, Response } from 'express';
import axios from 'axios';
import crypto from 'crypto';
import { UsuarioModel } from '../models/usuarioModel';
import { ConversationModel } from '../models/conversationModel';
import { PasswordUtils } from '../utils/passwordUtils';
import { getDb } from '../config/database';

// Configurações extraídas do seu .env
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:3001';
const WA_ACCESS_TOKEN = process.env.WA_ACCESS_TOKEN;
const WA_PHONE_NUMBER_ID = process.env.WA_PHONE_NUMBER_ID;
const MESSAGE_ID_TTL_MS = 5 * 60 * 1000;
const OS_RECOVERY_LOOKBACK_BUFFER_MS = 5 * 1000;
const MAGIC_LINK_TTL_HOURS = 24;

const recentMessageIds = new Map<string, ReturnType<typeof setTimeout>>();

const messageBuffer = new Map<string, string[]>();
const debounceTimers = new Map<string, NodeJS.Timeout>();

type PersistedOsConfirmation = {
  agendamento_id: string;
  orcamento_id: string;
  agendado_para: Date | string;
  magic_link_url: string;
};

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

const normalizePlate = (value: unknown): string | null => {
  if (typeof value !== 'string' || !value.trim()) {
    return null;
  }

  return value.trim().toUpperCase();
};

const isCustomerFacingFailure = (value: unknown): boolean => {
  if (typeof value !== 'string' || !value.trim()) {
    return true;
  }

  const normalized = value.toLowerCase();
  return (
    normalized.includes('ops, tive um problema') ||
    normalized.includes('desculpe') ||
    normalized.includes('não consegui') ||
    normalized.includes('nao consegui') ||
    normalized.includes('erro técnico') ||
    normalized.includes('erro tecnico') ||
    normalized.includes('problema ao processar') ||
    normalized.includes('tente novamente')
  );
};

const createMagicLinkForCustomer = async (clienteId: string): Promise<string> => {
  const db = getDb();
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + MAGIC_LINK_TTL_HOURS * 60 * 60 * 1000);

  await db.query(
    `INSERT INTO magic_links (usuario_id, token, expires_at)
     VALUES ($1, $2, $3)`,
    [clienteId, token, expiresAt]
  );

  const baseUrl = `${process.env.BASE_URL ?? ''}${process.env.API_PORT ?? ''}`;
  return `${baseUrl}/auth/magic-link/${token}`;
};

const findRecentlyPersistedOs = async (
  clienteId: string,
  startedAt: Date,
  vehiclePlate?: unknown
): Promise<PersistedOsConfirmation | null> => {
  const db = getDb();
  const minCreatedAt = new Date(startedAt.getTime() - OS_RECOVERY_LOOKBACK_BUFFER_MS);
  const values: unknown[] = [clienteId, minCreatedAt];
  const plate = normalizePlate(vehiclePlate);
  const plateCondition = plate
    ? `AND UPPER(v.placa) = $${values.push(plate)}`
    : '';

  const result = await db.query(
    `SELECT
       a.id AS agendamento_id,
       a.agendado_para,
       o.id AS orcamento_id
     FROM agendamentos a
     JOIN orcamentos o ON o.agendamento_id = a.id
     LEFT JOIN veiculos v ON v.id = a.veiculo_id
     WHERE a.cliente_id = $1
       AND a.criado_em >= $2
       AND a.notas_cliente ILIKE '[WhatsApp]%'
       ${plateCondition}
     ORDER BY a.criado_em DESC, o.criado_em DESC
     LIMIT 1`,
    values
  );

  const row = result.rows[0];
  if (!row?.agendamento_id || !row?.orcamento_id || !row?.agendado_para) {
    return null;
  }

  return {
    agendamento_id: row.agendamento_id,
    orcamento_id: row.orcamento_id,
    agendado_para: row.agendado_para,
    magic_link_url: await createMagicLinkForCustomer(clienteId),
  };
};

const buildRecoveredOsMessage = (os: PersistedOsConfirmation): string => {
  const appointmentDate = new Date(os.agendado_para);
  const dateText = Number.isNaN(appointmentDate.getTime())
    ? ''
    : ` para ${appointmentDate.toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })}`;

  return `Agendamento e orçamento criados com sucesso${dateText}.\n\nAcompanhe seu serviço por aqui: ${os.magic_link_url}`;
};

const recoverPersistedOsMessage = async (
  clienteId: string,
  startedAt: Date,
  vehiclePlate?: unknown
): Promise<string | null> => {
  try {
    const os = await findRecentlyPersistedOs(clienteId, startedAt, vehiclePlate);
    if (!os) return null;

    console.warn(`[Webhook] OS persistida recuperada após erro: agendamento ${os.agendamento_id}, orçamento ${os.orcamento_id}`);
    return buildRecoveredOsMessage(os);
  } catch (error: any) {
    console.error('[Webhook] Falha ao verificar OS persistida antes de enviar erro:', error.message);
    return null;
  }
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
const processBufferedMessages = async (
  customerNumber: string,
  conversacaoId: string,
  clienteId: string,
  requestStartedAt: Date,
  message_id?: string
) => {
  const messages = messageBuffer.get(customerNumber) || [];
  if (messages.length === 0) return;

  const combinedText = messages.join('\n');
  
  messageBuffer.delete(customerNumber);
  debounceTimers.delete(customerNumber);

  console.log(`[Webhook] Processando lote de mensagens para ${customerNumber}:\n${combinedText}`);

  if (message_id) {
    send_whatsapp_typing(message_id).catch((err) => {
      console.error('[Webhook] Falha ao acionar indicador de digitação:', err.message);
    });
  }

  let is_ai_done = false;
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
    }, {
      headers: { 'X-Internal-Token': process.env.INTERNAL_AUTH_TOKEN }
    });

    is_ai_done = true;
    clearTimeout(processando_timeout);

    const { action, result, demand } = aiResponse.data;

    if (action === 'REPLY') {
      const recoveredMsg = isCustomerFacingFailure(result)
        ? await recoverPersistedOsMessage(clienteId, requestStartedAt)
        : null;
      const replyText = recoveredMsg
        ?? (typeof result === 'string' && result.trim()
          ? result
          : 'Desculpe, tive um problema ao processar sua solicitação no momento. Posso tentar novamente?');

      await sendWhatsAppMessage(customerNumber, replyText);
      if (conversacaoId) {
        await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', replyText);
      }

      if (!recoveredMsg) {
        const magicLinkUrl = aiResponse.data.magic_link_url;
        if (magicLinkUrl) {
          await sendWhatsAppMessage(customerNumber, magicLinkUrl);
          if (conversacaoId) {
            await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', magicLinkUrl);
          }
        }
      }

    } else if (action === 'CREATE_OS') {
      console.log(`[Webhook] Solicitando criação de OS para ${customerNumber}...`);
      const osCreateStartedAt = new Date();

      try {
        const osResponse = await axios.post(`${AI_SERVICE_URL}/ai/create-os`, demand, {
          headers: { 'X-Internal-Token': process.env.INTERNAL_AUTH_TOKEN }
        });
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
        const recoveredMsg = await recoverPersistedOsMessage(clienteId, osCreateStartedAt, demand?.vehiclePlate);

        if (recoveredMsg) {
          await sendWhatsAppMessage(customerNumber, recoveredMsg);
          if (conversacaoId) {
            await ConversationModel.addMessage(conversacaoId, clienteId, 'bot', recoveredMsg);
          }
          return;
        }

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
        await ConversationModel.updateHandoff(conversacaoId, true);
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
  const requestStartedAt = new Date();

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

  let is_ai_done = false;
  let processando_timeout: ReturnType<typeof setTimeout> | undefined;

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
        nome: '',
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

    // Envia o indicador visual de digitação nativo imediatamente se a IA não estiver pausada
    if (message_id) {
      send_whatsapp_typing(message_id).catch((err) => {
        console.error('[Webhook] Falha ao acionar indicador de digitação:', err.message);
      });
    }

    // 1. Timeout de Fallback: Envia mensagem física se a resposta da IA demorar mais de 25 segundos
    processando_timeout = setTimeout(async () => {
      if (!is_ai_done && !iaPausada) {
        await sendWhatsAppMessage(customerNumber, "Estou processando sua solicitação, só um instante... ⚙️");
      }
    }, 25000);

    const aiResponse = await axios.post(`${AI_SERVICE_URL}/ai/analyze`, {
      message: customerText,
      number: customerNumber,
      conversacaoId,
    });

    is_ai_done = true;
    if (processando_timeout) clearTimeout(processando_timeout);

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
      processBufferedMessages(customerNumber, conversacaoId, cliente.id, requestStartedAt, message_id);
    }, 4500);

    debounceTimers.set(customerNumber, timer);

  } catch (error: any) {
    is_ai_done = true;
    if (processando_timeout) clearTimeout(processando_timeout);
    console.error('[Webhook] Erro na comunicação com AI_SERVICE:', error.message);
  }

  // Sempre retorna 200 para a Meta não reenviar a mesma mensagem
  return res.sendStatus(200);
};
