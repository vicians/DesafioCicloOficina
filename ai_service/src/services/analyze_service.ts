import { prisma } from '../config/prisma';
import { model } from '../config/ai_model';
import { queryProdutos } from '../vectorstore/productVectorStore';
import { SYSTEM_PROMPT } from '../prompts/ai_prompts';

export async function analyzeMessage(message: string, number: string) {
  let customer = await prisma.customer.findUnique({
    where: { whatsappNumber: number },
  });

  if (customer?.status === 'HUMAN') {
    return {
      result: null,
      action: 'MANUAL_WAIT',
      info: 'O atendimento está sendo realizado por um humano.',
    };
  }

  const ragDocs = await queryProdutos(message);
  const contextBlock =
    ragDocs.length > 0
      ? `\n\nProdutos e preços disponíveis na oficina:\n${ragDocs.map((d) => `- ${d}`).join('\n')}`
      : '';

  const response = await model.invoke([
    ['system', `${SYSTEM_PROMPT}${contextBlock}`],
    ['user', message],
  ]);

  const content = String(response.content).trim();

  // Tenta parsear se a IA retornou um CREATE_OS
  try {
    const parsed = JSON.parse(content);
    if (parsed.action === 'CREATE_OS') {
      return {
        result: 'Demanda identificada. Criando ordem de serviço...',
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
