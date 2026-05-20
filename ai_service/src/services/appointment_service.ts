import axios from 'axios';
import { CreateOsBody } from '../schemas/ai_schemas';
import { resolveAppointmentDate, toDateOnlyString } from '../utils/date_utils';
import { extractBackendErrorMessage } from '../utils/backend_error';
import { cleanCustomerName, isValidCustomerName } from '../utils/customer_name';
import { looksLikeBrazilianLicensePlate, normalizeLicensePlate } from '../utils/contextual_entities';
import { prisma } from '../config/prisma';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const OS_RECOVERY_LOOKBACK_BUFFER_MS = 5 * 1000;
const DEFAULT_APPOINTMENT_HTTP_TIMEOUT_MS = 10000;

function getAppointmentHttpTimeoutMs(): number {
  const parsed = Number.parseInt(process.env.APPOINTMENT_HTTP_TIMEOUT_MS ?? '', 10);

  if (Number.isNaN(parsed) || parsed < 1000) {
    return DEFAULT_APPOINTMENT_HTTP_TIMEOUT_MS;
  }

  return parsed;
}

const backendHttp = axios.create({
  baseURL: BACKEND_URL,
  timeout: getAppointmentHttpTimeoutMs(),
});

type AuthHeaders = { Authorization?: string; 'X-Internal-Token'?: string };
type MechanicCandidate = { id: string; nome: string };
type BackendCustomer = { id: string; nome?: string; telefone?: string | null };
type DbCustomerLookup = { id: string; nome: string | null; telefone: string | null };
type BackendAppointmentSummary = {
  id?: string;
  funcionario_id?: string | null;
  agendado_para?: string | Date | null;
  criado_em?: string | Date | null;
  notas_cliente?: string | null;
  veiculo_placa?: string | null;
};
type OsWorkflowResult = {
  agendamento_id: string;
  orcamento_id: string;
  mechanic: { id: string | null; nome: string };
  agendado_para: string;
  magic_link_url: string | null;
  message: string;
  recovered?: boolean;
};

async function getAuthHeaders() {
  return { 'X-Internal-Token': process.env.INTERNAL_AUTH_TOKEN };
}

function normalizePhone(value: string | null | undefined): string {
  return (value ?? '').replace(/\D/g, '');
}

async function findCustomerByPhone(phoneNumber: string): Promise<DbCustomerLookup | null> {
  const cleanPhone = normalizePhone(phoneNumber);
  if (!cleanPhone) return null;

  const phoneWithoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;
  const rows = await prisma.$queryRaw<DbCustomerLookup[]>`
    SELECT id, nome, telefone
    FROM usuarios
    WHERE tipo_id = 2
      AND (
        regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${cleanPhone}
        OR regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${phoneWithoutCountryCode}
      )
    LIMIT 1
  `;

  return rows[0] ?? null;
}

function phoneMatches(left: string | null | undefined, right: string | null | undefined): boolean {
  const leftDigits = normalizePhone(left);
  const rightDigits = normalizePhone(right);

  if (!leftDigits || !rightDigits) return false;
  if (leftDigits === rightDigits) return true;

  const leftWithoutCountryCode = leftDigits.startsWith('55') ? leftDigits.slice(2) : leftDigits;
  const rightWithoutCountryCode = rightDigits.startsWith('55') ? rightDigits.slice(2) : rightDigits;
  return leftWithoutCountryCode === rightWithoutCountryCode;
}

function dateTimeMs(value: unknown): number {
  const date = value instanceof Date
    ? value
    : typeof value === 'string'
      ? new Date(value)
      : null;

  if (!date || Number.isNaN(date.getTime())) {
    return 0;
  }

  return date.getTime();
}

function buildOsWorkflowResult(params: {
  agendamentoId: string;
  orcamentoId: string;
  mecanicoId: string | null;
  mecanicoNome: string;
  agendadoPara: Date;
  magicLinkUrl: string | null;
  recovered?: boolean;
}): OsWorkflowResult {
  return {
    agendamento_id: params.agendamentoId,
    orcamento_id: params.orcamentoId,
    mechanic: { id: params.mecanicoId, nome: params.mecanicoNome },
    agendado_para: params.agendadoPara.toISOString(),
    magic_link_url: params.magicLinkUrl,
    message: params.magicLinkUrl
      ? `Agendamento e Orçamento criados com sucesso! Acesse pelo link: ${params.magicLinkUrl}`
      : 'Agendamento criado! Entre em contato para detalhes do orçamento.',
    recovered: params.recovered,
  };
}

async function createMagicLinkForPhone(telefone: string): Promise<string | null> {
  try {
    const mlRes = await backendHttp.post('/auth/magic-link', { telefone });
    return mlRes.data.url ?? null;
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível gerar magic link:', extractBackendErrorMessage(err));
    return null;
  }
}

async function findBudgetByAppointmentId(
  agendamentoId: string,
  headers: AuthHeaders
): Promise<string | null> {
  const existingOrcamentos = await backendHttp.get('/orcamentos', { headers });
  const foundOrcamento = (existingOrcamentos.data ?? []).find(
    (orcamento: any) => orcamento.agendamento_id === agendamentoId
  );

  return foundOrcamento?.id ?? null;
}

async function getOrCreateBudgetForAppointment(
  agendamentoId: string,
  clienteId: string,
  mecanicoId: string | null,
  headers: AuthHeaders
): Promise<string> {
  const existingId = await findBudgetByAppointmentId(agendamentoId, headers);
  if (existingId) return existingId;

  try {
    const orcRes = await backendHttp.post('/orcamentos', {
      agendamento_id: agendamentoId,
      cliente_id: clienteId,
      funcionario_id: mecanicoId,
    }, {
      headers,
    });
    return orcRes.data.id;
  } catch (err: any) {
    if (err?.response?.status === 409) {
      const fallbackId = await findBudgetByAppointmentId(agendamentoId, headers);
      if (fallbackId) return fallbackId;
    }

    throw err;
  }
}

function isMechanicScheduleConflict(error: any): boolean {
  const message = extractBackendErrorMessage(error).toLowerCase();
  return error?.response?.status === 409 && message.includes('funcionário') && message.includes('agendamento');
}

async function createAppointmentWithMechanicFallback(params: {
  clienteId: string;
  veiculoId: string;
  mecanicos: MechanicCandidate[];
  data: string;
  hora: number;
  notasCliente: string;
  headers: AuthHeaders;
}): Promise<{ agendamentoId: string; mecanicoId: string | null; mecanicoNome: string }> {
  const candidates: Array<{ id: string | null; nome: string }> = [
    ...params.mecanicos,
    { id: null, nome: 'A definir' },
  ];

  for (const candidate of candidates) {
    try {
      const agendRes = await backendHttp.post('/agendamentos', {
        cliente_id: params.clienteId,
        veiculo_id: params.veiculoId,
        funcionario_id: candidate.id,
        data: params.data,
        hora: params.hora,
        para_avaliacao: true,
        notas_cliente: params.notasCliente,
      }, {
        headers: params.headers,
      });

      return {
        agendamentoId: agendRes.data.id,
        mecanicoId: candidate.id,
        mecanicoNome: candidate.nome,
      };
    } catch (err: any) {
      if (candidate.id && isMechanicScheduleConflict(err)) {
        console.warn(`[OS] Mecânico indisponível (${candidate.nome}), tentando próximo responsável.`);
        continue;
      }

      throw err;
    }
  }

  throw new Error('Não foi possível criar agendamento para nenhum responsável disponível.');
}

export async function recoverRecentOsWorkflow(
  body: CreateOsBody & { services?: string[] },
  startedAt: Date,
): Promise<OsWorkflowResult | null> {
  try {
    if (!body.number) return null;

    const headers = await getAuthHeaders();
    const usuariosRes = await backendHttp.get('/usuarios', {
      params: { tipo_id: 2 },
      headers,
    });
    const clientes = (usuariosRes.data ?? []) as BackendCustomer[];
    const cliente = clientes.find((candidate) => phoneMatches(candidate.telefone, body.number));

    if (!cliente) return null;

    const agendamentosRes = await backendHttp.get(`/agendamentos/cliente/${cliente.id}`, {
      headers,
    });
    const agendamentos = (agendamentosRes.data ?? []) as BackendAppointmentSummary[];
    const minCreatedAt = startedAt.getTime() - OS_RECOVERY_LOOKBACK_BUFFER_MS;
    const requestedPlate = body.vehiclePlate ? normalizeLicensePlate(body.vehiclePlate) : '';
    const candidates = agendamentos
      .filter((agendamento) => dateTimeMs(agendamento.criado_em) >= minCreatedAt)
      .filter((agendamento) => agendamento.notas_cliente?.startsWith('[WhatsApp]'))
      .filter((agendamento) => {
        if (!requestedPlate) return true;
        return typeof agendamento.veiculo_placa === 'string' &&
          normalizeLicensePlate(agendamento.veiculo_placa) === requestedPlate;
      })
      .sort((left, right) => dateTimeMs(right.criado_em) - dateTimeMs(left.criado_em));

    for (const agendamento of candidates) {
      if (!agendamento.id || !agendamento.agendado_para) continue;

      const orcamentoId = await findBudgetByAppointmentId(agendamento.id, headers);
      if (!orcamentoId) continue;

      const agendadoPara = new Date(agendamento.agendado_para);
      if (Number.isNaN(agendadoPara.getTime())) continue;

      const magicLinkUrl = await createMagicLinkForPhone(cliente.telefone ?? body.number);
      console.warn(`[OS] Fluxo recuperado após erro: agendamento ${agendamento.id}, orçamento ${orcamentoId}`);

      return buildOsWorkflowResult({
        agendamentoId: agendamento.id,
        orcamentoId,
        mecanicoId: agendamento.funcionario_id ?? null,
        mecanicoNome: agendamento.funcionario_id ? 'Responsável atribuído' : 'A definir',
        agendadoPara,
        magicLinkUrl,
        recovered: true,
      });
    }
  } catch (err: any) {
    console.warn('[OS] Falha ao verificar OS persistida após erro:', extractBackendErrorMessage(err));
  }

  return null;
}

export async function createOsWorkflow(body: CreateOsBody & { services?: string[] }) {
  const { number, customerName, vehiclePlate, description, serviceType, services, requestedDate } = body;

  if (!number || !description) {
    throw new Error('number e description são obrigatórios');
  }

  const agendadoPara = resolveAppointmentDate(requestedDate);
  const cleanedCustomerName = customerName ? cleanCustomerName(customerName) : '';

  // ── 1. Localizar ou criar cliente ─────────────────────────────────────────
  console.log(`[OS] 📝 Iniciando processo de criação para: ${number}`);
  let clienteId: string;
  let clienteTelefone: string = number;
  const headers = await getAuthHeaders();

  const usuariosRes = await backendHttp.get('/usuarios', {
    params: { tipo_id: 2 },
    headers,
  });
  const todos: any[] = usuariosRes.data ?? [];
  const found = todos.find((u: any) => phoneMatches(u.telefone, number));

  if (found) {
    clienteId = found.id;
    clienteTelefone = found.telefone ?? number;
    console.log(`[OS] Cliente encontrado: ${found.nome} (${clienteId})`);
  } else {
    console.log(`[OS] Cliente não encontrado. Criando novo registro...`);
    if (!isValidCustomerName(cleanedCustomerName, number)) {
      throw new Error('Nome real do cliente e obrigatorio para criar cadastro e OS via WhatsApp.');
    }

    const temporaryPassword = `whatsapp_${number.replace(/\D/g, '').slice(-8)}_tmp`;
    const novoCliente = await backendHttp.post('/usuarios', {
      tipo_id: 2,
      cpf_cnpj: number.replace(/\D/g, '').slice(0, 20),
      nome: cleanedCustomerName,
      telefone: number,
      senha: temporaryPassword,
    }, {
      headers,
    });
    clienteId = novoCliente.data.id;
    console.log(`[OS] Novo cliente criado: ${clienteId}`);
  }

  // ── 2. Localizar ou criar veículo ─────────────────────────────────────────
  let veiculoId: string;

  if (!vehiclePlate || !looksLikeBrazilianLicensePlate(vehiclePlate)) {
    throw new Error('Placa do veículo é obrigatória para criar a OS. Por favor, informe a placa.');
  }

  const normalizedVehiclePlate = normalizeLicensePlate(vehiclePlate);
  const veiculosRes = await backendHttp.get('/veiculos', { headers });
  const veiculos: any[] = veiculosRes.data ?? [];
  const veiculoFound = veiculos.find(
    (v: any) => typeof v.placa === 'string' && normalizeLicensePlate(v.placa) === normalizedVehiclePlate
  );

  if (veiculoFound) {
    if (veiculoFound.cliente_id && veiculoFound.cliente_id !== clienteId) {
      throw new Error('Esta placa ja esta vinculada a outro cadastro. Confirme a placa ou fale com o atendimento.');
    }

    veiculoId = veiculoFound.id;
    console.log(`[OS] Veículo encontrado: ${normalizedVehiclePlate} (${veiculoId})`);
  } else {
    console.log(`[OS] Veículo não encontrado. Cadastrando placa ${normalizedVehiclePlate}...`);
    const novoVeiculo = await backendHttp.post('/veiculos', {
      cliente_id: clienteId,
      placa: normalizedVehiclePlate,
      marca: 'Não informado',
      modelo: 'Não informado',
      ano: new Date().getFullYear(),
      quilometragem_atual: 0,
    }, {
      headers,
    });
    veiculoId = novoVeiculo.data.id;
    console.log(`[OS] Novo veículo criado: ${normalizedVehiclePlate} (${veiculoId})`);
  }

  // ── 3. Selecionar mecânico disponível ─────────────────────────────────────
  let mecanicos: MechanicCandidate[] = [];

  try {
    const mecanicosRes = await backendHttp.get('/usuarios', {
      params: { tipo_id: 3 },
      headers,
    });
    mecanicos = mecanicosRes.data ?? [];
    if (mecanicos.length > 0) {
      console.log(`[OS] Mecânicos candidatos: ${mecanicos.map((m) => m.nome).join(', ')}`);
    }
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível buscar mecânicos:', extractBackendErrorMessage(err));
  }

  // ── 4. Criar agendamento (data solicitada ou fallback às 09:00) ───────────
  const data = toDateOnlyString(agendadoPara);
  const hora = agendadoPara.getHours();

  const appointment = await createAppointmentWithMechanicFallback({
    clienteId,
    veiculoId,
    mecanicos,
    data,
    hora,
    notasCliente: `[WhatsApp] ${serviceType ?? ''} — ${description}`.trim(),
    headers,
  });
  const { agendamentoId, mecanicoId, mecanicoNome } = appointment;
  console.log(`[OS] Agendamento criado: ${agendamentoId}`);

  // ── 5. Reutilizar ou criar orçamento (rascunho) ───────────────────────────
  const orcamentoId = await getOrCreateBudgetForAppointment(agendamentoId, clienteId, mecanicoId, headers);
  console.log(`[OS] Orçamento vinculado: ${orcamentoId}`);

  // ── 6. Adicionar serviços identificados ───────────────────────────────────
  if (services && services.length > 0) {
    console.log(`[OS] 🛠️ Adicionando serviços identificados: ${services.join(', ')}`);
    const catalogoRes = await backendHttp.get('/servicos', { headers });
    const catalogo: any[] = catalogoRes.data ?? [];

    for (const sName of services) {
      const match = catalogo.find(s =>
        s.nome.toLowerCase().includes(sName.toLowerCase()) ||
        sName.toLowerCase().includes(s.nome.toLowerCase())
      );

      if (match) {
        try {
          await backendHttp.post(`/orcamentos/${orcamentoId}/servicos`, {
            servico_id: match.id,
            quantidade: 1,
            preco_unitario: match.preco
          }, {
            headers,
          });
          console.log(`[OS] Serviço adicionado: ${match.nome}`);
        } catch (err: any) {
          console.error(`[OS] Erro ao adicionar serviço ${match.nome}:`, extractBackendErrorMessage(err));
        }
      }
    }
  }

  // ── 7. Gerar magic link ────────────────────────────────────────────────────
  let magicLinkUrl: string | null = null;
  try {
    const mlRes = await backendHttp.post('/auth/magic-link', {
      telefone: clienteTelefone,
    });
    magicLinkUrl = mlRes.data.url;
  } catch (err) { }

  return {
    agendamento_id: agendamentoId,
    orcamento_id: orcamentoId,
    mechanic: { id: mecanicoId, nome: mecanicoNome },
    agendado_para: agendadoPara.toISOString(),
    magic_link_url: magicLinkUrl,
    message: magicLinkUrl
      ? 'Agendamento e Orçamento criados com sucesso!'
      : 'Agendamento criado! Entre em contato para detalhes do orçamento.',
  };
}

export async function checkAvailability(date: string) {
  console.log(`[AI] Consultando disponibilidade para: ${date}`);
  const headers = await getAuthHeaders();
  const res = await backendHttp.get('/agendamentos/disponibilidade', {
    params: { data: date },
    headers,
  });
  const unavailableHours = Array.isArray(res.data?.horas_indisponiveis)
    ? (res.data.horas_indisponiveis as number[])
        .filter((hour) => Number.isInteger(hour) && hour >= 0 && hour <= 23)
        .sort((a, b) => a - b)
    : [];

  if (unavailableHours.length === 0) {
    return "O dia está totalmente livre. Atendemos das 08:00 às 18:00.";
  }

  const availableHours = Array.from({ length: 11 }, (_, index) => index + 8)
    .filter((hour) => !unavailableHours.includes(hour));
  const targetDate = new Date(`${date}T00:00:00`);
  const dateText = Number.isNaN(targetDate.getTime())
    ? date
    : targetDate.toLocaleDateString('pt-BR');

  if (availableHours.length === 0) {
    return `Nao ha horarios disponiveis em ${dateText}. Posso verificar a proxima data util para voce?`;
  }

  const availableText = availableHours
    .map((hour) => `${String(hour).padStart(2, '0')}:00`)
    .join(', ');
  return `Horarios disponiveis em ${dateText}: ${availableText}.`;
}

type BackendVehicle = {
  placa?: string | null;
  marca?: string | null;
  modelo?: string | null;
};

type BackendAppointment = {
  agendado_para?: string | Date | null;
  notas_cliente?: string | null;
  status?: string | null;
  veiculo_placa?: string | null;
  veiculo_marca?: string | null;
  veiculo_modelo?: string | null;
};

function formatText(value: unknown, fallback: string): string {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }

  if (typeof value === 'number') {
    return String(value);
  }

  return fallback;
}

function formatDate(value: unknown): string {
  const date = value instanceof Date
    ? value
    : typeof value === 'string'
      ? new Date(value)
      : null;

  if (!date || Number.isNaN(date.getTime())) {
    return 'Data nao informada';
  }

  return date.toLocaleDateString('pt-BR');
}

function formatVehicleLine(vehicle: BackendVehicle): string {
  const plate = formatText(vehicle.placa, 'Placa nao informada');
  const make = formatText(vehicle.marca, 'Marca nao informada');
  const model = formatText(vehicle.modelo, 'Modelo nao informado');

  return `- Placa: ${plate}; Marca: ${make}; Modelo: ${model}`;
}

function formatAppointmentLine(appointment: BackendAppointment): string {
  const date = formatDate(appointment.agendado_para);
  const description = formatText(appointment.notas_cliente, 'Sem descricao');
  const status = formatText(appointment.status, '');
  const plate = formatText(appointment.veiculo_placa, '');
  const make = formatText(appointment.veiculo_marca, '');
  const model = formatText(appointment.veiculo_modelo, '');
  const vehicleName = [make, model].filter(Boolean).join(' ').trim();
  const vehicleText = plate
    ? ` | Veiculo: ${vehicleName || 'Marca/modelo nao informados'} | Placa: ${plate}`
    : '';
  const statusText = status ? ` | Status: ${status}` : '';

  return `- ${date}: ${description}${vehicleText}${statusText}`;
}

export async function getCustomerHistory(number: string) {
  console.log(`[AI] Buscando dados do cliente, veiculos e historico para o numero: ${number}`);
  const headers = await getAuthHeaders();

  const cliente = await findCustomerByPhone(number);

  if (!cliente) return "Cliente nao encontrado na base de dados.";

  const [agendRes, veiculosRes] = await Promise.all([
    backendHttp.get(`/agendamentos/cliente/${cliente.id}`, { headers }),
    backendHttp.get(`/veiculos/cliente/${cliente.id}`, { headers }),
  ]);

  const history = (agendRes.data ?? []) as BackendAppointment[];
  const vehicles = (veiculosRes.data ?? []) as BackendVehicle[];

  const customerName = formatText(cliente.nome, 'Nome nao informado');
  const vehicleSummary = vehicles.length > 0
    ? vehicles.map(formatVehicleLine).join('\n')
    : 'Nenhum veiculo vinculado a este cliente.';
  const historySummary = history.length > 0
    ? history.map(formatAppointmentLine).join('\n')
    : 'Nao ha historico de atendimentos para este cliente.';

  return [
    `Dados cadastrais do cliente atual:`,
    `- Nome: ${customerName}`,
    `- Telefone: ${formatText(cliente.telefone, number)}`,
    '',
    'Veiculos vinculados ao cliente:',
    vehicleSummary,
    '',
    'Historico de atendimentos:',
    historySummary,
  ].join('\n');
}
