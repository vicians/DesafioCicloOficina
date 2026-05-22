import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import axios from 'axios';
import { prisma } from '../config/prisma';
import {
  cleanCustomerName,
  isGenericCustomerName,
  isValidCustomerName,
  normalizePhone,
  cleanEmail,
  isValidEmail,
  cleanCpfCnpj,
  isValidCpfCnpj,
} from '../utils/customer_name';

type CustomerRow = {
  id: string;
  nome: string | null;
  telefone: string | null;
  cpf_cnpj: string | null;
  email: string | null;
};

async function findCustomerByPhone(phoneNumber: string): Promise<CustomerRow | null> {
  const cleanPhone = normalizePhone(phoneNumber);
  if (!cleanPhone) return null;

  const phoneWithoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;

  const rows = await prisma.$queryRaw<CustomerRow[]>`
    SELECT id, nome, telefone, cpf_cnpj, email
    FROM usuarios
    WHERE regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${cleanPhone}
       OR regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${phoneWithoutCountryCode}
    LIMIT 1
  `;

  return rows[0] ?? null;
}

export const updateCustomerTool = (phoneNumber: string) => new DynamicStructuredTool({
  name: 'update_customer',
  description: 'Atualiza os dados cadastrais (nome, email ou CPF/CNPJ) do cliente do WhatsApp. Use assim que o cliente informar qualquer um desses dados.',
  schema: z.object({
    nome: z
      .string()
      .trim()
      .optional()
      .describe('Nome real do cliente, sem placa, saudacao ou texto extra.'),
    email: z
      .string()
      .trim()
      .optional()
      .describe('Email do cliente.'),
    cpf_cnpj: z
      .string()
      .trim()
      .optional()
      .describe('CPF ou CNPJ do cliente, apenas numeros.'),
  }),
  func: async ({ nome, email, cpf_cnpj }) => {
    const customer = await findCustomerByPhone(phoneNumber);
    if (!customer) {
      return JSON.stringify({
        ok: false,
        error: 'Cliente atual nao encontrado pelo telefone do WhatsApp.',
      });
    }

    if (nome === undefined && email === undefined && cpf_cnpj === undefined) {
      return JSON.stringify({
        ok: false,
        error: 'Pelo menos um campo (nome, email ou cpf_cnpj) deve ser informado para atualizacao.',
      });
    }

    let cleanedName: string | undefined = undefined;
    if (nome !== undefined) {
      cleanedName = cleanCustomerName(nome);
      if (!isValidCustomerName(cleanedName, phoneNumber)) {
        return JSON.stringify({
          ok: false,
          error: 'Nome invalido. Peca o nome real do cliente, sem telefone, placa ou texto extra.',
        });
      }
    }

    let cleanedCpfCnpj: string | undefined = undefined;
    if (cpf_cnpj !== undefined) {
      cleanedCpfCnpj = cleanCpfCnpj(cpf_cnpj);
      if (!isValidCpfCnpj(cleanedCpfCnpj)) {
        return JSON.stringify({
          ok: false,
          error: 'CPF ou CNPJ invalido. O CPF deve conter 11 digitos e o CNPJ 14 digitos.',
        });
      }

      const existingCpfOwnerRows = await prisma.$queryRaw<Array<{ id: string }>>`
        SELECT id
        FROM usuarios
        WHERE regexp_replace(COALESCE(cpf_cnpj, ''), '\\D', '', 'g') = ${cleanedCpfCnpj}
        LIMIT 1
      `;
      const existingCpfOwner = existingCpfOwnerRows[0] ?? null;
      if (existingCpfOwner && existingCpfOwner.id !== customer.id) {
        return JSON.stringify({
          ok: false,
          error: 'O CPF ou CNPJ informado ja pertence a outro cadastro.',
        });
      }
    }

    let cleanedEmail: string | undefined = undefined;
    if (email !== undefined) {
      cleanedEmail = cleanEmail(email);
      if (!isValidEmail(cleanedEmail)) {
        return JSON.stringify({
          ok: false,
          error: 'Formato de e-mail invalido.',
        });
      }

      const existingEmailUser = await prisma.usuarios.findUnique({
        where: { email: cleanedEmail },
      });
      if (existingEmailUser && existingEmailUser.id !== customer.id) {
        return JSON.stringify({
          ok: false,
          error: 'O e-mail informado ja esta em uso por outro usuario.',
        });
      }
    }

    let pin: string | undefined = undefined;
    if (cleanedEmail !== undefined && !customer.email) {
      pin = Math.floor(100000 + Math.random() * 900000).toString();
    }

    const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
    const headers = { 'X-Internal-Token': process.env.INTERNAL_AUTH_TOKEN || '' };
    const updateBody: any = {};

    if (cleanedName !== undefined) {
      updateBody.nome = cleanedName;
    }
    if (cleanedEmail !== undefined) {
      updateBody.email = cleanedEmail;
    }
    if (pin !== undefined) {
      updateBody.senha = pin;
    }

    try {
      if (Object.keys(updateBody).length > 0) {
        await axios.put(`${BACKEND_URL}/usuarios/${customer.id}`, updateBody, { headers });
      }

      if (cleanedCpfCnpj !== undefined) {
        await prisma.usuarios.update({
          where: { id: customer.id },
          data: { cpf_cnpj: cleanedCpfCnpj },
        });
      }
    } catch (error: any) {
      const errMsg = error?.response?.data?.error || error?.message || 'Erro ao atualizar dados.';
      return JSON.stringify({
        ok: false,
        error: errMsg,
      });
    }

    const updatedCustomer = await prisma.usuarios.findUnique({
      where: { id: customer.id },
      select: {
        id: true,
        nome: true,
        telefone: true,
        email: true,
        cpf_cnpj: true,
      },
    });

    return JSON.stringify({
      ok: true,
      updated: true,
      data: updatedCustomer,
      temp_pin: pin,
    });
  },
});
