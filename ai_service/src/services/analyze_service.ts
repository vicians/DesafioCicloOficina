import { prisma } from '../config/prisma';
import { model } from '../config/ai_model';
import { getTools } from '../tools';
import { OFICINA_TIAO_SYSTEM_PROMPT } from '../guardrails/system_prompt';
import {
  evaluateInputGuardrails,
  sanitizeToolResultForPrompt,
  validateFinalReplyGuardrails,
  validateToolCallGuardrails,
} from '../guardrails/security_guardrails';
import {
  ChatHistoryMessage,
  getRecentConversationMessages,
  resolveConversationId,
} from '../repositories/conversation_repository';
import { AIMessage, HumanMessage, SystemMessage, ToolMessage, BaseMessage } from '@langchain/core/messages';

import dotenv from 'dotenv';
dotenv.config();

const MAX_ITERATIONS = 4;
const DEFAULT_CONVERSATION_HISTORY_LIMIT = 10;

function getConversationHistoryLimit(): number {
  const parsed = Number.parseInt(process.env.CONVERSATION_HISTORY_LIMIT ?? '', 10);

  if (Number.isNaN(parsed) || parsed < 0) {
    return DEFAULT_CONVERSATION_HISTORY_LIMIT;
  }

  return parsed;
}

function mapConversationHistoryToLlmMessages(
  history: ChatHistoryMessage[],
): BaseMessage[] {
  return history.flatMap<BaseMessage>((chatMessage) => {
    const content = chatMessage.conteudo?.trim();

    if (!content) {
      return [];
    }

    if (chatMessage.tipo_remetente === 'client') {
      return [new HumanMessage(content)];
    }

    if (chatMessage.tipo_remetente === 'bot') {
      return [new AIMessage(content)];
    }

    return [];
  });
}

function getMessageText(message: BaseMessage): string {
  const { content } = message;
  return typeof content === 'string' ? content.trim() : JSON.stringify(content).trim();
}

function shouldAppendCurrentMessage(
  historyMessages: BaseMessage[],
  currentMessage: string,
): boolean {
  const lastMessage = historyMessages[historyMessages.length - 1];

  if (!lastMessage || !(lastMessage instanceof HumanMessage)) {
    return true;
  }

  return getMessageText(lastMessage) !== currentMessage.trim();
}

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

export async function analyzeMessage(message: string, number: string, conversacaoId?: string) {
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

  const inputGuardrail = await evaluateInputGuardrails(message, model);
  if (!inputGuardrail.allowed) {
    console.warn(
      `[Guardrails] Entrada bloqueada (${inputGuardrail.category}): ${inputGuardrail.reason}`,
    );

    return {
      result: inputGuardrail.safeResponse,
      action: 'REPLY',
      guardrail: inputGuardrail.category,
    };
  }

  const tools = getTools(number, message, customer?.id);
  const modelWithTools = model.bindTools(tools);

  const resolvedConversationId = await resolveConversationId(conversacaoId, customer?.id);
  const historyLimit = getConversationHistoryLimit();
  const conversationHistory = await getRecentConversationMessages(
    resolvedConversationId,
    customer?.id,
    historyLimit,
  );
  const historyMessages = mapConversationHistoryToLlmMessages(conversationHistory);

  const messages: BaseMessage[] = [
    new SystemMessage(OFICINA_TIAO_SYSTEM_PROMPT),
    ...historyMessages,
  ];

  if (shouldAppendCurrentMessage(historyMessages, message)) {
    messages.push(new HumanMessage(message));
  }

  console.log(`[AI Service] 🧠 Contexto carregado: ${historyMessages.length}/${historyLimit} mensagens`);
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
      const toolCallId = toolCall.id ?? `${toolCall.name}-${iterations}`;

      if (!tool) {
        console.warn(`[Guardrails] Ferramenta desconhecida bloqueada: ${toolCall.name}`);
        messages.push(new ToolMessage({
          tool_call_id: toolCallId,
          content: 'Ferramenta bloqueada por segurança: ferramenta desconhecida ou não permitida.'
        }));
        continue;
      }

      const toolGuardrail = validateToolCallGuardrails(toolCall.name, toolCall.args, inputGuardrail);
      if (!toolGuardrail.allowed) {
        console.warn(`[Guardrails] ${toolGuardrail.reason}`);
        messages.push(new ToolMessage({
          tool_call_id: toolCallId,
          content: toolGuardrail.toolResult
        }));
        continue;
      }

      console.log(`[AI Service] 🛠️ [Turno ${iterations}] Executando ferramenta: ${toolCall.name}`);
      try {
        const toolResult = await (tool as any).call(toolCall.args);
        const serializedToolResult = typeof toolResult === 'string' ? toolResult : JSON.stringify(toolResult);
        messages.push(new ToolMessage({
          tool_call_id: toolCallId,
          content: sanitizeToolResultForPrompt(serializedToolResult)
        }));
      } catch (error) {
        console.error(`[AI Service] ❌ Erro na ferramenta ${toolCall.name}:`, error);
        messages.push(new ToolMessage({
          tool_call_id: toolCallId,
          content: `Erro técnico ao executar a ferramenta. Por favor, tente novamente.`
        }));
      }
    }
  }

  const finalContent = validateFinalReplyGuardrails(
    normalizeAssistantReply(
      String(finalResponse?.content || 'Desculpe, tive um problema ao processar sua solicitação no momento. Posso tentar novamente?')
    )
  );

  return {
    result: finalContent,
    action: 'REPLY'
  };
}
