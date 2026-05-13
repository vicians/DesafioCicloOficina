import axios from 'axios';
import { CreateOsBody } from '../schemas/ai_schemas';
import { nextBusinessDay9am } from '../utils/date_utils';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export async function createOsWorkflow(body: CreateOsBody & { services?: string[] }) {
  const { number, customerName, vehiclePlate, description, serviceType, services } = body;

  if (!number || !description) {
    throw new Error('number e description são obrigatórios');
  }

  // ── 1. Localizar ou criar cliente ─────────────────────────────────────────
  console.log(`[OS] 📝 Iniciando processo de criação para: ${number}`);
  let clienteId: string;
  let clienteTelefone: string = number;

  const usuariosRes = await axios.get(`${BACKEND_URL}/usuarios`, {
    params: { tipo_id: 2 },
  });
  const todos: any[] = usuariosRes.data ?? [];
  const found = todos.find((u: any) => u.telefone === number);

  if (found) {
    clienteId = found.id;
    console.log(`[OS] Cliente encontrado: ${found.nome} (${clienteId})`);
  } else {
    console.log(`[OS] Cliente não encontrado. Criando novo registro...`);
    const novoCliente = await axios.post(`${BACKEND_URL}/usuarios`, {
      tipo_id: 2,
      cpf_cnpj: number.replace(/\D/g, '').slice(0, 20),
      nome: customerName ?? `Cliente WhatsApp ${number}`,
      telefone: number,
    });
    clienteId = novoCliente.data.id;
    console.log(`[OS] Novo cliente criado: ${clienteId}`);
  }

  // ── 2. Localizar ou criar veículo ─────────────────────────────────────────
  let veiculoId: string;

  if (!vehiclePlate) {
    throw new Error('Placa do veículo é obrigatória para criar a OS. Por favor, informe a placa.');
  }

  const veiculosRes = await axios.get(`${BACKEND_URL}/veiculos`);
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
    });
    veiculoId = novoVeiculo.data.id;
    console.log(`[OS] Novo veículo criado: ${vehiclePlate} (${veiculoId})`);
  }

  // ── 3. Selecionar mecânico disponível ─────────────────────────────────────
  let mecanicoId: string | null = null;
  let mecanicoNome: string = 'A definir';

  try {
    const mecanicosRes = await axios.get(`${BACKEND_URL}/usuarios`, {
      params: { tipo_id: 3 },
    });
    const mecanicos: any[] = mecanicosRes.data ?? [];
    if (mecanicos.length > 0) {
      mecanicoId = mecanicos[0].id;
      mecanicoNome = mecanicos[0].nome;
      console.log(`[OS] Mecânico atribuído: ${mecanicoNome} (${mecanicoId})`);
    }
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível buscar mecânicos:', err.message);
  }

  // ── 4. Criar agendamento (próximo dia útil às 09:00) ─────────────────────
  const agendadoPara = nextBusinessDay9am();

  const agendRes = await axios.post(`${BACKEND_URL}/agendamentos`, {
    cliente_id: clienteId,
    veiculo_id: veiculoId,
    funcionario_id: mecanicoId,
    agendado_para: agendadoPara.toISOString(),
    duracao_total_minutos: 60,
    notas_cliente: `[WhatsApp] ${serviceType ?? ''} — ${description}`.trim(),
  });
  const agendamentoId = agendRes.data.id;
  console.log(`[OS] Agendamento criado: ${agendamentoId}`);

  // ── 5. Criar orçamento (rascunho) ─────────────────────────────────────────
  const orcRes = await axios.post(`${BACKEND_URL}/orcamentos`, {
    agendamento_id: agendamentoId,
    cliente_id: clienteId,
    funcionario_id: mecanicoId,
  });
  const orcamentoId = orcRes.data.id;
  console.log(`[OS] Orçamento criado: ${orcamentoId}`);

  // ── 6. Adicionar serviços identificados ───────────────────────────────────
  if (services && services.length > 0) {
    console.log(`[OS] 🛠️ Adicionando serviços identificados: ${services.join(', ')}`);
    const catalogoRes = await axios.get(`${BACKEND_URL}/servicos`);
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
          });
          console.log(`[OS] Serviço adicionado: ${match.nome}`);
        } catch (err: any) {
          console.error(`[OS] Erro ao adicionar serviço ${match.nome}:`, err.message);
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
  const res = await axios.get(`${BACKEND_URL}/agendamentos`);
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

export async function getCustomerHistory(number: string) {
  console.log(`[AI] Buscando histórico para o número: ${number}`);
  
  const usuariosRes = await axios.get(`${BACKEND_URL}/usuarios`, { params: { tipo_id: 2 } });
  const cliente = (usuariosRes.data ?? []).find((u: any) => u.telefone === number);

  if (!cliente) return "Cliente não encontrado na base de dados.";

  const agendRes = await axios.get(`${BACKEND_URL}/agendamentos/cliente/${cliente.id}`);
  const history: any[] = agendRes.data ?? [];

  if (history.length === 0) return "Não há histórico de atendimentos para este cliente.";

  const summary = history.map(h => {
    const data = new Date(h.agendado_para).toLocaleDateString('pt-BR');
    return `- ${data}: ${h.notas_cliente || 'Sem descrição'}`;
  }).join('\n');

  return `Histórico de atendimentos do cliente ${cliente.nome}:\n${summary}`;
}