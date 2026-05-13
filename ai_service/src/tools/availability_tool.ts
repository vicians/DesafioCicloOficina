import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { checkAvailability } from '../services/appointment_service';

export const availabilityTool = new DynamicStructuredTool({
  name: "check_availability",
  description: "Consulta horários disponíveis para agendamento em uma data específica.",
  schema: z.object({
    date: z.string().describe("Data para consulta (ex: '2026-05-10')")
  }),
  func: async ({ date }) => {
    try {
      return await checkAvailability(date);
    } catch (error: any) {
      return `Erro ao consultar disponibilidade: ${error.message}`;
    }
  }
});
