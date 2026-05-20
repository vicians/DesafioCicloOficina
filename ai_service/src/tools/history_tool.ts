import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { getCustomerHistory } from '../services/appointment_service';

export const historyTool = (phoneNumber: string) => new DynamicStructuredTool({
  name: "get_customer_history",
  description: "Recupera dados cadastrais, veiculos vinculados (placa, marca e modelo) e historico de servicos/agendamentos do cliente atual.",
  schema: z.object({}),
  func: async () => {
    try {
      return await getCustomerHistory(phoneNumber);
    } catch (error: any) {
      return `Erro ao buscar dados do cliente: ${error.message}`;
    }
  }
});
