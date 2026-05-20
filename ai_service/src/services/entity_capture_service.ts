import { prisma } from '../config/prisma';
import { ContextualEntity } from '../utils/contextual_entities';
import { isGenericCustomerName, isValidCustomerName, normalizePhone } from '../utils/customer_name';

export type CustomerProfileSnapshot = {
  id: string;
  nome: string | null;
  telefone: string | null;
  cpf_cnpj: string | null;
};

export type CapturedEntityState = {
  entity: ContextualEntity;
  customer: CustomerProfileSnapshot | null;
  status: 'created' | 'updated' | 'unchanged' | 'conflict' | 'skipped' | 'invalid';
  promptContext: string;
};

async function findCustomerByPhone(
  phoneNumber: string,
  preferredCustomerId?: string | null,
): Promise<CustomerProfileSnapshot | null> {
  if (preferredCustomerId) {
    const customer = await prisma.usuarios.findUnique({
      where: { id: preferredCustomerId },
      select: {
        id: true,
        nome: true,
        telefone: true,
        cpf_cnpj: true,
      },
    });

    if (customer) return customer;
  }

  const cleanPhone = normalizePhone(phoneNumber);
  if (!cleanPhone) return null;

  const phoneWithoutCountryCode = cleanPhone.startsWith('55') ? cleanPhone.slice(2) : cleanPhone;

  const rows = await prisma.$queryRaw<CustomerProfileSnapshot[]>`
    SELECT id, nome, telefone, cpf_cnpj
    FROM usuarios
    WHERE regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${cleanPhone}
       OR regexp_replace(COALESCE(telefone, ''), '\\D', '', 'g') = ${phoneWithoutCountryCode}
    LIMIT 1
  `;

  return rows[0] ?? null;
}

function labelForEntity(entity: ContextualEntity): string {
  switch (entity.type) {
    case 'customer_name':
      return 'nome';
    case 'cpf':
      return 'CPF';
    case 'license_plate':
      return 'placa';
    default:
      return 'dado';
  }
}

function buildPromptContext(params: {
  entity: ContextualEntity;
  status: CapturedEntityState['status'];
  reason: string;
}): string {
  const label = labelForEntity(params.entity);

  return [
    'Dado curto validado pelo contexto da ultima pergunta do assistente:',
    `- Tipo: ${label}`,
    `- Valor normalizado: ${params.entity.value}`,
    `- Estado: ${params.reason}`,
    '- Trate a mensagem atual como uma resposta valida ao dado solicitado. Nao bloqueie, nao recuse e nao peca o mesmo dado novamente se ele ja foi salvo.',
  ].join('\n');
}

async function persistCustomerName(
  entity: ContextualEntity,
  customer: CustomerProfileSnapshot,
  phoneNumber: string,
): Promise<Pick<CapturedEntityState, 'customer' | 'status' | 'promptContext'>> {
  if (!isValidCustomerName(entity.value, phoneNumber)) {
    return {
      customer,
      status: 'invalid',
      promptContext: buildPromptContext({
        entity,
        status: 'invalid',
        reason: 'nome informado nao passou na validacao local; peca o nome real novamente de forma objetiva.',
      }),
    };
  }

  if (!isGenericCustomerName(customer.nome, customer.telefone) && customer.nome?.trim() === entity.value) {
    return {
      customer,
      status: 'unchanged',
      promptContext: buildPromptContext({
        entity,
        status: 'unchanged',
        reason: 'nome ja estava salvo no cadastro.',
      }),
    };
  }

  const updated = await prisma.usuarios.update({
    where: { id: customer.id },
    data: { nome: entity.value },
    select: {
      id: true,
      nome: true,
      telefone: true,
      cpf_cnpj: true,
    },
  });

  return {
    customer: updated,
    status: 'updated',
    promptContext: buildPromptContext({
      entity,
      status: 'updated',
      reason: 'nome salvo no cadastro antes do raciocinio do agente.',
    }),
  };
}

async function persistCpf(
  entity: ContextualEntity,
  customer: CustomerProfileSnapshot,
): Promise<Pick<CapturedEntityState, 'customer' | 'status' | 'promptContext'>> {
  if (customer.cpf_cnpj === entity.value) {
    return {
      customer,
      status: 'unchanged',
      promptContext: buildPromptContext({
        entity,
        status: 'unchanged',
        reason: 'CPF ja estava salvo no cadastro.',
      }),
    };
  }

  const existingCpfOwnerRows = await prisma.$queryRaw<Array<{ id: string }>>`
    SELECT id
    FROM usuarios
    WHERE regexp_replace(COALESCE(cpf_cnpj, ''), '\\D', '', 'g') = ${entity.value}
    LIMIT 1
  `;
  const existingCpfOwner = existingCpfOwnerRows[0] ?? null;

  if (existingCpfOwner && existingCpfOwner.id !== customer.id) {
    return {
      customer,
      status: 'conflict',
      promptContext: buildPromptContext({
        entity,
        status: 'conflict',
        reason: 'CPF informado ja pertence a outro cadastro; nao foi salvo automaticamente.',
      }),
    };
  }

  const updated = await prisma.usuarios.update({
    where: { id: customer.id },
    data: { cpf_cnpj: entity.value },
    select: {
      id: true,
      nome: true,
      telefone: true,
      cpf_cnpj: true,
    },
  });

  return {
    customer: updated,
    status: 'updated',
    promptContext: buildPromptContext({
      entity,
      status: 'updated',
      reason: 'CPF salvo no cadastro antes do raciocinio do agente.',
    }),
  };
}

async function persistLicensePlate(
  entity: ContextualEntity,
  customer: CustomerProfileSnapshot,
): Promise<Pick<CapturedEntityState, 'customer' | 'status' | 'promptContext'>> {
  const existingVehicleRows = await prisma.$queryRaw<Array<{ id: string; cliente_id: string }>>`
    SELECT id, cliente_id
    FROM veiculos
    WHERE upper(regexp_replace(placa, '[^A-Za-z0-9]', '', 'g')) = ${entity.value}
    LIMIT 1
  `;
  const existingVehicle = existingVehicleRows[0] ?? null;

  if (existingVehicle?.cliente_id === customer.id) {
    return {
      customer,
      status: 'unchanged',
      promptContext: buildPromptContext({
        entity,
        status: 'unchanged',
        reason: 'placa ja estava vinculada ao cliente atual.',
      }),
    };
  }

  if (existingVehicle) {
    return {
      customer,
      status: 'conflict',
      promptContext: buildPromptContext({
        entity,
        status: 'conflict',
        reason: 'placa informada ja pertence a outro cadastro; nao foi vinculada automaticamente.',
      }),
    };
  }

  await prisma.veiculos.create({
    data: {
      cliente_id: customer.id,
      placa: entity.value,
      marca: 'Nao informado',
      modelo: 'Nao informado',
      ano: new Date().getFullYear(),
      quilometragem_atual: 0,
    },
  });

  return {
    customer,
    status: 'created',
    promptContext: buildPromptContext({
      entity,
      status: 'created',
      reason: 'placa vinculada ao cliente atual antes do raciocinio do agente.',
    }),
  };
}

export async function persistContextualEntity(
  entity: ContextualEntity | null,
  params: {
    phoneNumber: string;
    customerId?: string | null;
  },
): Promise<CapturedEntityState | null> {
  if (!entity) return null;

  const customer = await findCustomerByPhone(params.phoneNumber, params.customerId);

  if (!customer) {
    return {
      entity,
      customer: null,
      status: 'skipped',
      promptContext: buildPromptContext({
        entity,
        status: 'skipped',
        reason: 'cliente atual nao foi encontrado pelo telefone; dado validado apenas no contexto da conversa.',
      }),
    };
  }

  const result = entity.type === 'customer_name'
    ? await persistCustomerName(entity, customer, params.phoneNumber)
    : entity.type === 'cpf'
      ? await persistCpf(entity, customer)
      : await persistLicensePlate(entity, customer);

  return {
    entity,
    ...result,
  };
}
