const LEGACY_PLACEHOLDER_TOKEN_GROUPS = [
  ['new', 'client'],
  ['cliente', 'whatsapp'],
];

const NON_NAME_INTENT_PATTERN =
  /\b(agendar|agendamento|marcar|horario|orcamento|servico|troca|trocar|oleo|pneu|pneus|freio|freios|alinhamento|balanceamento|bateria|suspensao|revisao|diagnostico|mecanica|borracharia|pastilha|filtro|carro|veiculo|placa|problema|quero|preciso|gostaria|atendimento)\b/i;

function normalizeText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

export function normalizePhone(value: string | null | undefined): string {
  return (value ?? '').replace(/\D/g, '');
}

export function cleanCustomerName(value: string): string {
  const collapsed = value
    .replace(/[.,;:!?]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  const normalized = normalizeText(collapsed);
  const prefixes = [
    'meu nome e ',
    'meu nome eh ',
    'eu me chamo ',
    'me chamo ',
    'sou o ',
    'sou a ',
    'sou ',
    'aqui e ',
    'aqui eh ',
  ];
  const matchedPrefix = prefixes.find((prefix) => normalized.startsWith(prefix));

  if (!matchedPrefix) return collapsed;

  const wordsToDrop = matchedPrefix.trim().split(/\s+/).length;
  return collapsed.split(/\s+/).slice(wordsToDrop).join(' ').trim();
}

export function isGenericCustomerName(name: string | null | undefined, phone?: string | null): boolean {
  const trimmed = (name ?? '').trim();
  if (!trimmed) return true;

  const normalizedName = normalizeText(trimmed);
  const normalizedPhone = normalizePhone(phone);
  const normalizedNameDigits = normalizePhone(trimmed);

  if (normalizedPhone && normalizedNameDigits === normalizedPhone) return true;
  if (normalizedNameDigits && normalizedNameDigits.length >= 8 && !/\p{L}/u.test(trimmed)) {
    return true;
  }

  return LEGACY_PLACEHOLDER_TOKEN_GROUPS.some((tokens) =>
    tokens.every((token) => normalizedName.includes(token)),
  );
}

export function isValidCustomerName(name: string, phone?: string | null): boolean {
  const cleanedName = cleanCustomerName(name);

  if (cleanedName.length < 2 || cleanedName.length > 120) return false;
  if (isGenericCustomerName(cleanedName, phone)) return false;
  if (NON_NAME_INTENT_PATTERN.test(normalizeText(cleanedName))) return false;
  if (!/\p{L}/u.test(cleanedName)) return false;
  if (/https?:\/\//i.test(cleanedName)) return false;
  if (normalizePhone(cleanedName).length >= 8) return false;

  return true;
}

export function looksLikeCustomerNameReply(message: string): boolean {
  const cleanedMessage = cleanCustomerName(message);

  if (!cleanedMessage || cleanedMessage.length > 120) return false;
  if (/^(oi|ola|olá|bom dia|boa tarde|boa noite|sim|nao|não)$/i.test(cleanedMessage)) return false;
  if (NON_NAME_INTENT_PATTERN.test(normalizeText(cleanedMessage))) return false;
  if (!/\p{L}/u.test(cleanedMessage)) return false;
  if (/[?]/.test(cleanedMessage)) return false;

  const words = cleanedMessage.split(/\s+/).filter(Boolean);
  return words.length <= 5;
}

export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export function cleanEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function cleanCpfCnpj(value: string): string {
  return value.replace(/\D/g, '');
}

export function isValidCpfCnpj(value: string): boolean {
  const digits = cleanCpfCnpj(value);
  return digits.length === 11 || digits.length === 14;
}

