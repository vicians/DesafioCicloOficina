import { Request, Response } from 'express';
import axios from 'axios';

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:3001';

export const validateWebhook = (req: Request, res: Response) => {
  const VERIFY_TOKEN = process.env.VERIFY_TOKEN;
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    return res.status(200).send(challenge);
  }
  return res.sendStatus(403);
};

export const handleMessage = async (req: Request, res: Response) => {
  const body = req.body;

  if (body.object !== 'whatsapp_business_account') {
    return res.sendStatus(404);
  }

  const message = body.entry?.[0]?.changes?.[0]?.value?.messages?.[0];

  if (!message?.text?.body) {
    return res.sendStatus(200);
  }

  const customerText: string = message.text.body;
  const customerNumber: string = message.from;

  try {
    const aiResponse = await axios.post(`${AI_SERVICE_URL}/ai/analyze`, {
      message: customerText,
      number: customerNumber,
    });

    const { action, demand } = aiResponse.data;

    if (action === 'REPLY') {
      console.log(`[Webhook] Bot → ${customerNumber}:`, aiResponse.data.result);
      // TODO: enviar aiResponse.data.result via API do WhatsApp Business
    } else if (action === 'CREATE_OS') {
      console.log(`[Webhook] Criando OS para ${customerNumber}...`);

      try {
        const osResponse = await axios.post(`${AI_SERVICE_URL}/ai/create-os`, demand);
        const { message: osMsg, magic_link_url } = osResponse.data;

        console.log(`[Webhook] OS criada com sucesso.`);
        console.log(`[Webhook] Magic link: ${magic_link_url}`);

        // TODO: enviar osMsg via API do WhatsApp Business
        // Ex: "OS criada! Acesse o app pelo link: <magic_link_url>"
        console.log(`[Webhook] Mensagem para cliente: ${osMsg}`);
      } catch (osErr: any) {
        console.error('[Webhook] Erro ao criar OS:', osErr.response?.data ?? osErr.message);
      }
    } else if (action === 'MANUAL_WAIT') {
      console.log(`[Webhook] Atendimento manual ativo para ${customerNumber}`);
    }
  } catch (error) {
    console.error('[Webhook] Erro na comunicação com AI_SERVICE:', error);
  }

  return res.sendStatus(200);
};
