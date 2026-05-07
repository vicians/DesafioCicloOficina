import axios from 'axios';
import { CreateOsBody } from '../schemas/ai_schemas';
import { nextBusinessDay9am } from '../utils/date_utils';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export async function createOsWorkflow(body: CreateOsBody) {
  const { number, customerName, vehiclePlate, description, serviceType } = body;

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
      cpf_cnpj: number.replace(/\D/g, '').slice(0, 20), // Garante formato válido para o banco
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
    } else {
      console.warn('[OS] Nenhum mecânico disponível — OS criada sem atribuição');
    }
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível buscar mecânicos:', err.message);
  }

  // ── 4. Criar agendamento (próximo dia útil às 09:00) ─────────────────────
  let agendamentoId: string;
  const agendadoPara = nextBusinessDay9am();

  const agendRes = await axios.post(`${BACKEND_URL}/agendamentos`, {
    cliente_id: clienteId,
    veiculo_id: veiculoId,
    funcionario_id: mecanicoId,
    agendado_para: agendadoPara.toISOString(),
    duracao_total_minutos: 60,
    notas_cliente: `[WhatsApp] ${serviceType ?? ''} — ${description}`.trim(),
  });
  agendamentoId = agendRes.data.id;
  console.log(`[OS] Agendamento criado: ${agendamentoId}`);

  // ── 5. Criar orçamento (rascunho) ─────────────────────────────────────────
  let orcamentoId: string;
  const orcRes = await axios.post(`${BACKEND_URL}/orcamentos`, {
    agendamento_id: agendamentoId,
    cliente_id: clienteId,
    funcionario_id: mecanicoId,
  });
  orcamentoId = orcRes.data.id;
  console.log(`[OS] Orçamento criado: ${orcamentoId}`);

  // ── 6. Gerar magic link para o cliente ────────────────────────────────────
  let magicLinkUrl: string | null = null;

  try {
    const mlRes = await axios.post(`${BACKEND_URL}/auth/magic-link`, {
      telefone: clienteTelefone,
    });
    magicLinkUrl = mlRes.data.url;
    console.log(`[OS] Magic link gerado: ${magicLinkUrl}`);
  } catch (err: any) {
    console.warn('[OS] Aviso: não foi possível gerar magic link:', err.response?.data ?? err.message);
  }

  return {
    agendamento_id: agendamentoId,
    orcamento_id: orcamentoId,
    mechanic: { id: mecanicoId, nome: mecanicoNome },
    agendado_para: agendadoPara.toISOString(),
    magic_link_url: magicLinkUrl,
    message: magicLinkUrl
      ? `OS criada com sucesso! Acesse o app pelo link: ${magicLinkUrl}`
      : 'OS criada com sucesso! Entre em contato para obter acesso ao app.',
  };
}