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
  customerEmail?: string | null;
  needsCustomerName: boolean;
  needsCustomerEmail?: boolean;
  needsCustomerCpfCnpj?: boolean;
}): string {
  const storedName = params.customerName?.trim() || 'NAO_INFORMADO';
  const storedEmail = params.customerEmail?.trim() || 'NAO_INFORMADO';

  const cpfCnpjDigits = onlyDigits(params.customerCpfCnpj);
  const phoneDigits = onlyDigits(params.phoneNumber);
  const phoneWithoutCountryCode = phoneDigits.startsWith('55') ? phoneDigits.slice(2) : phoneDigits;

  const hasCpfCnpj = Boolean(
    cpfCnpjDigits &&
    cpfCnpjDigits !== phoneDigits &&
    cpfCnpjDigits !== phoneWithoutCountryCode,
  );

  const contextLines = [
    'Contexto cadastral do cliente atual:',
    `- Telefone WhatsApp: ${params.phoneNumber}`,
    `- Nome cadastrado: ${storedName}`,
    `- CPF/CNPJ cadastrado: ${hasCpfCnpj ? 'sim' : 'nao'}`,
    `- Email cadastrado: ${storedEmail !== 'NAO_INFORMADO' ? 'sim' : 'nao'}`,
    '',
    'Diretrizes de coleta de dados (aja de forma conversacional e prestativa; não faça múltiplas perguntas de uma vez):'
  ];

  if (params.needsCustomerName) {
    contextLines.push('- NOME: O nome real ainda precisa ser coletado. Para dúvidas sobre LGPD, responda primeiro. Nos demais casos, pergunte o nome de forma amigável e use a ferramenta update_customer com o parametro nome antes de avançar.');
  } else {
    contextLines.push('- NOME: Já confirmado. Não pergunte novamente, a menos que o cliente peça para corrigir.');
  }

  if (params.needsCustomerEmail && !params.needsCustomerName) {
    contextLines.push('- EMAIL: O email está pendente. Peça-o de forma contextualizada (ex: "Para que você consiga logar no Aplicativo da Oficina, qual o seu email?") e apos obte-lo, use a ferramenta update_customer com o parametro email.');
  }

  if (params.needsCustomerCpfCnpj) {
    contextLines.push('- CPF/CNPJ: Como o cliente buscou a oficina, pergunte qual é o CPF ou CNPJ do cliente. Ao obter, use a ferramenta update_customer com o parametro cpf_cnpj.');
  }

  return contextLines.join('\n');
}

function buildVehicleProfileContext(vehicles: Array<{
  placa: string;
  marca: string | null;
  modelo: string | null;
  ano: number | null;
  quilometragem_atual: number | null;
}>): string {
  if (vehicles.length === 0) {
    return [
      'Contexto de veículos do cliente:',
      '- Nenhum veículo cadastrado ainda.',
      '',
      'Diretrizes de coleta de veículo (aja de forma conversacional e prestativa; não faça múltiplas perguntas de uma vez):',
      '- O agendamento exige um veículo. Se o cliente não tiver veículos cadastrados, pergunte a placa do veículo primeiro. Após obter a placa, ela será salva no cadastro. Depois, peça os outros dados obrigatórios (marca, modelo, ano e quilometragem).',
    ].join('\n');
  }

  const contextLines = [
    'Contexto de veículos cadastrados do cliente:',
  ];

  for (const vehicle of vehicles) {
    const isBrandMissing = !vehicle.marca || vehicle.marca === 'Nao informado' || vehicle.marca === 'Não informado';
    const isModelMissing = !vehicle.modelo || vehicle.modelo === 'Nao informado' || vehicle.modelo === 'Não informado';
    const isYearMissing = !vehicle.ano || vehicle.ano === new Date().getFullYear();
    const isMileageMissing = !vehicle.quilometragem_atual;

    const brand = isBrandMissing ? 'NAO_INFORMADO' : vehicle.marca;
    const model = isModelMissing ? 'NAO_INFORMADO' : vehicle.modelo;
    const year = isYearMissing ? 'NAO_INFORMADO' : vehicle.ano;
    const mileage = isMileageMissing ? 'NAO_INFORMADO' : vehicle.quilometragem_atual;

    contextLines.push(`- Veículo Placa ${vehicle.placa}:`);
    contextLines.push(`  - Marca: ${brand}`);
    contextLines.push(`  - Modelo: ${model}`);
    contextLines.push(`  - Ano: ${year}`);
    contextLines.push(`  - Quilometragem: ${mileage}`);

    const missingFields: string[] = [];
    if (isBrandMissing) missingFields.push('marca');
    if (isModelMissing) missingFields.push('modelo');
    if (isYearMissing) missingFields.push('ano');
    if (isMileageMissing) missingFields.push('quilometragem');

    if (missingFields.length > 0) {
      contextLines.push(`  - Diretriz para Placa ${vehicle.placa}: Ainda faltam os dados obrigatórios do veículo: ${missingFields.join(', ')}. Pergunte-os de forma amigável (uma informação por vez, sem enxurrada de perguntas) e use a ferramenta update_vehicle assim que obtê-los. A quilometragem também é um dado obrigatório.`);
    } else {
      contextLines.push(`  - Todos os dados obrigatórios do veículo (placa, marca, modelo, ano e quilometragem) estão completos.`);
    }
  }

  return contextLines.join('\n');
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
    : `Agendamento e orçamento criados com sucesso${typeof data.agendado_para === 'string'
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

function getOficinaStatus(): { isOpen: boolean; label: string } {
  const options = { timeZone: 'America/Sao_Paulo' };
  
  const dayName = new Intl.DateTimeFormat('en-US', { ...options, weekday: 'long' }).format(new Date());
  const hourStr = new Intl.DateTimeFormat('en-US', { ...options, hour: 'numeric', hour12: false }).format(new Date());
  const minStr = new Intl.DateTimeFormat('en-US', { ...options, minute: 'numeric' }).format(new Date());
  
  const hour = parseInt(hourStr, 10);
  const minute = parseInt(minStr, 10);
  const isWeekend = dayName === 'Saturday' || dayName === 'Sunday';
  
  const minutesSinceMidnight = hour * 60 + minute;
  const isOpen = !isWeekend && minutesSinceMidnight >= 8 * 60 && minutesSinceMidnight < 18 * 60;
  
  return {
    isOpen,
    label: isOpen ? 'ABERTA' : 'FECHADA'
  };
}

async function findCustomerByPhone(phoneNumber: string) {
  const cleanPhone = onlyDigits(phoneNumber);
  if (!cleanPhone) return null;

  const phoneWithoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;

  const rows = await prisma.$queryRaw<any[]>`
    SELECT id, nome, telefone, cpf_cnpj, email, tipo_id
    FROM usuarios
    WHERE regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${cleanPhone}
       OR regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${phoneWithoutCountryCode}
    LIMIT 1
  `;

  return rows[0] ?? null;
}

export async function analyzeMessage(message: string, number: string, conversacaoId?: string) {
  console.log(`\n[AI Service] 📩 Requisição recebida de: ${number}`);
  console.log(`[AI Service] 💬 Mensagem: "${message}"`);

  const customer = await findCustomerByPhone(number);

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
    registeredName: customer?.nome,
    customerPhone: number,
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
  const activeNeedsCustomerEmail = !activeCustomer?.email;
  const activeCpfCnpjDigits = onlyDigits(activeCustomer?.cpf_cnpj);
  const activePhoneDigits = onlyDigits(number);
  const activePhoneWithoutCountryCode = activePhoneDigits.startsWith('55') ? activePhoneDigits.slice(2) : activePhoneDigits;
  const activeHasCpfCnpj = Boolean(
    activeCpfCnpjDigits &&
    activeCpfCnpjDigits !== activePhoneDigits &&
    activeCpfCnpjDigits !== activePhoneWithoutCountryCode,
  );
  const activeNeedsCustomerCpfCnpj = !activeHasCpfCnpj;

  const customerVehicles = activeCustomer
    ? await prisma.veiculos.findMany({
      where: { cliente_id: activeCustomer.id },
      select: {
        placa: true,
        marca: true,
        modelo: true,
        ano: true,
        quilometragem_atual: true,
      },
    })
    : [];

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
  const oficinaStatus = getOficinaStatus();
  const messages: BaseMessage[] = [
    new SystemMessage(OFICINA_TIAO_SYSTEM_PROMPT),
    new SystemMessage(`A data e hora atuais do sistema são: ${new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })}.
A oficina está atualmente ${oficinaStatus.label}. O horário de funcionamento estabelecido é de segunda a sexta-feira, das 08:00 às 18:00. Fora desse horário (incluindo finais de semana), a oficina está FECHADA e você não deve realizar agendamentos, apenas tirar dúvidas. Informe ao cliente de forma clara se a oficina está aberta ou fechada com base nisso.`),
    new SystemMessage(buildCustomerProfileContext({
      phoneNumber: number,
      customerName: activeCustomer?.nome,
      customerCpfCnpj: activeCustomer?.cpf_cnpj,
      customerEmail: activeCustomer?.email,
      needsCustomerName: activeNeedsCustomerName,
      needsCustomerEmail: activeNeedsCustomerEmail,
      needsCustomerCpfCnpj: activeNeedsCustomerCpfCnpj,
    })),
    new SystemMessage(buildVehicleProfileContext(customerVehicles)),
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
  };
}
