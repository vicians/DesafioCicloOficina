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
import { isGenericCustomerName } from '../utils/customer_name';
import { extractContextualEntity } from '../utils/contextual_entities';
import { persistContextualEntity } from './entity_capture_service';
import { AIMessage, HumanMessage, SystemMessage, ToolMessage, BaseMessage } from '@langchain/core/messages';

import dotenv from 'dotenv';
dotenv.config();

const MAX_ITERATIONS = 4;
const DEFAULT_CONVERSATION_HISTORY_LIMIT = 7;

function getConversationHistoryLimit(): number {
  const parsed = Number.parseInt(process.env.CONVERSATION_HISTORY_LIMIT ?? '', 10);

  if (Number.isNaN(parsed) || parsed < 0) {
    return DEFAULT_CONVERSATION_HISTORY_LIMIT;
  }

  return parsed;
}

function onlyDigits(value: string | null | undefined): string {
  return (value ?? '').replace(/\D/g, '');
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

function buildCustomerProfileContext(params: {
  phoneNumber: string;
  customerName?: string | null;
  customerCpfCnpj?: string | null;
  needsCustomerName: boolean;
}): string {
  const storedName = params.customerName?.trim() || 'NAO_INFORMADO';
  const cpfCnpjDigits = onlyDigits(params.customerCpfCnpj);
  const phoneDigits = onlyDigits(params.phoneNumber);
  const phoneWithoutCountryCode = phoneDigits.startsWith('55') ? phoneDigits.slice(2) : phoneDigits;
  const hasCpfCnpj = Boolean(
    cpfCnpjDigits &&
    cpfCnpjDigits !== phoneDigits &&
    cpfCnpjDigits !== phoneWithoutCountryCode,
  );

  return [
    'Contexto cadastral do cliente atual:',
    `- Telefone WhatsApp: ${params.phoneNumber}`,
    `- Nome cadastrado: ${storedName}`,
    `- CPF/CNPJ cadastrado: ${hasCpfCnpj ? 'sim' : 'nao'}`,
    `- Nome real confirmado: ${params.needsCustomerName ? 'nao' : 'sim'}`,
    params.needsCustomerName
      ? '- O nome real ainda precisa ser coletado. Para duvidas gerais sobre privacidade, LGPD ou seguranca dos dados, responda primeiro sem pedir o nome. Nos demais atendimentos, pergunte de forma natural e, assim que o cliente informar, use update_customer_name antes de seguir com a proxima acao.'
      : '- O nome real ja esta confirmado. Nao peca o nome novamente a menos que o cliente queira corrigir.',
  ].join('\n');
}

function isAwaitingCustomerName(history: ChatHistoryMessage[]): boolean {
  const lastBotMessage = [...history]
    .reverse()
    .find((chatMessage) => chatMessage.tipo_remetente === 'bot')
    ?.conteudo
    ?.normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

  if (!lastBotMessage) return false;

  return (
    /\bnome\b/.test(lastBotMessage) &&
    /\b(qual|informe|informar|me diga|me passa|pode me dizer|confirmar|confirmar seu)\b/.test(lastBotMessage)
  );
}

function getLastAssistantMessage(history: ChatHistoryMessage[]): string | null {
  return [...history]
    .reverse()
    .find((chatMessage) => chatMessage.tipo_remetente === 'bot')
    ?.conteudo
    ?.trim() ?? null;
}

function parseJsonText(content: string): unknown | null {
  try {
    return JSON.parse(content);
  } catch {
    return null;
  }
}

type AppointmentToolSuccess = {
  agendamento_id: string;
  orcamento_id: string;
  agendado_para?: string;
  magic_link_url?: string | null;
  message?: string;
};

function isAppointmentToolSuccess(value: unknown): value is AppointmentToolSuccess {
  if (!value || typeof value !== 'object') return false;
  const data = value as Record<string, unknown>;

  return typeof data.agendamento_id === 'string' && typeof data.orcamento_id === 'string';
}

function isGenericFailureReply(content: string): boolean {
  const normalized = content.toLowerCase();
  return (
    normalized.includes('desculpe') ||
    normalized.includes('não consegui') ||
    normalized.includes('nao consegui') ||
    normalized.includes('problema ao processar') ||
    normalized.includes('erro técnico') ||
    normalized.includes('erro tecnico')
  );
}

function formatAppointmentConfirmation(data: AppointmentToolSuccess): string {
  return typeof data.message === 'string' && data.message.trim()
    ? data.message.trim()
    : `Agendamento e orçamento criados com sucesso${
        typeof data.agendado_para === 'string'
          ? ` para ${new Date(data.agendado_para).toLocaleString('pt-BR')}`
          : ''
      }.`;
}

function appendAppointmentLinkIfMissing(content: string, fallbackAppointment?: AppointmentToolSuccess | null): string {
  return content;
}

function normalizeAssistantReply(content: string, fallbackAppointment?: AppointmentToolSuccess | null): string {
  const trimmed = content.trim();

  if (!trimmed) {
    if (fallbackAppointment) {
      return formatAppointmentConfirmation(fallbackAppointment);
    }

    return 'Não consegui concluir a solicitação agora. Pode reformular a mensagem?';
  }

  if (fallbackAppointment && isGenericFailureReply(trimmed)) {
    return formatAppointmentConfirmation(fallbackAppointment);
  }

  const parsed = parseJsonText(trimmed);
  if (!parsed || typeof parsed !== 'object') {
    return appendAppointmentLinkIfMissing(trimmed, fallbackAppointment);
  }

  const data = parsed as Record<string, unknown>;

  if (typeof data.result === 'string' && data.result.trim()) {
    return appendAppointmentLinkIfMissing(data.result.trim(), fallbackAppointment);
  }

  if (typeof data.message === 'string' && data.message.trim()) {
    return appendAppointmentLinkIfMissing(data.message.trim(), fallbackAppointment);
  }

  if (data.ok === false && typeof data.error === 'string') {
    if (fallbackAppointment) {
      return formatAppointmentConfirmation(fallbackAppointment);
    }

    return `Não consegui concluir a ação no sistema: ${data.error}`;
  }

  if (isAppointmentToolSuccess(data)) {
    return formatAppointmentConfirmation(data);
  }

  return appendAppointmentLinkIfMissing(trimmed, fallbackAppointment);
}

export async function analyzeMessage(message: string, number: string, conversacaoId?: string) {
  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

  let magicLinkUrl: string | undefined = undefined;

  const customer = await prisma.usuarios.findUnique({
    where: { telefone: number },
  });

  if (customer && customer.tipo_id !== 2) {
    console.warn(
      `[AI Service] Numero ${number} pertence a usuario interno (tipo_id=${customer.tipo_id}); nao acionando handoff automatico.`,
    );

    return {
      result:
        'Este numero esta cadastrado como usuario interno da oficina. Para testar o atendimento automatico como cliente, use um numero cadastrado como CLIENTE ou remova este telefone do usuario interno.',
      action: 'REPLY',
      info: 'Numero de usuario interno detectado. Handoff automatico ignorado.',
    };
  }

  const resolvedConversationId = await resolveConversationId(conversacaoId, customer?.id);
  const historyLimit = getConversationHistoryLimit();
  const conversationHistory = await getRecentConversationMessages(
    resolvedConversationId,
    customer?.id,
    historyLimit,
  );
  const historyMessages = mapConversationHistoryToLlmMessages(conversationHistory);
  const needsCustomerName = !customer || isGenericCustomerName(customer.nome, number);
  const awaitingCustomerName = needsCustomerName && isAwaitingCustomerName(conversationHistory);
  const lastAssistantMessage = getLastAssistantMessage(conversationHistory);

  const guardrailModel = model.withConfig({
    runName: 'Oficina_Tiao_Input_Guardrail',
    metadata: {
      customer_phone: number,
      customer_id: customer?.id ?? 'unknown',
    },
  });

  const inputGuardrail = await evaluateInputGuardrails(message, guardrailModel as any, {
    awaitingCustomerName,
    lastAssistantMessage,
  });
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

  const capturedEntity = extractContextualEntity(message, {
    awaitingCustomerName,
    lastAssistantMessage,
  });
  const capturedEntityState = await persistContextualEntity(capturedEntity, {
    phoneNumber: number,
    customerId: customer?.id,
  });
  const activeCustomer = capturedEntityState?.customer ?? customer;
  const activeNeedsCustomerName = !activeCustomer || isGenericCustomerName(activeCustomer.nome, number);

  if (capturedEntityState) {
    console.log(
      `[AI Service] Dado contextual capturado: ${capturedEntityState.entity.type} (${capturedEntityState.status})`,
    );
  }

  const tools = getTools(number, message, activeCustomer?.id);

  const modelWithTools = model.bindTools(tools).withConfig({
    runName: 'Oficina_Tiao_Agent_Loop',
    metadata: {
      customer_phone: number,
      customer_id: activeCustomer?.id ?? 'unknown',
      conversation_id: resolvedConversationId,
    },
  });
  const messages: BaseMessage[] = [
    new SystemMessage(OFICINA_TIAO_SYSTEM_PROMPT),
    new SystemMessage(buildCustomerProfileContext({
      phoneNumber: number,
      customerName: activeCustomer?.nome,
      customerCpfCnpj: activeCustomer?.cpf_cnpj,
      needsCustomerName: activeNeedsCustomerName,
    })),
    ...(capturedEntityState ? [new SystemMessage(capturedEntityState.promptContext)] : []),
    ...historyMessages,
  ];

  if (shouldAppendCurrentMessage(historyMessages, message)) {
    messages.push(new HumanMessage(message));
  }

  console.log(`[AI Service] 🧠 Contexto carregado: ${historyMessages.length}/${historyLimit} mensagens`);
  console.log(`[AI Service] 🤖 Iniciando raciocínio do agente...`);

  let iterations = 0;
  let finalResponse: any = null;
  let lastSuccessfulAppointment: AppointmentToolSuccess | null = null;

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
        const parsedToolResult = parseJsonText(serializedToolResult);

        if (toolCall.name === 'create_appointment' && isAppointmentToolSuccess(parsedToolResult)) {
          lastSuccessfulAppointment = parsedToolResult;
          if (typeof parsedToolResult.magic_link_url === 'string') {
            magicLinkUrl = parsedToolResult.magic_link_url;
          }
        }
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
      String(finalResponse?.content ?? ''),
      lastSuccessfulAppointment
    )
  );

  return {
    result: finalContent,
    action: 'REPLY',
    magic_link_url: magicLinkUrl
  };
}
