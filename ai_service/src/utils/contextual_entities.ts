import { cleanCustomerName, looksLikeCustomerNameReply } from './customer_name';

export type ContextualEntityType = 'customer_name' | 'cpf' | 'license_plate';

export type ContextualEntity = {
  type: ContextualEntityType;
  rawValue: string;
  value: string;
};

export type ContextualEntityContext = {
  awaitingCustomerName?: boolean;
  lastAssistantMessage?: string | null;
};

const MAX_CONTEXT_MESSAGE_LENGTH = 700;
const SHORT_DIRECT_ANSWER_MAX_LENGTH = 80;

export function normalizeEntityText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

export function compactContextMessage(value: string | null | undefined): string | null {
  const trimmed = value?.replace(/\s+/g, ' ').trim();

  if (!trimmed) return null;

  return trimmed.length > MAX_CONTEXT_MESSAGE_LENGTH
    ? `${trimmed.slice(0, MAX_CONTEXT_MESSAGE_LENGTH)}...`
    : trimmed;
}

export function isAssistantAskingForInformation(lastAssistantMessage: string | null | undefined): boolean {
  const compacted = compactContextMessage(lastAssistantMessage);

  if (!compacted) return false;

  const normalized = normalizeEntityText(compacted);

  return (
    compacted.includes('?') ||
    /\b(qual|quais|informe|informar|me diga|me passa|pode me dizer|pode informar|pode enviar|envie|confirme|confirmar|preciso|falta|faltam)\b/i.test(normalized)
  );
}

export function isShortDirectAnswer(message: string): boolean {
  const trimmed = message.trim();

  if (!trimmed || trimmed.length > SHORT_DIRECT_ANSWER_MAX_LENGTH) return false;
  if (trimmed.includes('\n')) return false;
  if (/[{}<>`]/.test(trimmed)) return false;

  return true;
}

function compactIdentifier(value: string): string {
  return value.trim().toUpperCase().replace(/[\s-]/g, '');
}

export function normalizeLicensePlate(value: string): string {
  return compactIdentifier(value);
}

export function looksLikeBrazilianLicensePlate(message: string): boolean {
  const compacted = normalizeLicensePlate(message);

  return /^[A-Z]{3}\d[A-Z0-9]\d{2}$/.test(compacted);
}

export function normalizeCpf(value: string): string {
  return value.replace(/\D/g, '');
}

export function looksLikeCpf(message: string): boolean {
  const trimmed = message.trim();
  const digits = normalizeCpf(trimmed);

  if (digits.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(digits)) return false;

  return /^[\d.\-\s]+$/.test(trimmed);
}

export function looksLikeSimpleIdentifier(message: string): boolean {
  const trimmed = message.trim();

  if (trimmed.length < 2 || trimmed.length > 32) return false;
  if (/\s/.test(trimmed)) return false;
  if (!/\d/.test(trimmed)) return false;

  return /^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(trimmed);
}

export function looksLikeDateOrTimeReply(message: string): boolean {
  const normalized = normalizeEntityText(message.trim());

  return (
    /^\d{1,2}([/.:-])\d{1,2}(?:\1\d{2,4})?$/.test(normalized) ||
    /^\d{1,2}h(?:\d{2})?$/.test(normalized) ||
    /^\d{1,2}:\d{2}$/.test(normalized) ||
    /^(hoje|amanha|depois de amanha|segunda|terca|quarta|quinta|sexta|sabado|domingo|manha|tarde|noite)$/.test(normalized)
  );
}

export function looksLikeConfirmationReply(message: string): boolean {
  return /^(sim|s|ok|okay|confirmo|confirmado|pode ser|isso|nao|n|negativo)$/i.test(normalizeEntityText(message.trim()));
}

export function looksLikeShortServiceOrProblemReply(message: string): boolean {
  const trimmed = message.trim();

  if (trimmed.length < 2 || trimmed.length > SHORT_DIRECT_ANSWER_MAX_LENGTH) return false;
  if (/[?{}<>`]/.test(trimmed)) return false;

  const words = trimmed.split(/\s+/).filter(Boolean);
  return words.length <= 8;
}

function assistantMessageExpectsCustomerName(normalizedLastAssistantMessage: string): boolean {
  return (
    /\b(qual|informe|informar|me diga|me passa|pode me dizer|pode informar|confirme|confirmar)\b.{0,50}\b(seu|teu)\b.{0,25}\bnome\b/.test(normalizedLastAssistantMessage) ||
    /\bnome\b.{0,50}\b(cadastral|cadastro|real|completo|do cliente)\b/.test(normalizedLastAssistantMessage) ||
    /\bcomo\b.{0,20}\b(voce|vc)\b.{0,20}\b(chama)\b/.test(normalizedLastAssistantMessage)
  );
}

function assistantMessageExpectsCpf(normalizedLastAssistantMessage: string): boolean {
  return /\b(cpf|cpf\/cnpj|documento|documento cadastral|dados cadastrais)\b/.test(normalizedLastAssistantMessage);
}

function assistantMessageExpectsLicensePlate(normalizedLastAssistantMessage: string): boolean {
  return /\b(placa|veiculo|carro|moto|automovel)\b/.test(normalizedLastAssistantMessage);
}

export function extractContextualEntity(
  message: string,
  context?: ContextualEntityContext,
): ContextualEntity | null {
  if (!isShortDirectAnswer(message)) return null;

  const lastAssistantMessage = compactContextMessage(context?.lastAssistantMessage);
  const normalizedLastAssistantMessage = lastAssistantMessage
    ? normalizeEntityText(lastAssistantMessage)
    : '';

  const isExpectedReply = Boolean(lastAssistantMessage && isAssistantAskingForInformation(lastAssistantMessage));

  if (
    (context?.awaitingCustomerName || (isExpectedReply && assistantMessageExpectsCustomerName(normalizedLastAssistantMessage))) &&
    looksLikeCustomerNameReply(message)
  ) {
    return {
      type: 'customer_name',
      rawValue: message,
      value: cleanCustomerName(message),
    };
  }

  if (isExpectedReply && assistantMessageExpectsCpf(normalizedLastAssistantMessage) && looksLikeCpf(message)) {
    return {
      type: 'cpf',
      rawValue: message,
      value: normalizeCpf(message),
    };
  }

  if (
    isExpectedReply &&
    assistantMessageExpectsLicensePlate(normalizedLastAssistantMessage) &&
    looksLikeBrazilianLicensePlate(message)
  ) {
    return {
      type: 'license_plate',
      rawValue: message,
      value: normalizeLicensePlate(message),
    };
  }

  return null;
}
