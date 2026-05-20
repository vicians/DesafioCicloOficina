import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { queryAgendamentos } from '../vectorstore/agendamentoVectorStore';
import { queryOrcamentos } from '../vectorstore/orcamentoVectorStore';
import { queryExecucoes } from '../vectorstore/execucaoServicoVectorStore';

/**
 * Ferramenta para busca semântica no histórico operacional (agendamentos, orçamentos e serviços em andamento).
 */
export const operationalSearchTool = (clienteId: string | null) => new DynamicStructuredTool({
  name: "operational_search_tool",
  description: "Busca semântica avançada em agendamentos, orçamentos e serviços em andamento do cliente atual. Use para buscar dados históricos não triviais (ex: 'orçamento de pastilha do mês passado'). Para datas exatas ou listagem simples, prefira a ferramenta get_customer_history.",
  schema: z.object({
    query: z.string().describe("O termo de busca ou pergunta do usuário em linguagem natural."),
    category: z.enum(['agendamentos', 'orcamentos', 'execucoes', 'all']).default('all').describe("A categoria de busca operacional.")
  }),
  func: async ({ query, category }) => {
    if (!clienteId) {
      return "Não é possível realizar busca operacional sem a identificação (ID) do cliente.";
    }

    try {
      const searchTasks: Promise<any>[] = [];

      if (category === 'all' || category === 'agendamentos') {
        searchTasks.push(queryAgendamentos(clienteId, query).then(res => res.length > 0 ? `📅 AGENDAMENTOS HISTÓRICOS:\n${res.join('\n')}` : null));
      }

      if (category === 'all' || category === 'orcamentos') {
        searchTasks.push(queryOrcamentos(clienteId, query).then(res => res.length > 0 ? `💰 ORÇAMENTOS:\n${res.join('\n')}` : null));
      }

      if (category === 'all' || category === 'execucoes') {
        searchTasks.push(queryExecucoes(clienteId, query).then(res => res.length > 0 ? `🔧 SERVIÇOS EM ANDAMENTO/HISTÓRICO:\n${res.join('\n')}` : null));
      }

      const rawResults = await Promise.all(searchTasks);
      const finalResults = rawResults.filter(Boolean);

      if (finalResults.length === 0) {
        return `Nenhum registro operacional encontrado para "${query}".`;
      }

      return finalResults.join('\n\n');
    } catch (error: any) {
      console.error('Erro na operationalSearchTool:', error);
      return "Erro ao acessar o histórico operacional detalhado.";
    }
  }
});
