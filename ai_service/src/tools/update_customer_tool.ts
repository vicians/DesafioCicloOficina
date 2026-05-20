import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { prisma } from '../config/prisma';
import {
  cleanCustomerName,
  isGenericCustomerName,
  isValidCustomerName,
  normalizePhone,
} from '../utils/customer_name';

type CustomerRow = {
  id: string;
  nome: string | null;
  telefone: string | null;
};

async function findCustomerByPhone(phoneNumber: string): Promise<CustomerRow | null> {
  const cleanPhone = normalizePhone(phoneNumber);
  if (!cleanPhone) return null;

  const phoneWithoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;

  const rows = await prisma.$queryRaw<CustomerRow[]>`
    SELECT id, nome, telefone
    FROM usuarios
    WHERE regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${cleanPhone}
       OR regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${phoneWithoutCountryCode}
    LIMIT 1
  `;

  return rows[0] ?? null;
}

export const updateCustomerNameTool = (phoneNumber: string) => new DynamicStructuredTool({
  name: 'update_customer_name',
  description:
    'Atualiza o nome cadastral do cliente atual do WhatsApp. Use imediatamente quando o cliente informar o nome real dele.',
  schema: z.object({
    nome: z
      .string()
      .trim()
      .min(2)
      .max(120)
      .describe('Nome real informado pelo cliente, sem telefone, placa, saudacao ou texto extra.'),
  }),
  func: async ({ nome }) => {
    const cleanedName = cleanCustomerName(nome);

    if (!isValidCustomerName(cleanedName, phoneNumber)) {
      return JSON.stringify({
        ok: false,
        error: 'Nome invalido. Peca o nome real do cliente, sem telefone, placa ou texto extra.',
      });
    }

    const customer = await findCustomerByPhone(phoneNumber);
    if (!customer) {
      return JSON.stringify({
        ok: false,
        error: 'Cliente atual nao encontrado pelo telefone do WhatsApp.',
      });
    }

    if (!isGenericCustomerName(customer.nome, customer.telefone) && customer.nome?.trim() === cleanedName) {
      return JSON.stringify({
        ok: true,
        updated: false,
        data: {
          id: customer.id,
          nome: customer.nome,
          telefone: customer.telefone,
        },
      });
    }

    const updated = await prisma.usuarios.update({
      where: { id: customer.id },
      data: { nome: cleanedName },
      select: {
        id: true,
        nome: true,
        telefone: true,
      },
    });

    return JSON.stringify({
      ok: true,
      updated: true,
      data: updated,
    });
  },
});
