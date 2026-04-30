import { Request, Response } from 'express';
import axios from 'axios';

export const validateWebhook = (req: Request, res: Response) => {
    const VERIFY_TOKEN = "token_que_voce_inventar"; // Use este mesmo no Meta Dashboard
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === VERIFY_TOKEN) {
        return res.status(200).send(challenge);
    }
    return res.sendStatus(403);
};

// No seu backend/src/webhook/controller.ts
export const handleMessage = async (req: Request, res: Response) => {
    const body = req.body;

    if (body.object === 'whatsapp_business_account') {
        const message = body.entry?.[0]?.changes?.[0]?.value?.messages?.[0];

        if (message?.text?.body) {
            const customerText = message.text.body;
            const customerNumber = message.from;

            try {
                // AJUSTE: Porta 3001 e rota /ai/analyze conforme seu index.ts
                // Dentro da sua função handleMessage no backend
                const aiResponse = await axios.post('http://localhost:3001/ai/analyze', {
                    message: customerText,
                    number: customerNumber // Garante que a IA saiba de quem é a mensagem
                });

                if (aiResponse.data.action === 'REPLY') {
                    console.log("Resposta enviada pelo Bot:", aiResponse.data.result);
                    // Lógica para chamar a API do WhatsApp e enviar o texto real
                } else if (aiResponse.data.action === 'MANUAL_WAIT') {
                    console.log("Ignorando mensagem: Atendimento manual ativo para", customerNumber);
                }

                // Aqui você enviaria o aiResponse.data.result de volta para o WhatsApp
            } catch (error) {
                console.error("Erro na comunicação com AI_SERVICE:", error);
            }
        }
        return res.sendStatus(200);
    }
    return res.sendStatus(404);
};