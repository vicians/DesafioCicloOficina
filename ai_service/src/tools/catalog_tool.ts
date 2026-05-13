import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { queryProdutos } from '../vectorstore/productVectorStore';
import { queryServicos } from '../vectorstore/serviceVectorStore';
import { queryDocuments } from '../vectorstore/documentVectorStore';

/**
 * Ferramenta modular para consulta ao catálogo e documentos técnicos.
 * Projetada para ser extensível, permitindo a adição de novas fontes de dados
 * sem alterar a interface do Agente.
 */
export const catalogTool = new DynamicStructuredTool({
  name: "catalog_search_tool",
  description: "Consulta o catálogo de produtos, serviços e manuais técnicos da CicloOficina. Use para buscar preços, disponibilidade e informações técnicas.",
  schema: z.object({
    query: z.string().describe("O termo de busca ou pergunta do usuário em linguagem natural."),
    category: z.enum(['all', 'products', 'services', 'manuals']).default('all').describe("Categoria específica de busca (opcional).")
  }),
  func: async ({ query, category }) => {
    try {
      const results: string[] = [];

      // Execução paralela das buscas para performance
      const searchTasks: Promise<any>[] = [];

      if (category === 'all' || category === 'products') {
        searchTasks.push(queryProdutos(query).then(res => res.length > 0 ? `📦 PRODUTOS:\n${res.join('\n')}` : null));
      }

      if (category === 'all' || category === 'services') {
        searchTasks.push(queryServicos(query).then(res => res.length > 0 ? `🛠️ SERVIÇOS:\n${res.join('\n')}` : null));
      }

      if (category === 'all' || category === 'manuals') {
        searchTasks.push(queryDocuments(query).then(res => res.length > 0 ? `📄 MANUAIS/POLÍTICAS:\n${res.map(d => `- ${d.content}`).join('\n')}` : null));
      }

      const rawResults = await Promise.all(searchTasks);
      
      // Filtra nulos e concatena
      const finalResults = rawResults.filter(Boolean);

      if (finalResults.length === 0) {
        return `Nenhuma informação encontrada para "${query}" no catálogo atual.`;
      }

      return finalResults.join('\n\n');
    } catch (error: any) {
      console.error('Erro na catalogTool:', error);
      return "Erro ao acessar o catálogo de informações.";
    }
  }
});
