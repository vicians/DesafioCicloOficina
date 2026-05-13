import axios from 'axios';
import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

const allowedEndpointPatterns: RegExp[] = [
  /^\/usuarios$/,
  /^\/veiculos$/,
  /^\/agendamentos$/,
  /^\/agendamentos\/cliente\/[0-9a-fA-F-]+$/,
  /^\/orcamentos$/,
  /^\/orcamentos\/[0-9a-fA-F-]+\/servicos$/,
  /^\/servicos$/,
  /^\/auth\/magic-link$/,
];

function isAllowedEndpoint(endpoint: string): boolean {
  return allowedEndpointPatterns.some((pattern) => pattern.test(endpoint));
}

export const backendApiTool = new DynamicStructuredTool({
  name: 'backend_api',
  description:
    'Ferramenta dedicada para chamadas HTTP ao backend da oficina. Use para GET/POST nos endpoints permitidos.',
  schema: z.object({
    method: z.enum(['GET', 'POST']).describe('Método HTTP da requisição.'),
    endpoint: z
      .string()
      .describe('Endpoint relativo do backend (ex: /usuarios, /agendamentos, /orcamentos).'),
    params: z
      .record(z.union([z.string(), z.number(), z.boolean()]))
      .optional()
      .describe('Query params para requisições GET.'),
    body: z.record(z.any()).optional().describe('Payload JSON para requisições POST.'),
  }),
  func: async ({ method, endpoint, params, body }) => {
    if (!isAllowedEndpoint(endpoint)) {
      return JSON.stringify({
        ok: false,
        error: `Endpoint não permitido: ${endpoint}`,
      });
    }

    try {
      const response = await axios.request({
        method,
        baseURL: BACKEND_URL,
        url: endpoint,
        params,
        data: body,
        timeout: 10000,
      });

      return JSON.stringify({
        ok: true,
        status: response.status,
        data: response.data,
      });
    } catch (error: any) {
      return JSON.stringify({
        ok: false,
        status: error?.response?.status ?? 500,
        error: error?.response?.data?.error ?? error?.message ?? 'Erro desconhecido no backend_api',
      });
    }
  },
});
