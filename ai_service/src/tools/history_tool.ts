import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { getCustomerHistory } from '../services/appointment_service';

export const historyTool = (phoneNumber: string) => new DynamicStructuredTool({
  name: "get_customer_history",
  description: "Recupera o histórico de serviços e agendamentos anteriores do cliente atual.",
  schema: z.object({}),
  func: async () => {
    try {
      return await getCustomerHistory(phoneNumber);
    } catch (error: any) {
      return `Erro ao buscar histórico: ${error.message}`;
    }
  }
});
