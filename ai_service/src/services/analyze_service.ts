import { prisma } from '../config/prisma';
import { chat_model } from '../config/ai_model';
import { queryProdutos } from '../vectorstore/productVectorStore';
import dotenv from 'dotenv';

dotenv.config();

export async function analyzeMessage(message: string, number: string) {
  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

  // 1. Identificar se o atendimento deve ser humano ou bot
  console.log(`[AI Service] 🔍 Verificando status do cliente no banco...`);
  let customer = await prisma.usuarios.findUnique({
    where: { telefone: number },
  });

  // Se não for cliente (tipo_id: 2), tratamos como manual para evitar conflito com funcionários/admins
  if (customer && customer.tipo_id !== 2) {
    console.log(`[AI Service] 👤 Usuário não é cliente (Tipo: ${customer.tipo_id}). Encaminhando para humano.`);
    return {
      result: null,
      action: 'MANUAL_WAIT',
      info: 'O atendimento está sendo realizado por um humano.',
    };
  }

  // 2. Consultar base de produtos (RAG)
  console.log(`[AI Service] 📚 Consultando base de produtos (RAG)...`);
  const ragDocs = await queryProdutos(message);
  const contextBlock =
    ragDocs.length > 0
      ? `\n\nProdutos e preços disponíveis na oficina:\n${ragDocs.map((d) => `- ${d}`).join('\n')}`
      : '';

  // 3. Chamar o Modelo de IA
  console.log(`[AI Service] 🤖 Chamando NVIDIA NIM...`);
  const response = await chat_model.invoke([
    ['system', `És o assistente virtual da CicloOficina.
Objetivos:
1. Identificar se o cliente quer agendar um serviço de Borracharia ou Mecânica.
2. Fornecer informações de preços e produtos baseando-se no contexto abaixo.
3. Para agendamentos, responda EXATAMENTE no formato JSON: {"action":"CREATE_OS","customerName":"<nome>","vehiclePlate":"<placa>","description":"<problema>","serviceType":"<serviço>"}

Regras:
- Se não for um agendamento, responda cordialmente em texto puro.
- Nunca invente preços. Se não estiver no contexto, diga que o consultor informará.
${contextBlock}`],
    ['user', message],
  ]);

  const content = String(response.content).trim();

  // 4. Tenta parsear se a IA retornou um comando de ação
  try {
    const parsed = JSON.parse(content);
    if (parsed.action === 'CREATE_OS') {
      console.log(`[AI Service] 🛠️ Ação identificada: Criar Ordem de Serviço.`);
      return {
        result: 'Identifiquei que você precisa de um agendamento. Estou gerando sua Ordem de Serviço...',
        action: 'CREATE_OS',
        demand: {
          number,
          customerName: parsed.customerName,
          vehiclePlate: parsed.vehiclePlate,
          description: parsed.description,
          serviceType: parsed.serviceType,
        },
      };
    }
  } catch {
    // Não é JSON — resposta textual normal
  }

  return { result: content, action: 'REPLY' };
}