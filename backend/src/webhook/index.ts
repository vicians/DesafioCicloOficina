import { Router } from 'express';

const router = Router();

// Esta é a rota que a Meta acessa para validar o seu webhook
router.get('/', (req, res) => {
    const VERIFY_TOKEN = process.env.VERIFY_TOKEN; // Ele busca do seu .env

    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode && token) {
        if (mode === 'subscribe' && token === VERIFY_TOKEN) {
            console.log('✅ WEBHOOK_VERIFIED');
            return res.status(200).send(challenge); // Retorna apenas o challenge puro
        } else {
            return res.sendStatus(403); // Token errado
        }
    }
});

// Aqui você deve ter a sua rota POST para receber as mensagens reais depois
router.post('/', (req, res) => {
    // Lógica para processar as mensagens da CicloOficina
    res.sendStatus(200);
});

export default router;