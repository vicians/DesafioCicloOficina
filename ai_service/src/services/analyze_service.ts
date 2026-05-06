import { prisma } from '../config/prisma';
import { chat_model } from '../config/ai_model';
import { queryProdutos } from '../vectorstore/productVectorStore';
import dotenv from 'dotenv';

dotenv.config();

export async function analyzeMessage(message: string, number: string) {
  let customer = await prisma.usuarios.findUnique({
    where: { telefone: number },
  });

  if (!customer || customer.tipo_id !== 2) {
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

  const response = await chat_model.invoke([
    ['system', `${process.env.SYSTEM_PROMPT}${contextBlock}`],
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