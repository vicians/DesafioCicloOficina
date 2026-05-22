import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { createOsWorkflow, recoverRecentOsWorkflow } from '../services/appointment_service';
import { formatBackendValidationError } from '../utils/backend_error';
import { isValidRequestedAppointmentDate } from '../utils/date_utils';

function normalizeServices(value: string | string[]): string[] {
  const rawItems = Array.isArray(value) ? value : [value];

  return rawItems
    .flatMap((item) => {
      const trimmed = item.trim();

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        return trimmed
          .slice(1, -1)
          .split(',')
          .map((part) => part.trim().replace(/^['"]|['"]$/g, ''))
          .filter(Boolean);
      }

      return trimmed.replace(/^['"]|['"]$/g, '');
    })
    .filter(Boolean);
}

export const appointmentTool = (phoneNumber: string, fallbackDescription: string) => new DynamicStructuredTool({
  name: "create_appointment",
  description: "Cria um agendamento para um cliente. Use quando o cliente solicitar agendamento ou orçamento.",
  schema: z.object({
    customerName: z.string().optional().describe("Nome do cliente"),
    vehiclePlate: z.string().describe("Placa do veículo"),
    description: z.string().optional().describe("Descrição do problema ou serviço solicitado"),
    serviceType: z.string().optional().describe("Tipo de serviço (Mecânica ou Borracharia)"),
    requestedDate: z
      .string()
      .trim()
      .refine((value) => value.length === 0 || isValidRequestedAppointmentDate(value), {
        message: "requestedDate deve ser uma data util atual ou futura no formato YYYY-MM-DD"
      })
      .optional()
      .describe("Data desejada para o agendamento no formato YYYY-MM-DD. Nao use datas passadas nem fins de semana."),
    services: z
      .union([z.string(), z.array(z.string())])
      .transform((value) => normalizeServices(value))
      .optional()
      .describe("Lista de nomes de serviços do catálogo identificados (ex: ['Troca de óleo', 'Alinhamento'])")
  }),
  func: async (input) => {
    const startedAt = new Date();

    try {
      const description = input.description?.trim() || fallbackDescription;

      const result = await createOsWorkflow({
        ...input,
        description,
        number: phoneNumber
      });
      return JSON.stringify(result);
    } catch (error: any) {
      const description = input.description?.trim() || fallbackDescription;
      const recovered = await recoverRecentOsWorkflow({
        ...input,
        description,
        number: phoneNumber
      }, startedAt);

      if (recovered) {
        return JSON.stringify(recovered);
      }

      return formatBackendValidationError(error, 'Erro desconhecido ao criar agendamento');
    }
  }
});
