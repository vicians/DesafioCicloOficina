import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';
import { prisma } from '../config/prisma';
import { normalizePhone } from '../utils/customer_name';
import { looksLikeBrazilianLicensePlate, normalizeLicensePlate } from '../utils/contextual_entities';

type CustomerRow = {
  id: string;
  nome: string | null;
  telefone: string | null;
  cpf_cnpj: string | null;
};

async function findCustomerByPhone(phoneNumber: string): Promise<CustomerRow | null> {
  const cleanPhone = normalizePhone(phoneNumber);
  if (!cleanPhone) return null;

  const phoneWithoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;

  const rows = await prisma.$queryRaw<CustomerRow[]>`
    SELECT id, nome, telefone, cpf_cnpj
    FROM usuarios
    WHERE regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${cleanPhone}
       OR regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${phoneWithoutCountryCode}
    LIMIT 1
  `;

  return rows[0] ?? null;
}

export const updateVehicleTool = (phoneNumber: string) => new DynamicStructuredTool({
  name: 'update_vehicle',
  description: 'Atualiza ou cadastra os dados de um veículo (marca, modelo, ano e quilometragem) associado ao cliente do WhatsApp. Use sempre que o cliente informar qualquer um desses dados.',
  schema: z.object({
    placa: z
      .string()
      .trim()
      .describe('Placa do veículo (obrigatório, ex: ABC1D23 ou ABC1234).'),
    marca: z
      .string()
      .trim()
      .optional()
      .describe('Marca do veículo (ex: Ford, Chevrolet, Fiat).'),
    modelo: z
      .string()
      .trim()
      .optional()
      .describe('Modelo do veículo (ex: Fiesta, Onix, Uno).'),
    ano: z
      .number()
      .int()
      .optional()
      .describe('Ano de fabricação do veículo (ex: 2018).'),
    quilometragem: z
      .number()
      .int()
      .optional()
      .describe('Quilometragem atual/acumulada do veículo (ex: 45000).'),
  }),
  func: async ({ placa, marca, modelo, ano, quilometragem }) => {
    const customer = await findCustomerByPhone(phoneNumber);
    if (!customer) {
      return JSON.stringify({
        ok: false,
        error: 'Cliente atual nao encontrado pelo telefone do WhatsApp.',
      });
    }

    if (!placa) {
      return JSON.stringify({
        ok: false,
        error: 'A placa do veiculo e obrigatoria para identificar o registro.',
      });
    }

    const normalizedPlate = normalizeLicensePlate(placa);
    if (!looksLikeBrazilianLicensePlate(normalizedPlate)) {
      return JSON.stringify({
        ok: false,
        error: 'Placa informada invalida. O formato esperado e ABC1D23 ou ABC1234.',
      });
    }

    if (marca === undefined && modelo === undefined && ano === undefined && quilometragem === undefined) {
      return JSON.stringify({
        ok: false,
        error: 'Pelo menos um campo (marca, modelo, ano ou quilometragem) deve ser informado para atualizacao.',
      });
    }

    const existingVehicleWithPlate = await prisma.veiculos.findUnique({
      where: { placa: normalizedPlate },
    });

    if (existingVehicleWithPlate && existingVehicleWithPlate.cliente_id !== customer.id) {
      return JSON.stringify({
        ok: false,
        error: 'A placa informada ja esta vinculada a outro cadastro.',
      });
    }

    let vehicle;
    if (existingVehicleWithPlate) {
      const updateData: any = {};
      if (marca !== undefined) updateData.marca = marca;
      if (modelo !== undefined) updateData.modelo = modelo;
      if (ano !== undefined) updateData.ano = ano;
      if (quilometragem !== undefined) updateData.quilometragem_atual = quilagemToNumber(quilometragem);

      vehicle = await prisma.veiculos.update({
        where: { id: existingVehicleWithPlate.id },
        data: updateData,
      });
    } else {
      vehicle = await prisma.veiculos.create({
        data: {
          cliente_id: customer.id,
          placa: normalizedPlate,
          marca: marca || 'Nao informado',
          modelo: modelo || 'Nao informado',
          ano: ano || new Date().getFullYear(),
          quilometragem_atual: quilometragem !== undefined ? quilagemToNumber(quilometragem) : 0,
        },
      });
    }

    return JSON.stringify({
      ok: true,
      updated: true,
      data: vehicle,
    });
  },
});

function quilagemToNumber(val: number | null | undefined): number {
  if (val === null || val === undefined) return 0;
  return Math.max(0, val);
}
