import { appointmentTool } from './appointment_tool';
import { availabilityTool } from './availability_tool';
import { historyTool } from './history_tool';
import { catalogTool } from './catalog_tool';

export const getTools = (phoneNumber: string) => [
  appointmentTool(phoneNumber),
  availabilityTool,
  historyTool(phoneNumber),
  catalogTool
];
