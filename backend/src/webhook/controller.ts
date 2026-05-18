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
    const aiResponse = await axios.post(`${AI_SERVICE_URL}/ai/analyze`, {
      message: customerText,
      number: customerNumber,
      conversacaoId,
    });

    const { action, result, demand } = aiResponse.data;

    // 2. Trata a ação decidida pela IA
    if (action === 'REPLY') {
      const recoveredMsg = isCustomerFacingFailure(result)
        ? await recoverPersistedOsMessage(cliente.id, requestStartedAt)
        : null;
      const replyText = recoveredMsg
        ?? (typeof result === 'string' && result.trim()
          ? result
          : 'Desculpe, tive um problema ao processar sua solicitação no momento. Posso tentar novamente?');

      // Resposta direta do Bot (Pistão)
      await sendWhatsAppMessage(customerNumber, replyText);
      
      if (conversacaoId) {
        await ConversationModel.addMessage(conversacaoId, cliente.id, 'bot', replyText);
      }

    } else if (action === 'CREATE_OS') {
      console.log(`[Webhook] Solicitando criação de OS para ${customerNumber}...`);
      const osCreateStartedAt = new Date();

      try {
        // Chama a criação de Ordem de Serviço
        const osResponse = await axios.post(`${AI_SERVICE_URL}/ai/create-os`, demand);
        const { message: osMsg, magic_link_url } = osResponse.data;

        // Monta a mensagem final com o link de acompanhamento
        const osMsgText = typeof osMsg === 'string' && osMsg.trim()
          ? osMsg.trim()
          : 'Agendamento e orçamento criados com sucesso.';
        const finalMsg = typeof magic_link_url === 'string' && magic_link_url && !osMsgText.includes(magic_link_url)
          ? `${osMsgText}\n\nAcompanhe seu serviço por aqui: ${magic_link_url}`
          : osMsgText;

        await sendWhatsAppMessage(customerNumber, finalMsg);
        
        if (conversacaoId) {
          await ConversationModel.addMessage(conversacaoId, cliente.id, 'bot', finalMsg);
        }
      } catch (osErr: any) {
        console.error('[Webhook] Erro ao criar OS no ai_service:', osErr.response?.data ?? osErr.message);
        const recoveredMsg = await recoverPersistedOsMessage(cliente.id, osCreateStartedAt, demand?.vehiclePlate);

        if (recoveredMsg) {
          await sendWhatsAppMessage(customerNumber, recoveredMsg);
          if (conversacaoId) {
            await ConversationModel.addMessage(conversacaoId, cliente.id, 'bot', recoveredMsg);
          }
          return res.sendStatus(200);
        }

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
    console.error('[Webhook] Erro na comunicação com AI_SERVICE:', error.message);
  }

  // Sempre retorna 200 para a Meta não reenviar a mesma mensagem
  return res.sendStatus(200);
};
