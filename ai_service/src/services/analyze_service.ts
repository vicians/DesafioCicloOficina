import { prisma } from '../config/prisma';
import { model } from '../config/ai_model';
import { queryProdutos } from '../vectorstore/productVectorStore';
import { queryServicos } from '../vectorstore/serviceVectorStore';
import { getTools } from '../tools';
import { HumanMessage, SystemMessage, ToolMessage } from '@langchain/core/messages';

import dotenv from 'dotenv';
dotenv.config();

const MAX_TOOL_ROUNDS = 3;

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

  // 1. Identificar status do cliente
  let customer = await prisma.usuarios.findUnique({
    where: { telefone: number },
  });

  if (customer && customer.tipo_id !== 2) {
    return {
      result: null,
      action: 'MANUAL_WAIT',
      info: 'O atendimento está sendo realizado por um humano.',
    };
  }

  // 2. Consultar RAG (Produtos + Serviços)
  const [ragProdutos, ragServicos] = await Promise.all([
    queryProdutos(message),
    queryServicos(message)
  ]);

  const contextBlock = `
CATÁLOGO DE PRODUTOS:
${ragProdutos.length > 0 ? ragProdutos.map(d => `- ${d}`).join('\n') : 'Nenhum produto relevante encontrado.'}

CATÁLOGO DE SERVIÇOS:
${ragServicos.length > 0 ? ragServicos.map(d => `- ${d}`).join('\n') : 'Nenhum serviço relevante encontrado.'}
`;

  // 3. Configurar Agent/Tools
  const tools = getTools(number, message);
  const modelWithTools = model.bindTools(tools);

  const messages: any[] = [
    new SystemMessage(`És o assistente virtual da CicloOficina.
Objetivos:
1. Ajudar clientes com informações sobre produtos, preços e serviços.
2. Identificar serviços desejados no CATÁLOGO DE SERVIÇOS e usá-los ao criar agendamentos.
3. Facilitar agendamentos e consultas de disponibilidade.

Regras:
- Nunca invente preços. Use apenas o que está no contexto.
- Se o cliente quiser agendar, use a ferramenta 'create_appointment' ou 'backend_api' quando precisar consultar ou registrar dados no backend.
- Se identificar um serviço específico do catálogo (ex: Troca de óleo), passe-o no parâmetro 'services'.
- Quando uma ferramenta retornar dados estruturados, use esses dados para redigir a resposta final. Nunca devolva JSON cru ao cliente.
- Se faltarem dados obrigatórios para executar uma ação, peça somente os dados faltantes.
- Responda sempre em português, de forma cordial e profissional.

CONTEXTO ATUAL:
${contextBlock}`),
    new HumanMessage(message)
  ];

  // 4. Execução do Loop de IA
  console.log(`[AI Service] 🤖 Processando com NVIDIA NIM e Tools...`);
  let response = await modelWithTools.invoke(messages);

  // Se houver chamadas de ferramentas, executamos em rodadas limitadas.
  for (let round = 0; round < MAX_TOOL_ROUNDS; round += 1) {
    if (!response.tool_calls || response.tool_calls.length === 0) {
      break;
    }

    messages.push(response);

    for (const toolCall of response.tool_calls) {
      const tool = tools.find(t => t.name === toolCall.name);
      if (tool) {
        console.log(`[AI Service] 🛠️ Executando ferramenta: ${toolCall.name}`);
        const toolResult = await (tool as any).call(toolCall.args);
        messages.push(new ToolMessage({
          tool_call_id: toolCall.id!,
          content: typeof toolResult === 'string' ? toolResult : JSON.stringify(toolResult)
        }));
      }
    }

    response = await modelWithTools.invoke(messages);
  }

  const finalContent = normalizeAssistantReply(String(response.content));
  
  // O retorno segue o padrão esperado pelo frontend/whatsapp
  return { 
    result: finalContent, 
    action: 'REPLY' 
  };
}