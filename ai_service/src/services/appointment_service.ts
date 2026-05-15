import axios from 'axios';
import { CreateOsBody } from '../schemas/ai_schemas';
import { nextBusinessDay9am } from '../utils/date_utils';
import { extractBackendErrorMessage } from '../utils/backend_error';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const BACKEND_SERVICE_EMAIL = process.env.BACKEND_SERVICE_EMAIL;
const BACKEND_SERVICE_PASSWORD = process.env.BACKEND_SERVICE_PASSWORD;

let cachedBackendToken: string | null = null;
let backendTokenFetchedAt = 0;
const BACKEND_TOKEN_TTL_MS = 10 * 60 * 1000;

type AuthHeaders = { Authorization: string };
type MechanicCandidate = { id: string; nome: string };

async function getBackendAuthToken(): Promise<string> {
  const now = Date.now();

  if (cachedBackendToken && now - backendTokenFetchedAt < BACKEND_TOKEN_TTL_MS) {
    return cachedBackendToken;
  }

  if (!BACKEND_SERVICE_EMAIL || !BACKEND_SERVICE_PASSWORD) {
    throw new Error(
      'Configuração do ai_service incompleta: BACKEND_SERVICE_EMAIL e BACKEND_SERVICE_PASSWORD são obrigatórios para autenticar no backend.'
    );
  }

  const loginResponse = await axios.post(`${BACKEND_URL}/auth/login`, {
    email: BACKEND_SERVICE_EMAIL,
    senha: BACKEND_SERVICE_PASSWORD,
  });

  const token = loginResponse?.data?.token;
  if (!token) {
    throw new Error('Falha ao autenticar no backend: token ausente em /auth/login.');
  }

  cachedBackendToken = token;
  backendTokenFetchedAt = now;
  return token;
}

async function getAuthHeaders() {
  const token = await getBackendAuthToken();
  return { Authorization: `Bearer ${token}` };
}

async function findBudgetByAppointmentId(
  agendamentoId: string,
  headers: AuthHeaders
): Promise<string | null> {
  const existingOrcamentos = await axios.get(`${BACKEND_URL}/orcamentos`, { headers });
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
    const orcRes = await axios.post(`${BACKEND_URL}/orcamentos`, {
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
      const agendRes = await axios.post(`${BACKEND_URL}/agendamentos`, {
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

export async function createOsWorkflow(body: CreateOsBody & { services?: string[] }) {
  const { number, customerName, vehiclePlate, description, serviceType, services } = body;

  if (!number || !description) {
    throw new Error('number e description são obrigatórios');
  }

  // ── 1. Localizar ou criar cliente ─────────────────────────────────────────
  console.log(`[OS] 📝 Iniciando processo de criação para: ${number}`);
  let clienteId: string;
  let clienteTelefone: string = number;
  const headers = await getAuthHeaders();

  const usuariosRes = await axios.get(`${BACKEND_URL}/usuarios`, {
    params: { tipo_id: 2 },
    headers,
  });
  const todos: any[] = usuariosRes.data ?? [];
  const found = todos.find((u: any) => u.telefone === number);

  if (found) {
    clienteId = found.id;
    console.log(`[OS] Cliente encontrado: ${found.nome} (${clienteId})`);
  } else {
    console.log(`[OS] Cliente não encontrado. Criando novo registro...`);
    const temporaryPassword = `whatsapp_${number.replace(/\D/g, '').slice(-8)}_tmp`;
    const novoCliente = await axios.post(`${BACKEND_URL}/usuarios`, {
      tipo_id: 2,
      cpf_cnpj: number.replace(/\D/g, '').slice(0, 20),
      nome: customerName ?? `Cliente WhatsApp ${number}`,
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

  if (!vehiclePlate) {
    throw new Error('Placa do veículo é obrigatória para criar a OS. Por favor, informe a placa.');
  }

  const veiculosRes = await axios.get(`${BACKEND_URL}/veiculos`, { headers });
  const veiculos: any[] = veiculosRes.data ?? [];
  const veiculoFound = veiculos.find(
    (v: any) => v.placa.toUpperCase() === vehiclePlate.toUpperCase()
  );

  if (veiculoFound) {
    veiculoId = veiculoFound.id;
    console.log(`[OS] Veículo encontrado: ${vehiclePlate} (${veiculoId})`);
  } else {
    console.log(`[OS] Veículo não encontrado. Cadastrando placa ${vehiclePlate}...`);
    const novoVeiculo = await axios.post(`${BACKEND_URL}/veiculos`, {
      cliente_id: clienteId,
      placa: vehiclePlate.toUpperCase(),
      marca: 'Não informado',
      modelo: 'Não informado',
      ano: new Date().getFullYear(),
      quilometragem_atual: 0,
    }, {
      headers,
    });
    veiculoId = novoVeiculo.data.id;
    console.log(`[OS] Novo veículo criado: ${vehiclePlate} (${veiculoId})`);
  }

  // ── 3. Selecionar mecânico disponível ─────────────────────────────────────
  let mecanicos: MechanicCandidate[] = [];

  try {
    const mecanicosRes = await axios.get(`${BACKEND_URL}/usuarios`, {
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

  // ── 4. Criar agendamento (próximo dia útil às 09:00) ─────────────────────
  const agendadoPara = nextBusinessDay9am();
  const data = agendadoPara.toISOString().slice(0, 10);
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
    const catalogoRes = await axios.get(`${BACKEND_URL}/servicos`, { headers });
    const catalogo: any[] = catalogoRes.data ?? [];

    for (const sName of services) {
      const match = catalogo.find(s => 
        s.nome.toLowerCase().includes(sName.toLowerCase()) || 
        sName.toLowerCase().includes(s.nome.toLowerCase())
      );

      if (match) {
        try {
          await axios.post(`${BACKEND_URL}/orcamentos/${orcamentoId}/servicos`, {
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
    const mlRes = await axios.post(`${BACKEND_URL}/auth/magic-link`, {
      telefone: clienteTelefone,
    });
    magicLinkUrl = mlRes.data.url;
  } catch (err) {}

  return {
    agendamento_id: agendamentoId,
    orcamento_id: orcamentoId,
    mechanic: { id: mecanicoId, nome: mecanicoNome },
    agendado_para: agendadoPara.toISOString(),
    magic_link_url: magicLinkUrl,
    message: magicLinkUrl
      ? `Agendamento e Orçamento criados com sucesso! Acesse pelo link: ${magicLinkUrl}`
      : 'Agendamento criado! Entre em contato para detalhes do orçamento.',
  };
}

export async function checkAvailability(date: string) {
  console.log(`[AI] Consultando disponibilidade para: ${date}`);
  const headers = await getAuthHeaders();
  const res = await axios.get(`${BACKEND_URL}/agendamentos`, { headers });
  const all: any[] = res.data ?? [];
  
  const targetDate = new Date(date);
  const dailySchedules = all.filter(a => {
    const d = new Date(a.agendado_para);
    return d.getFullYear() === targetDate.getFullYear() &&
           d.getMonth() === targetDate.getMonth() &&
           d.getDate() === targetDate.getDate();
  });

  if (dailySchedules.length === 0) {
    return "O dia está totalmente livre. Atendemos das 08:00 às 18:00.";
  }

  const occupied = dailySchedules.map(a => {
    const start = new Date(a.agendado_para);
    const end = new Date(start.getTime() + a.duracao_total_minutos * 60000);
    return `${start.toLocaleTimeString('pt-BR', {hour:'2-digit', minute:'2-digit'})} - ${end.toLocaleTimeString('pt-BR', {hour:'2-digit', minute:'2-digit'})}`;
  });

  return `Horários já ocupados em ${targetDate.toLocaleDateString('pt-BR')}: \n${occupied.join('\n')}\nOs demais horários entre 08:00 e 18:00 estão disponíveis.`;
}

type BackendCustomer = {
  id: string;
  nome?: string;
  telefone?: string;
};

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

  const usuariosRes = await axios.get(`${BACKEND_URL}/usuarios`, { params: { tipo_id: 2 }, headers });
  const cliente = ((usuariosRes.data ?? []) as BackendCustomer[])
    .find((u) => u.telefone === number);

  if (!cliente) return "Cliente nao encontrado na base de dados.";

  const [agendRes, veiculosRes] = await Promise.all([
    axios.get(`${BACKEND_URL}/agendamentos/cliente/${cliente.id}`, { headers }),
    axios.get(`${BACKEND_URL}/veiculos/cliente/${cliente.id}`, { headers }),
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
