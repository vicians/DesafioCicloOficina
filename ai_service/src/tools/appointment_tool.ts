import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { createOsWorkflow } from '../services/appointment_service';

export const appointmentTool = (phoneNumber: string) => new DynamicStructuredTool({
  name: "create_appointment",
  description: "Cria um agendamento e uma ordem de serviço (orçamento) para um cliente. Use quando o cliente solicitar explicitamente um agendamento.",
  schema: z.object({
    customerName: z.string().optional().describe("Nome do cliente"),
    vehiclePlate: z.string().describe("Placa do veículo"),
    description: z.string().describe("Descrição do problema ou serviço solicitado"),
    serviceType: z.string().optional().describe("Tipo de serviço (Mecânica ou Borracharia)"),
    services: z.array(z.string()).optional().describe("Lista de nomes de serviços do catálogo identificados (ex: ['Troca de óleo', 'Alinhamento'])")
  }),
  func: async (input) => {
    try {
      const result = await createOsWorkflow({
        ...input,
        number: phoneNumber
      });
      return JSON.stringify(result);
    } catch (error: any) {
      return `Erro ao criar agendamento: ${error.message}`;
    }
  }
});
