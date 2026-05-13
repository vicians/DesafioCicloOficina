import { prisma } from '../config/prisma';
import { model } from '../config/ai_model';
import { queryProdutos } from '../vectorstore/productVectorStore';
import { queryServicos } from '../vectorstore/serviceVectorStore';
import { getTools } from '../tools';
import { HumanMessage, SystemMessage, AIMessage, ToolMessage } from '@langchain/core/messages';

import dotenv from 'dotenv';
dotenv.config();

export async function analyzeMessage(message: string, number: string) {
  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

  // 1. Identificar status do cliente
  let customer = await prisma.usuarios.findUnique({
    where: { telefone: number },
  });

  if (customer && customer.tipo_id !== 2) {
    return {
      result: null,
      action: 'MANUAL_WAIT',
      info: 'O atendimento está sendo realizado por um humano.',
    };
  }

  // 2. Consultar RAG (Produtos + Serviços)
  const [ragProdutos, ragServicos] = await Promise.all([
    queryProdutos(message),
    queryServicos(message)
  ]);

  const contextBlock = `
CATÁLOGO DE PRODUTOS:
${ragProdutos.length > 0 ? ragProdutos.map(d => `- ${d}`).join('\n') : 'Nenhum produto relevante encontrado.'}

CATÁLOGO DE SERVIÇOS:
${ragServicos.length > 0 ? ragServicos.map(d => `- ${d}`).join('\n') : 'Nenhum serviço relevante encontrado.'}
`;

  // 3. Configurar Agent/Tools
  const tools = getTools(number);
  const modelWithTools = model.bindTools(tools);

  const messages: any[] = [
    new SystemMessage(`És o assistente virtual da CicloOficina.
Objetivos:
1. Ajudar clientes com informações sobre produtos, preços e serviços.
2. Identificar serviços desejados no CATÁLOGO DE SERVIÇOS e usá-los ao criar agendamentos.
3. Facilitar agendamentos e consultas de disponibilidade.

Regras:
- Nunca invente preços. Use apenas o que está no contexto.
- Se o cliente quiser agendar, use a ferramenta 'create_appointment'.
- Se identificar um serviço específico do catálogo (ex: Troca de óleo), passe-o no parâmetro 'services'.
- Responda de forma cordial e profissional.

CONTEXTO ATUAL:
${contextBlock}`),
    new HumanMessage(message)
  ];

  // 4. Execução do Loop de IA
  console.log(`[AI Service] 🤖 Processando com NVIDIA NIM e Tools...`);
  let response = await modelWithTools.invoke(messages);

  // Se houver chamadas de ferramentas, executamos
  if (response.tool_calls && response.tool_calls.length > 0) {
    for (const toolCall of response.tool_calls) {
      const tool = tools.find(t => t.name === toolCall.name);
      if (tool) {
        console.log(`[AI Service] 🛠️ Executando ferramenta: ${toolCall.name}`);
        const toolResult = await (tool as any).call(toolCall.args);
        messages.push(response);
        messages.push(new ToolMessage({
          tool_call_id: toolCall.id!,
          content: typeof toolResult === 'string' ? toolResult : JSON.stringify(toolResult)
        }));
      }
    }
    // Segunda chamada para gerar a resposta final com base no resultado da ferramenta
    response = await modelWithTools.invoke(messages);
  }

  const finalContent = String(response.content).trim();
  
  // O retorno segue o padrão esperado pelo frontend/whatsapp
  return { 
    result: finalContent, 
    action: 'REPLY' 
  };
}