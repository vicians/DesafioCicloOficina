import { appointmentTool } from './appointment_tool';
import { availabilityTool } from './availability_tool';
import { historyTool } from './history_tool';
import { catalogTool } from './catalog_tool';
import { backendApiTool } from './backend_api_tool';
import { operationalSearchTool } from './operational_search_tool';

export const getTools = (phoneNumber: string, message: string, clienteId?: string) => [
  appointmentTool(phoneNumber, message),
  availabilityTool,
  historyTool(phoneNumber),
  catalogTool,
  backendApiTool,
  operationalSearchTool(clienteId ?? null),
];
