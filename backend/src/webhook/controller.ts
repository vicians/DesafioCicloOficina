import { Request, Response } from 'express';
import axios from 'axios';

// Configurações extraídas do seu .env[cite: 1]
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:3001';
const WA_ACCESS_TOKEN = process.env.WA_ACCESS_TOKEN;
const WA_PHONE_NUMBER_ID = process.env.WA_PHONE_NUMBER_ID;

/**
 * Envia uma mensagem de texto de volta para o usuário via API da Meta
 */
const sendWhatsAppMessage = async (to: string, text: string) => {
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

  // Verifica se o objeto é da conta do WhatsApp[cite: 1]
  if (body.object !== 'whatsapp_business_account') {
    return res.sendStatus(404);
  }

  const message = body.entry?.[0]?.changes?.[0]?.value?.messages?.[0];

  // Ignora se não houver mensagem de texto
  if (!message?.text?.body) {
    return res.sendStatus(200);
  }

  const customerText: string = message.text.body;
  const customerNumber: string = message.from;

  try {
    console.log(`[Webhook] Recebido de ${customerNumber}: ${customerText}`);

    // 1. Envia a mensagem para o serviço de IA (ai_service)
    const aiResponse = await axios.post(`${AI_SERVICE_URL}/ai/analyze`, {
      message: customerText,
      number: customerNumber,
    });

    const { action, result, demand } = aiResponse.data;

    // 2. Trata a ação decidida pela IA
    if (action === 'REPLY') {
      // Resposta direta do Bot (Pistão)
      await sendWhatsAppMessage(customerNumber, result);

    } else if (action === 'CREATE_OS') {
      console.log(`[Webhook] Solicitando criação de OS para ${customerNumber}...`);

      try {
        // Chama a criação de Ordem de Serviço
        const osResponse = await axios.post(`${AI_SERVICE_URL}/ai/create-os`, demand);
        const { message: osMsg, magic_link_url } = osResponse.data;

        // Monta a mensagem final com o link de acompanhamento
        const finalMsg = `${osMsg}\n\nAcompanhe seu serviço por aqui: ${magic_link_url}`;

        await sendWhatsAppMessage(customerNumber, finalMsg);
      } catch (osErr: any) {
        console.error('[Webhook] Erro ao criar OS no ai_service:', osErr.response?.data ?? osErr.message);
        await sendWhatsAppMessage(customerNumber, "Ops, tive um problema ao gerar sua Ordem de Serviço. Tente novamente em instantes.");
      }

    } else if (action === 'MANUAL_WAIT') {
      console.log(`[Webhook] Atendimento manual para ${customerNumber}`);
      await sendWhatsAppMessage(customerNumber, "Entendido. Vou passar seu caso para um de nossos mecânicos. Um momento, por favor!");
    }

  } catch (error: any) {
    console.error('[Webhook] Erro na comunicação com AI_SERVICE:', error.message);
  }

  // Sempre retorna 200 para a Meta não reenviar a mesma mensagem[cite: 1]
  return res.sendStatus(200);
};