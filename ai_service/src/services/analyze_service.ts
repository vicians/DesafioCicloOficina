import { prisma } from '../config/prisma';
import { model } from '../config/ai_model';
import { getTools } from '../tools';
import { HumanMessage, SystemMessage, ToolMessage, BaseMessage } from '@langchain/core/messages';

import dotenv from 'dotenv';
dotenv.config();

const MAX_ITERATIONS = 4;

/**
 * Serviço principal de análise de mensagens.
 * Agora opera como um Agente Autônomo com suporte a múltiplas rodadas de ferramentas (Multi-turn).
 * O RAG foi desacoplado e agora é acionado sob demanda via 'catalog_search_tool'.
 */
export async function analyzeMessage(message: string, number: string) {
  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

  // 1. Identificar status do cliente e verificar se está em atendimento humano
  const customer = await prisma.usuarios.findUnique({
    where: { telefone: number },
  });

  if (customer && customer.tipo_id !== 2) {
    return {
      result: null,
      action: 'MANUAL_WAIT',
      info: 'O atendimento está sendo realizado por um humano.',
    };
  }

  // 2. Configurar Agente e Ferramentas
  const tools = getTools(number);
  const modelWithTools = model.bindTools(tools);

  const messages: BaseMessage[] = [
    new SystemMessage(`És o assistente virtual da CicloOficina.
Objetivos:
1. Ajudar clientes com informações sobre produtos, preços e serviços.
2. Facilitar agendamentos e consultas de disponibilidade.

Regras Cruciais:
- Você NÃO tem conhecimento prévio de preços, estoque ou serviços.
- USE SEMPRE a ferramenta 'catalog_search_tool' para buscar qualquer informação do catálogo.
- Nunca invente preços ou prazos. Informe apenas o que for retornado pelas ferramentas.
- Se o cliente quiser agendar, use 'create_appointment'.
- Se identificar um serviço específico no catálogo, passe-o no parâmetro 'services' do agendamento.
- Você pode usar múltiplas ferramentas em sequência se necessário (ex: pesquisar preço e depois agendar).
- Responda de forma cordial e profissional em Português (Brasil).`),
    new HumanMessage(message)
  ];

  // 3. Loop de Execução do Agente (Reasoning Loop)
  console.log(`[AI Service] 🤖 Iniciando raciocínio do agente...`);
  
  let iterations = 0;
  let finalResponse: any = null;

  while (iterations < MAX_ITERATIONS) {
    iterations++;
    const response = await modelWithTools.invoke(messages);
    
    // Se não houver chamadas de ferramentas, o agente terminou de pensar
    if (!response.tool_calls || response.tool_calls.length === 0) {
      finalResponse = response;
      break;
    }

    // Adiciona a intenção da IA ao histórico de mensagens
    messages.push(response);

    // Processa cada chamada de ferramenta solicitada pelo modelo
    for (const toolCall of response.tool_calls) {
      const tool = tools.find(t => t.name === toolCall.name);
      if (tool) {
        console.log(`[AI Service] 🛠️ [Turno ${iterations}] Executando ferramenta: ${toolCall.name}`);
        try {
          const toolResult = await (tool as any).call(toolCall.args);
          messages.push(new ToolMessage({
            tool_call_id: toolCall.id!,
            content: typeof toolResult === 'string' ? toolResult : JSON.stringify(toolResult)
          }));
        } catch (error) {
          console.error(`[AI Service] ❌ Erro na ferramenta ${toolCall.name}:`, error);
          messages.push(new ToolMessage({
            tool_call_id: toolCall.id!,
            content: `Erro técnico ao executar a ferramenta. Por favor, tente novamente.`
          }));
        }
      }
    }
  }

  // Fallback se o loop atingir o limite sem uma resposta final (raro)
  const finalContent = String(finalResponse?.content || "Desculpe, tive um problema ao processar sua solicitação no momento. Posso tentar novamente?").trim();
  
  return { 
    result: finalContent, 
    action: 'REPLY' 
  };
}