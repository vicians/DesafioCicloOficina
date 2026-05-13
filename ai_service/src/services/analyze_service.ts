import { prisma } from '../config/prisma';
import { model } from '../config/ai_model';
import { getTools } from '../tools';
import { HumanMessage, SystemMessage, ToolMessage, BaseMessage } from '@langchain/core/messages';

import dotenv from 'dotenv';
dotenv.config();

const MAX_ITERATIONS = 4;

function parseJsonText(content: string): unknown | null {
  try {
    return JSON.parse(content);
  } catch {
    return null;
  }
}

function normalizeAssistantReply(content: string): string {
  const trimmed = content.trim();

  if (!trimmed) {
    return 'Não consegui concluir a solicitação agora. Pode reformular a mensagem?';
  }

  const parsed = parseJsonText(trimmed);
  if (!parsed || typeof parsed !== 'object') {
    return trimmed;
  }

  const data = parsed as Record<string, unknown>;

  if (typeof data.result === 'string' && data.result.trim()) {
    return data.result.trim();
  }

  if (typeof data.message === 'string' && data.message.trim()) {
    return data.message.trim();
  }

  if (data.ok === false && typeof data.error === 'string') {
    return `Não consegui concluir a ação no sistema: ${data.error}`;
  }

  if (
    typeof data.agendamento_id === 'string' &&
    typeof data.orcamento_id === 'string'
  ) {
    const dateText = typeof data.agendado_para === 'string'
      ? ` para ${new Date(data.agendado_para).toLocaleString('pt-BR')}`
      : '';
    const magicLinkText = typeof data.magic_link_url === 'string' && data.magic_link_url
      ? ` Acompanhe pelo link: ${data.magic_link_url}`
      : '';

    return `Agendamento e orçamento criados com sucesso${dateText}.${magicLinkText}`.trim();
  }

  return trimmed;
}

export async function analyzeMessage(message: string, number: string) {
  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

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

  const tools = getTools(number, message);
  const modelWithTools = model.bindTools(tools);

  const messages: BaseMessage[] = [
    new SystemMessage(`És o assistente virtual da CicloOficina.
Objetivos:
1. Ajudar clientes com informações sobre produtos, preços e serviços.
2. Identificar serviços desejados no catálogo e usá-los ao criar agendamentos.
3. Facilitar agendamentos e consultas de disponibilidade.

Regras:
- Você NÃO tem conhecimento prévio de preços, estoque ou serviços.
- USE SEMPRE a ferramenta 'catalog_search_tool' para buscar qualquer informação do catálogo.
- Se o cliente quiser agendar, use 'create_appointment'. Use 'backend_api' quando precisar consultar ou registrar dados adicionais no backend.
- Se identificar um serviço específico no catálogo (ex: Troca de óleo), passe-o no parâmetro 'services' do agendamento.
- Nunca invente preços ou prazos. Informe apenas o que for retornado pelas ferramentas.
- Quando uma ferramenta retornar dados estruturados, use esses dados para redigir a resposta final. Nunca devolva JSON cru ao cliente.
- Se faltarem dados obrigatórios para executar uma ação, peça somente os dados faltantes.
- Você pode usar múltiplas ferramentas em sequência se necessário (ex: pesquisar preço e depois agendar).
- Responda sempre em português (Brasil), de forma cordial e profissional.`),
    new HumanMessage(message)
  ];

  console.log(`[AI Service] 🤖 Iniciando raciocínio do agente...`);

  let iterations = 0;
  let finalResponse: any = null;

  while (iterations < MAX_ITERATIONS) {
    iterations++;
    const response = await modelWithTools.invoke(messages);

    if (!response.tool_calls || response.tool_calls.length === 0) {
      finalResponse = response;
      break;
    }

    messages.push(response);

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

  const finalContent = normalizeAssistantReply(
    String(finalResponse?.content || 'Desculpe, tive um problema ao processar sua solicitação no momento. Posso tentar novamente?')
  );

  return {
    result: finalContent,
    action: 'REPLY'
  };
}
