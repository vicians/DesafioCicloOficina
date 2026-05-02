import { getDb } from '../../config/database';
import { v4 as uuidv4 } from 'uuid';
import { PasswordUtils } from '../../utils/passwordUtils';

// IDs únicos gerados programaticamente
const adminId = uuidv4();
const mecanicoId = uuidv4();
const clienteId = uuidv4();

// IDs para novos usuários
const mecanicoIds = [uuidv4(), uuidv4(), uuidv4()];
const clienteIds = [uuidv4(), uuidv4(), uuidv4(), uuidv4(), uuidv4()];

export const runSeeds = async () => {
  const db = getDb();

  console.log('Iniciando Seeds...');

  // Gerar hashes das senhas a partir do .env — todos os usuários seguem o mesmo padrão
  const adminSenhaHash    = await PasswordUtils.hash(process.env.ADMIN_SENHA     || 'admin123');
  const mecanicoSenhaHash = await PasswordUtils.hash(process.env.MECANICO_SENHA  || 'mecanico123');
  const clienteSenhaHash  = await PasswordUtils.hash(process.env.CLIENTE_SENHA   || 'cliente123');
  const mecanico2Hash     = await PasswordUtils.hash(process.env.MECANICO2_SENHA || 'mecanico2_secret_password');
  const mecanico3Hash     = await PasswordUtils.hash(process.env.MECANICO3_SENHA || 'mecanico3_secret_password');
  const mecanico4Hash     = await PasswordUtils.hash(process.env.MECANICO4_SENHA || 'mecanico4_secret_password');
  const cliente2Hash      = await PasswordUtils.hash(process.env.CLIENTE2_SENHA  || 'cliente2_secret_password');
  const cliente3Hash      = await PasswordUtils.hash(process.env.CLIENTE3_SENHA  || 'cliente3_secret_password');
  const cliente4Hash      = await PasswordUtils.hash(process.env.CLIENTE4_SENHA  || 'cliente4_secret_password');
  const cliente5Hash      = await PasswordUtils.hash(process.env.CLIENTE5_SENHA  || 'cliente5_secret_password');
  const cliente6Hash      = await PasswordUtils.hash(process.env.CLIENTE6_SENHA  || 'cliente6_secret_password');

  const usuariosBase = [
    {
      id: adminId,
      tipo_id: 1, // ADMIN
      nome: process.env.ADMIN_NOME || 'Admin OmniConnect',
      cpf_cnpj: process.env.ADMIN_CPF || '000.000.000-00',
      telefone: process.env.ADMIN_TELEFONE || '5511999999999',
      email: process.env.ADMIN_EMAIL || 'admin@omniconnect.com',
      senha_hash: adminSenhaHash,
    },
    {
      id: mecanicoId,
      tipo_id: 3, // MECANICO
      nome: process.env.MECANICO_NOME || 'Mecânico Principal',
      cpf_cnpj: process.env.MECANICO_CPF || '111.111.111-11',
      telefone: process.env.MECANICO_TELEFONE || '5511988888888',
      email: process.env.MECANICO_EMAIL || 'mecanico@omniconnect.com',
      senha_hash: mecanicoSenhaHash,
    },
    {
      id: clienteId,
      tipo_id: 2, // CLIENTE
      nome: process.env.CLIENTE_NOME || 'Cliente Exemplo',
      cpf_cnpj: process.env.CLIENTE_CPF || '222.222.222-22',
      telefone: process.env.CLIENTE_TELEFONE || '5511977777777',
      email: process.env.CLIENTE_EMAIL || 'cliente@exemplo.com',
      senha_hash: clienteSenhaHash,
    },
  ];

  const novosMecanicos = [
    { id: mecanicoIds[0], nome: process.env.MECANICO2_NOME || 'Mecânico 2', cpf: process.env.MECANICO2_CPF || '333.333.333-33', tel: process.env.MECANICO2_TELEFONE || '5511966666661', email: process.env.MECANICO2_EMAIL || 'mecanico2@oficina.com', senha_hash: mecanico2Hash },
    { id: mecanicoIds[1], nome: process.env.MECANICO3_NOME || 'Mecânico 3', cpf: process.env.MECANICO3_CPF || '444.444.444-44', tel: process.env.MECANICO3_TELEFONE || '5511966666662', email: process.env.MECANICO3_EMAIL || 'mecanico3@oficina.com', senha_hash: mecanico3Hash },
    { id: mecanicoIds[2], nome: process.env.MECANICO4_NOME || 'Mecânico 4', cpf: process.env.MECANICO4_CPF || '555.555.555-55', tel: process.env.MECANICO4_TELEFONE || '5511966666663', email: process.env.MECANICO4_EMAIL || 'mecanico4@oficina.com', senha_hash: mecanico4Hash },
  ];

  const novosClientes = [
    { id: clienteIds[0], nome: process.env.CLIENTE2_NOME || 'Cliente 2', cpf: process.env.CLIENTE2_CPF || '666.666.666-66', tel: process.env.CLIENTE2_TELEFONE || '5511955555551', email: process.env.CLIENTE2_EMAIL || 'cliente2@gmail.com', senha_hash: cliente2Hash },
    { id: clienteIds[1], nome: process.env.CLIENTE3_NOME || 'Cliente 3', cpf: process.env.CLIENTE3_CPF || '777.777.777-77', tel: process.env.CLIENTE3_TELEFONE || '5511955555552', email: process.env.CLIENTE3_EMAIL || 'cliente3@gmail.com', senha_hash: cliente3Hash },
    { id: clienteIds[2], nome: process.env.CLIENTE4_NOME || 'Cliente 4', cpf: process.env.CLIENTE4_CPF || '888.888.888-88', tel: process.env.CLIENTE4_TELEFONE || '5511955555553', email: process.env.CLIENTE4_EMAIL || 'cliente4@gmail.com', senha_hash: cliente4Hash },
    { id: clienteIds[3], nome: process.env.CLIENTE5_NOME || 'Cliente 5', cpf: process.env.CLIENTE5_CPF || '999.999.999-99', tel: process.env.CLIENTE5_TELEFONE || '5511955555554', email: process.env.CLIENTE5_EMAIL || 'cliente5@gmail.com', senha_hash: cliente5Hash },
    { id: clienteIds[4], nome: process.env.CLIENTE6_NOME || 'Cliente 6', cpf: process.env.CLIENTE6_CPF || '101.101.101-10', tel: process.env.CLIENTE6_TELEFONE || '5511955555555', email: process.env.CLIENTE6_EMAIL || 'cliente6@gmail.com', senha_hash: cliente6Hash },
  ];

  const veiculosData = [
    { brand: 'Fiat', model: 'Uno 1.0 8V (Fire)', year: 2005 },
    { brand: 'Fiat', model: 'Uno / Palio 1.0 8V (Fire EVO)', year: 2013 },
    { brand: 'Fiat', model: 'Argo / Cronos / Uno 1.0 6V (Firefly)', year: 2020 },
    { brand: 'Fiat/Jeep', model: 'Toro / Renegade / Compass 1.3 16V', year: 2022 },
    { brand: 'VW', model: 'Gol / Fox / Voyage 1.0 / 1.6 8V', year: 2010 },
    { brand: 'VW', model: 'Up! / Gol / Fox 1.0 12V MPI', year: 2018 },
    { brand: 'VW', model: 'Polo / Virtus / T-Cross 1.0 12V TSI', year: 2019 },
    { brand: 'VW', model: 'Nivus / Polo / T-Cross 1.0 / 1.4 TSI', year: 2023 },
    { brand: 'VW', model: 'Amarok 2.0 / 3.0 V6 TDI', year: 2015 },
    { brand: 'GM', model: 'Celta / Classic / Prisma 1.0 / 1.4 8V', year: 2010 },
    { brand: 'GM', model: 'Onix / Prisma 1.0 / 1.4 8V', year: 2015 },
    { brand: 'GM', model: 'Onix / Tracker 1.0 / 1.2 Turbo', year: 2021 },
    { brand: 'Ford', model: 'Fiesta / Ka / EcoSport 1.0 / 1.6 8V', year: 2007 },
    { brand: 'Ford', model: 'Ka / HB20 1.0 12V', year: 2017 },
    { brand: 'Ford', model: 'Ranger 3.2 20V', year: 2018 },
    { brand: 'Hyundai', model: 'HB20 1.0 12V (Kappa Aspirado)', year: 2018 },
    { brand: 'Hyundai', model: 'HB20 / Creta 1.0 12V (Kappa TGDI)', year: 2022 },
    { brand: 'Honda', model: 'Civic / Fit / City 1.5 / 1.8 / 2.0', year: 2018 },
    { brand: 'Toyota', model: 'Corolla 1.8 / 2.0 16V', year: 2007 },
    { brand: 'Toyota', model: 'Corolla / Yaris 1.5 / 2.0 16V', year: 2018 },
    { brand: 'Toyota', model: 'Hilux 2.8 16V', year: 2020 },
    { brand: 'Renault', model: 'Sandero / Logan / Clio 1.0 16V', year: 2010 },
    { brand: 'Renault', model: 'Kwid / Sandero / Logan 1.0 12V', year: 2020 },
  ];

  const produtosData = [
    // Óleos de motor
    { nome: 'Óleo 15W-40 API SL (1L)', marca: 'Motul', valor: 3800, estoque: 50 },
    { nome: 'Óleo 5W-30 API SN / ACEA A1/B1 (1L)', marca: 'Castrol', valor: 5500, estoque: 50 },
    { nome: 'Óleo 0W-20 API SP / ILSAC GF-6 (1L)', marca: 'Mobil', valor: 7500, estoque: 40 },
    { nome: 'Óleo 5W-40 API SN / ACEA A3/B4 (1L)', marca: 'Shell', valor: 6200, estoque: 40 },
    { nome: 'Óleo 5W-30 ACEA C3 DPF (1L)', marca: 'Total', valor: 8500, estoque: 30 },

    // Filtros
    { nome: 'Filtro de Óleo Universal', marca: 'Mahle', valor: 2800, estoque: 60 },
    { nome: 'Filtro de Ar Motor (Popular)', marca: 'Fram', valor: 3500, estoque: 50 },
    { nome: 'Filtro de Ar Motor (Premium)', marca: 'Mann', valor: 5200, estoque: 30 },
    { nome: 'Filtro de Combustível Gasolina/Etanol', marca: 'Bosch', valor: 4500, estoque: 40 },
    { nome: 'Filtro de Cabine / Ar Condicionado', marca: 'Mahle', valor: 4800, estoque: 35 },
    { nome: 'Filtro de Transmissão Automática', marca: 'Mann', valor: 8900, estoque: 20 },

    // Freios
    { nome: 'Pastilha de Freio Dianteira (Par)', marca: 'Bosch', valor: 12000, estoque: 30 },
    { nome: 'Pastilha de Freio Traseira (Par)', marca: 'Bosch', valor: 9800, estoque: 30 },
    { nome: 'Sapata de Freio Traseira (Jogo)', marca: 'Cobreq', valor: 7500, estoque: 25 },
    { nome: 'Disco de Freio Dianteiro (Unidade)', marca: 'Brembo', valor: 18500, estoque: 20 },
    { nome: 'Disco de Freio Traseiro (Unidade)', marca: 'Brembo', valor: 16500, estoque: 20 },
    { nome: 'Fluido de Freio DOT 4 (500ml)', marca: 'Bosch', valor: 3200, estoque: 40 },

    // Sistema elétrico
    { nome: 'Vela de Ignição NGK (Unidade)', marca: 'NGK', valor: 2500, estoque: 80 },
    { nome: 'Vela de Ignição Iridium (Unidade)', marca: 'NGK', valor: 5800, estoque: 40 },
    { nome: 'Cabo de Vela (Jogo 4 cilindros)', marca: 'NGK', valor: 9500, estoque: 20 },
    { nome: 'Bateria 60Ah', marca: 'Heliar', valor: 42000, estoque: 15 },
    { nome: 'Bateria 70Ah', marca: 'Heliar', valor: 52000, estoque: 15 },
    { nome: 'Lâmpada H4 Halógena (Par)', marca: 'Osram', valor: 3800, estoque: 30 },
    { nome: 'Lâmpada H7 Halógena (Par)', marca: 'Osram', valor: 4200, estoque: 30 },

    // Correias e tensores
    { nome: 'Correia Dentada', marca: 'Gates', valor: 8500, estoque: 25 },
    { nome: 'Kit Correia Dentada + Tensor', marca: 'Gates', valor: 18500, estoque: 20 },
    { nome: 'Correia Alternador / Acessórios', marca: 'Gates', valor: 5500, estoque: 30 },
    { nome: 'Tensor de Correia Dentada', marca: 'INA', valor: 7800, estoque: 20 },

    // Fluidos e aditivos
    { nome: 'Fluido de Arrefecimento (1L)', marca: 'Prestone', valor: 2800, estoque: 50 },
    { nome: 'Fluido de Direção Hidráulica (1L)', marca: 'Texaco', valor: 3500, estoque: 30 },
    { nome: 'Fluido de Embreagem DOT 3 (500ml)', marca: 'Bosch', valor: 2900, estoque: 30 },
    { nome: 'Aditivo para Limpeza de Bico Injetor', marca: 'Tecbril', valor: 2200, estoque: 40 },

    // Suspensão e direção
    { nome: 'Amortecedor Dianteiro (Unidade)', marca: 'Monroe', valor: 28000, estoque: 15 },
    { nome: 'Amortecedor Traseiro (Unidade)', marca: 'Monroe', valor: 22000, estoque: 15 },
    { nome: 'Pivô de Suspensão', marca: 'Nakata', valor: 6500, estoque: 20 },
    { nome: 'Barra Estabilizadora / Bucha', marca: 'Nakata', valor: 4200, estoque: 25 },
    { nome: 'Rolamento de Roda Dianteiro', marca: 'SKF', valor: 14500, estoque: 20 },
    { nome: 'Rolamento de Roda Traseiro', marca: 'SKF', valor: 12500, estoque: 20 },
  ];

  try {
    // 1. Inserir Tipos de Usuário
    await db.query(`
      INSERT INTO tipos_usuario (id, nome, descricao)
      VALUES 
        (1, 'ADMIN', 'Administrador do sistema'),
        (2, 'CLIENTE', 'Cliente final da oficina'),
        (3, 'MECANICO', 'Mecânico executante')
      ON CONFLICT (id) DO NOTHING
    `);

    // 2. Inserir Usuários (Base e Novos)
    const allUsuarios = [
      ...usuariosBase,
      ...novosMecanicos.map(m => ({ id: m.id, tipo_id: 3, nome: m.nome, cpf_cnpj: m.cpf, telefone: m.tel, email: m.email, senha_hash: m.senha_hash })),
      ...novosClientes.map(c => ({ id: c.id, tipo_id: 2, nome: c.nome, cpf_cnpj: c.cpf, telefone: c.tel, email: c.email, senha_hash: c.senha_hash })),
    ];

    for (const u of allUsuarios) {
      await db.query(
        `INSERT INTO usuarios (id, tipo_id, nome, cpf_cnpj, telefone, email, senha_hash)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (cpf_cnpj) DO NOTHING`,
        [u.id, u.tipo_id, u.nome, u.cpf_cnpj, u.telefone, u.email, u.senha_hash]
      );
    }
    console.log('✓ Usuários (Base, Mecânicos e Clientes) inseridos');

    // 3. Inserir Oficina
    const contagemOficina = await db.query('SELECT COUNT(*) as count FROM oficinas');
    if (parseInt(contagemOficina.rows[0].count) === 0) {
      await db.query(`
        INSERT INTO oficinas (nome, quantidade_boxes)
        VALUES ('Oficina Central OmniConnect', 5)
      `);
      console.log('✓ Oficina inserida');
    }

    // 4. Inserir Catálogo de Serviços
    // duracao_minutos é crítico: sistema usa para bloquear vagas na agenda (RN022)
    const servicosData = [
      // Manutenção Preventiva
      { nome: 'Troca de Óleo e Filtro', preco: 15000, duracao: 40 },
      { nome: 'Revisão dos 10.000 km', preco: 28000, duracao: 120 },
      { nome: 'Revisão dos 20.000 km', preco: 45000, duracao: 180 },
      { nome: 'Revisão dos 40.000 km (Completa)', preco: 85000, duracao: 300 },
      { nome: 'Troca de Filtro de Ar', preco: 8000, duracao: 20 },
      { nome: 'Troca de Filtro de Cabine', preco: 9000, duracao: 20 },
      { nome: 'Troca de Filtro de Combustível', preco: 10000, duracao: 30 },
      { nome: 'Troca de Velas de Ignição', preco: 18000, duracao: 60 },
      { nome: 'Troca de Correia Dentada + Tensor', preco: 55000, duracao: 240 },
      { nome: 'Troca de Correia Alternador', preco: 18000, duracao: 60 },
      { nome: 'Troca de Fluido de Freio', preco: 14000, duracao: 45 },
      { nome: 'Troca de Fluido de Arrefecimento', preco: 16000, duracao: 60 },
      { nome: 'Troca de Fluido de Direção Hidráulica', preco: 12000, duracao: 30 },

      // Sistema de Freios
      { nome: 'Troca de Pastilha Dianteira', preco: 22000, duracao: 60 },
      { nome: 'Troca de Pastilha Traseira', preco: 20000, duracao: 60 },
      { nome: 'Troca de Disco de Freio (Par)', preco: 48000, duracao: 120 },
      { nome: 'Troca de Sapata de Freio (Jogo)', preco: 24000, duracao: 90 },
      { nome: 'Revisão Completa do Sistema de Freios', preco: 38000, duracao: 120 },

      // Suspensão e Direção
      { nome: 'Alinhamento', preco: 8000, duracao: 30 },
      { nome: 'Balanceamento (4 rodas)', preco: 8000, duracao: 30 },
      { nome: 'Alinhamento e Balanceamento', preco: 14000, duracao: 60 },
      { nome: 'Troca de Amortecedor Dianteiro (Par)', preco: 75000, duracao: 180 },
      { nome: 'Troca de Amortecedor Traseiro (Par)', preco: 65000, duracao: 180 },
      { nome: 'Troca de Pivô de Suspensão', preco: 28000, duracao: 90 },
      { nome: 'Troca de Bucha de Bandeja', preco: 22000, duracao: 90 },
      { nome: 'Troca de Rolamento de Roda', preco: 38000, duracao: 120 },

      // Sistema Elétrico
      { nome: 'Diagnóstico Eletrônico (Scanner OBD)', preco: 15000, duracao: 60 },
      { nome: 'Troca de Bateria', preco: 20000, duracao: 30 },
      { nome: 'Troca de Alternador', preco: 42000, duracao: 120 },
      { nome: 'Troca de Motor de Partida', preco: 38000, duracao: 120 },
      { nome: 'Reparo de Instalação Elétrica', preco: 35000, duracao: 180 },

      // Injeção e Motor
      { nome: 'Limpeza de Bico Injetor (Ultrassom)', preco: 32000, duracao: 120 },
      { nome: 'Limpeza do Sistema de Injeção (Química)', preco: 18000, duracao: 60 },
      { nome: 'Regulagem de Motor', preco: 25000, duracao: 90 },
      { nome: 'Diagnóstico de Falhas no Motor', preco: 20000, duracao: 60 },
      { nome: 'Troca de Junta do Cabeçote', preco: 120000, duracao: 480 },

      // Ar Condicionado
      { nome: 'Recarga de Gás do Ar Condicionado', preco: 25000, duracao: 60 },
      { nome: 'Higienização do Ar Condicionado', preco: 18000, duracao: 45 },
      { nome: 'Troca de Compressor de Ar Condicionado', preco: 85000, duracao: 240 },

      // Câmbio e Transmissão
      { nome: 'Troca de Óleo de Câmbio Manual', preco: 18000, duracao: 45 },
      { nome: 'Troca de Óleo de Câmbio Automático', preco: 28000, duracao: 60 },
      { nome: 'Troca de Embreagem (Jogo)', preco: 95000, duracao: 360 },
    ];

    const contagemServicos = await db.query('SELECT COUNT(*) as count FROM catalogo_servicos');
    if (parseInt(contagemServicos.rows[0].count) === 0) {
      for (const s of servicosData) {
        await db.query(
          `INSERT INTO catalogo_servicos (nome, preco, duracao_minutos) VALUES ($1, $2, $3)`,
          [s.nome, s.preco, s.duracao]
        );
      }
      console.log(`✓ ${servicosData.length} serviços inseridos no catálogo`);
    }

    // 5. Inserir Produtos
    const contagemProdutos = await db.query('SELECT COUNT(*) as count FROM produtos');
    if (parseInt(contagemProdutos.rows[0].count) === 0) {
      for (const p of produtosData) {
        await db.query(
          `INSERT INTO produtos (nome, marca, valor, quantidade_estoque)
           VALUES ($1, $2, $3, $4)`,
          [p.nome, p.marca, p.valor, p.estoque]
        );
      }
      console.log('✓ Produtos (Óleos, Filtros, Freios, Elétrico, Correias, Fluidos, Suspensão) inseridos');
    }

    // 6. Inserir Veículos — RN003: cliente PF tem no máximo 3 veículos
    // 6 clientes × 3 veículos = 18 registros (usa os primeiros 18 modelos da lista)
    const contagemVeiculos = await db.query('SELECT COUNT(*) as count FROM veiculos');
    if (parseInt(contagemVeiculos.rows[0].count) === 0) {
      const todosClientes = [clienteId, ...clienteIds]; // 6 clientes PF

      for (let clienteIdx = 0; clienteIdx < todosClientes.length; clienteIdx++) {
        for (let veiculoSlot = 0; veiculoSlot < 3; veiculoSlot++) {
          const modeloIdx = clienteIdx * 3 + veiculoSlot;
          const v = veiculosData[modeloIdx];
          const cId = todosClientes[clienteIdx];
          // Gera placa no formato ABC-1234 garantindo unicidade pelo índice global
          const letra = (n: number) => String.fromCharCode(65 + (n % 26));
          const globalIdx = modeloIdx;
          const placa = `${letra(globalIdx)}${letra(globalIdx + 1)}${letra(globalIdx + 2)}-${1000 + globalIdx}`;

          await db.query(
            `INSERT INTO veiculos (cliente_id, placa, marca, modelo, ano, quilometragem_atual)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [cId, placa, v.brand, v.model, v.year, 10000 + (globalIdx * 5000)]
          );
        }
      }
      console.log('✓ Veículos inseridos (máx 3 por cliente — RN003)');
    }

    // ── A partir daqui buscamos IDs reais do banco ──────────────────────────
    // Os IDs de clientes, veículos e serviços foram gerados pelo PostgreSQL
    // (gen_random_uuid), então precisamos consultá-los em runtime.

    // 7. Inserir Orçamentos com status variados + itens
    const contagemOrcamentos = await db.query('SELECT COUNT(*) as count FROM orcamentos');
    if (parseInt(contagemOrcamentos.rows[0].count) === 0) {

      // Buscar referências necessárias do banco
      const clientesDb = await db.query(
        `SELECT u.id, u.nome FROM usuarios u WHERE u.tipo_id = 2 ORDER BY u.criado_em LIMIT 6`
      );
      const veiculosDb = await db.query(
        `SELECT v.id, v.cliente_id FROM veiculos v ORDER BY v.criado_em LIMIT 18`
      );
      const servicosDb = await db.query(
        `SELECT id, nome, preco, duracao_minutos FROM catalogo_servicos ORDER BY criado_em`
      );
      const produtosDb = await db.query(
        `SELECT id, nome, valor FROM produtos ORDER BY id`
      );
      const mecanicosDb = await db.query(
        `SELECT id FROM usuarios WHERE tipo_id = 3 ORDER BY criado_em`
      );

      const clientes = clientesDb.rows;
      const veiculos = veiculosDb.rows;
      const servicos = servicosDb.rows;
      const produtos = produtosDb.rows;
      const mecanicos = mecanicosDb.rows;

      if (clientes.length === 0 || veiculos.length === 0 || servicos.length < 5) {
        console.log('⚠️  Dados insuficientes para criar orçamentos. Verifique clientes/veículos/serviços.');
      } else {
        // Helper: busca veículo de um cliente específico
        const veiculoDoCliente = (clienteId: string, offset = 0) =>
          veiculos.filter(v => v.cliente_id === clienteId)[offset] ?? veiculos[0];

        // Helper: data futura a partir de hoje
        const dataFutura = (dias: number) => {
          const d = new Date();
          d.setDate(d.getDate() + dias);
          d.setHours(9, 0, 0, 0);
          return d.toISOString();
        };

        // Helper: data passada
        const dataPassada = (dias: number) => {
          const d = new Date();
          d.setDate(d.getDate() - dias);
          d.setHours(9, 0, 0, 0);
          return d.toISOString();
        };

        const validadePadrao = (diasBase: number) => {
          const d = new Date();
          d.setDate(d.getDate() + diasBase + 7); // +7 dias de validade (RN033)
          return d.toISOString();
        };

        /*
         * Dois fluxos de agendamento existentes no sistema:
         *
         * FLUXO 1 — Para avaliação/diagnóstico (sem orçamento prévio):
         *   Cliente agenda → agendamento PENDENTE → mecânico avalia → orçamento criado
         *   Agendamentos A, B, C abaixo cobrem este fluxo.
         *
         * FLUXO 2 — Pós-aprovação de orçamento:
         *   Cliente aprova orçamento → agendamento CONFIRMADO gerado automaticamente
         *   Orçamentos 4, 5, 6 abaixo cobrem este fluxo (APROVADO×2, PAGO).
         *
         * Cenários de orçamento (complementares):
         * 1. RASCUNHO   — cliente[0], veículo dele, 1 serviço
         * 2. ENVIADO    — cliente[1], veículo dele, 2 serviços + 1 produto
         * 3. REJEITADO  — cliente[2], veículo dele, 1 serviço
         * 4. APROVADO   — cliente[3] → agendamento CONFIRMADO + execução EM_EXECUCAO
         * 5. APROVADO   — cliente[4] → agendamento CONFIRMADO + execução CONCLUIDO
         * 6. PAGO       — cliente[5] → agendamento CONFIRMADO + execução ENTREGUE
         */

        // ── FLUXO 1: Agendamentos para Avaliação/Diagnóstico (PENDENTE) ──────
        // RN021: cliente pode ter múltiplas solicitações PENDENTE aguardando orçamento
        // Estes agendamentos NÃO têm orçamento vinculado — o orçamento é criado
        // após o mecânico inspecionar o veículo.

        // A: cliente[0] — barulho no motor, avaliação ocorrendo AGORA
        const pA_cli = clientes[0];
        const pA_vei = veiculoDoCliente(pA_cli.id);
        const pA_mec = mecanicos[1]?.id ?? mecanicos[0].id;
        const pA_dur = 60; // tempo de avaliação técnica
        const pA_ini = dataPassada(0);
        const pA_fim = new Date(new Date(pA_ini).getTime() + pA_dur * 60000).toISOString();
        await db.query(
          `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
           VALUES ($1, $2, $3, $4, $5, $6, 'EM_AVALIACAO', $7)`,
          [pA_cli.id, pA_vei.id, pA_mec, pA_ini, pA_dur, pA_fim,
           'Carro fazendo barulho estranho ao acelerar. Nunca passou por revisão.']
        );

        // B: cliente[1] — luz de check engine acesa, precisa de scanner
        const pB_cli = clientes[1];
        const pB_vei = veiculoDoCliente(pB_cli.id);
        const pB_mec = mecanicos[2]?.id ?? mecanicos[0].id;
        const pB_dur = 60;
        const pB_ini = dataFutura(3);
        const pB_fim = new Date(new Date(pB_ini).getTime() + pB_dur * 60000).toISOString();
        await db.query(
          `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
           VALUES ($1, $2, $3, $4, $5, $6, 'PENDENTE', $7)`,
          [pB_cli.id, pB_vei.id, pB_mec, pB_ini, pB_dur, pB_fim,
           'Luz de motor acesa há 3 dias. Carro ainda roda normalmente mas estou preocupado.']
        );

        // C: cliente[2] — revisão geral antes de viagem longa
        const pC_cli = clientes[2];
        const pC_vei = veiculoDoCliente(pC_cli.id);
        const pC_mec = mecanicos[3]?.id ?? mecanicos[0].id;
        const pC_dur = 90;
        const pC_ini = dataFutura(5);
        const pC_fim = new Date(new Date(pC_ini).getTime() + pC_dur * 60000).toISOString();
        await db.query(
          `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
           VALUES ($1, $2, $3, $4, $5, $6, 'PENDENTE', $7)`,
          [pC_cli.id, pC_vei.id, pC_mec, pC_ini, pC_dur, pC_fim,
           'Quero uma revisão geral antes de uma viagem longa no fim de semana.']
        );

        console.log('✓ Agendamentos PENDENTE inseridos (fluxo avaliação/diagnóstico — RN021)');

        // ── Orçamento 1: RASCUNHO ──────────────────────────────────────────
        const c0 = clientes[0];
        const v0 = veiculoDoCliente(c0.id);
        const s0 = servicos[0]; // Troca de Óleo e Filtro
        const total0 = s0.preco;

        const orc0 = await db.query(
          `INSERT INTO orcamentos (cliente_id, funcionario_id, status, valor_total, valido_ate)
           VALUES ($1, $2, 'RASCUNHO', $3, $4) RETURNING id`,
          [c0.id, mecanicos[0]?.id ?? null, total0, validadePadrao(0)]
        );
        await db.query(
          `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3)`,
          [orc0.rows[0].id, s0.id, s0.preco]
        );

        // ── Orçamento 2: ENVIADO ───────────────────────────────────────────
        const c1 = clientes[1];
        const v1 = veiculoDoCliente(c1.id);
        const s1a = servicos[1]; // Revisão 10.000 km
        const s1b = servicos[13]; // Troca Pastilha Dianteira
        const p1  = produtos[0];  // Filtro de Óleo
        const total1 = s1a.preco + s1b.preco + p1.valor;

        const orc1 = await db.query(
          `INSERT INTO orcamentos (cliente_id, funcionario_id, status, valor_total, valido_ate)
           VALUES ($1, $2, 'ENVIADO', $3, $4) RETURNING id`,
          [c1.id, mecanicos[0]?.id ?? null, total1, validadePadrao(0)]
        );
        await db.query(
          `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3), ($1, $4, 1, $5)`,
          [orc1.rows[0].id, s1a.id, s1a.preco, s1b.id, s1b.preco]
        );
        await db.query(
          `INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3)`,
          [orc1.rows[0].id, p1.id, p1.valor]
        );

        // ── Orçamento 3: REJEITADO ─────────────────────────────────────────
        const c2 = clientes[2];
        const v2 = veiculoDoCliente(c2.id);
        const s2 = servicos[8]; // Troca Correia Dentada
        const total2 = s2.preco;

        const orc2 = await db.query(
          `INSERT INTO orcamentos (cliente_id, funcionario_id, status, valor_total, valido_ate)
           VALUES ($1, $2, 'REJEITADO', $3, $4) RETURNING id`,
          [c2.id, mecanicos[1]?.id ?? mecanicos[0]?.id ?? null, total2, validadePadrao(-8)]
        );
        await db.query(
          `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3)`,
          [orc2.rows[0].id, s2.id, s2.preco]
        );

        // ── Orçamento 4: APROVADO → agendamento CONFIRMADO + execução EM_EXECUCAO ──
        // RN024: agendamento CONFIRMADO só após orçamento APROVADO
        // RN041: execução criada somente com orçamento APROVADO
        const c3 = clientes[3];
        const v3 = veiculoDoCliente(c3.id);
        const s3 = servicos[0]; // Troca de Óleo e Filtro
        const p3 = produtos[5]; // Filtro de Óleo Universal
        const total3 = s3.preco + p3.valor;
        const mec3 = mecanicos[1]?.id ?? mecanicos[0].id;
        const duracao3 = s3.duracao_minutos;
        const inicio3 = dataFutura(1);
        const fim3 = new Date(new Date(inicio3).getTime() + duracao3 * 60000).toISOString();

        const ag3 = await db.query(
          `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
           VALUES ($1, $2, $3, $4, $5, $6, 'CONFIRMADO', $7) RETURNING id`,
          [c3.id, v3.id, mec3, inicio3, duracao3, fim3, 'Carro fazendo barulho ao freiar']
        );
        const orc3 = await db.query(
          `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
           VALUES ($1, $2, $3, 'APROVADO', $4, $5) RETURNING id`,
          [ag3.rows[0].id, c3.id, mec3, total3, validadePadrao(-2)]
        );
        await db.query(
          `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3)`,
          [orc3.rows[0].id, s3.id, s3.preco]
        );
        await db.query(
          `INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3)`,
          [orc3.rows[0].id, p3.id, p3.valor]
        );
        // RN044: status EM_EXECUCAO
        await db.query(
          `INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em, notas_internas)
           VALUES ($1, $2, 'EM_EXECUCAO', $3, $4)`,
          [orc3.rows[0].id, mec3, dataPassada(0), 'Veículo no elevador, aguardando peças']
        );

        // ── Orçamento 5: APROVADO → execução CONCLUIDO ────────────────────
        const c4 = clientes[4 % clientes.length];
        const v4 = veiculoDoCliente(c4.id);
        const s4a = servicos[2]; // Revisão 20.000 km
        const s4b = servicos[6]; // Troca Filtro Combustível
        const p4 = produtos[1];  // Óleo 5W-30
        const total4 = s4a.preco + s4b.preco + p4.valor;
        const mec4 = mecanicos[2]?.id ?? mecanicos[0].id;
        const duracao4 = s4a.duracao_minutos + s4b.duracao_minutos;
        const inicio4 = dataPassada(3);
        const fim4 = new Date(new Date(inicio4).getTime() + duracao4 * 60000).toISOString();

        const ag4 = await db.query(
          `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
           VALUES ($1, $2, $3, $4, $5, $6, 'CONFIRMADO', $7) RETURNING id`,
          [c4.id, v4.id, mec4, inicio4, duracao4, fim4, 'Revisão programada dos 20 mil km']
        );
        const orc4 = await db.query(
          `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
           VALUES ($1, $2, $3, 'APROVADO', $4, $5) RETURNING id`,
          [ag4.rows[0].id, c4.id, mec4, total4, validadePadrao(-10)]
        );
        await db.query(
          `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3), ($1, $4, 1, $5)`,
          [orc4.rows[0].id, s4a.id, s4a.preco, s4b.id, s4b.preco]
        );
        await db.query(
          `INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario)
           VALUES ($1, $2, 2, $3)`,
          [orc4.rows[0].id, p4.id, p4.valor]
        );
        // RN044: CONCLUIDO — serviço finalizado, aguardando retirada
        await db.query(
          `INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em, finalizado_em, notas_internas)
           VALUES ($1, $2, 'CONCLUIDO', $3, $4, $5)`,
          [orc4.rows[0].id, mec4, dataPassada(3), dataPassada(2), 'Revisão concluída. Óleo trocado, filtros substituídos. Veículo pronto para retirada.']
        );

        // ── Orçamento 6: PAGO → execução ENTREGUE ─────────────────────────
        const c5 = clientes[5 % clientes.length];
        const v5 = veiculoDoCliente(c5.id);
        const s5 = servicos[14]; // Troca Disco de Freio
        const p5 = produtos[11]; // Pastilha Dianteira
        const total5 = s5.preco + p5.valor * 2;
        const mec5 = mecanicos[0].id;
        const duracao5 = s5.duracao_minutos;
        const inicio5 = dataPassada(7);
        const fim5 = new Date(new Date(inicio5).getTime() + duracao5 * 60000).toISOString();

        const ag5 = await db.query(
          `INSERT INTO agendamentos (cliente_id, veiculo_id, funcionario_id, agendado_para, duracao_total_minutos, fim_estimado_em, status, notas_cliente)
           VALUES ($1, $2, $3, $4, $5, $6, 'CONFIRMADO', $7) RETURNING id`,
          [c5.id, v5.id, mec5, inicio5, duracao5, fim5, 'Freio traseiro falhando, disco arranhado']
        );
        const orc5 = await db.query(
          `INSERT INTO orcamentos (agendamento_id, cliente_id, funcionario_id, status, valor_total, valido_ate)
           VALUES ($1, $2, $3, 'PAGO', $4, $5) RETURNING id`,
          [ag5.rows[0].id, c5.id, mec5, total5, validadePadrao(-20)]
        );
        await db.query(
          `INSERT INTO itens_orcamento_servico (orcamento_id, servico_id, quantidade, preco_unitario)
           VALUES ($1, $2, 1, $3)`,
          [orc5.rows[0].id, s5.id, s5.preco]
        );
        await db.query(
          `INSERT INTO itens_orcamento_produto (orcamento_id, produto_id, quantidade, preco_unitario)
           VALUES ($1, $2, 2, $3)`,
          [orc5.rows[0].id, p5.id, p5.valor]
        );
        // RN044: ENTREGUE — ciclo completo encerrado
        await db.query(
          `INSERT INTO execucoes_servico (orcamento_id, funcionario_id, status, iniciado_em, finalizado_em, notas_internas)
           VALUES ($1, $2, 'ENTREGUE', $3, $4, $5)`,
          [orc5.rows[0].id, mec5, dataPassada(7), dataPassada(6), 'Discos e pastilhas substituídos. Cliente retirou o veículo e assinou a OS.']
        );

        console.log('✓ Orçamentos (RASCUNHO, ENVIADO, REJEITADO, APROVADO×2, PAGO) inseridos');
        console.log('✓ Agendamentos CONFIRMADOS vinculados aos orçamentos APROVADOS/PAGO inseridos');
        console.log('✓ Execuções (EM_EXECUCAO, CONCLUIDO, ENTREGUE) inseridas — RN041/RN044');
      }
    }

    // 8. Inserir Notificações
    // Tipos usados no projeto: low_stock, budget, approved_budget, new_schedule
    // RN093: clientes recebem orçamento enviado, mudança de status, veículo pronto
    // RN094: oficina recebe nova solicitação, aprovação de orçamento
    // RN095: máx 5 notificações/dia por cliente
    const contagemNotifs = await db.query('SELECT COUNT(*) as count FROM notifications');
    if (parseInt(contagemNotifs.rows[0].count) === 0) {

      // Buscar usuários e referências em runtime
      const clientesNotif = await db.query(
        `SELECT id FROM usuarios WHERE tipo_id = 2 ORDER BY criado_em LIMIT 6`
      );
      const internosNotif = await db.query(
        `SELECT id FROM usuarios WHERE tipo_id IN (1, 3) ORDER BY criado_em`
      );
      const orcamentosNotif = await db.query(
        `SELECT id, status, cliente_id FROM orcamentos ORDER BY criado_em`
      );
      const agendamentosNotif = await db.query(
        `SELECT id, cliente_id FROM agendamentos ORDER BY criado_em`
      );
      const produtosNotif = await db.query(
        `SELECT id, nome FROM produtos WHERE quantidade_estoque <= 20 LIMIT 2`
      );

      const cliIds   = clientesNotif.rows.map((r: { id: string }) => r.id);
      const intIds   = internosNotif.rows.map((r: { id: string }) => r.id);
      const orc      = orcamentosNotif.rows;
      const agend    = agendamentosNotif.rows;
      const prodBx   = produtosNotif.rows;

      // Helper: insere notificação com estado controlado
      const notif = async (
        usuario_id: string,
        tipo: string,
        titulo: string,
        mensagem: string,
        referencia_id: string | null,
        referencia_tipo: string | null,
        lida: boolean,
        push_enviado: boolean
      ) => {
        await db.query(
          `INSERT INTO notifications
             (usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo,
              lida, lido_em, push_enviado, push_enviado_em)
           VALUES ($1, $2, $3, $4, $5, $6,
                   $7, $8, $9, $10)`,
          [
            usuario_id, tipo, titulo, mensagem, referencia_id, referencia_tipo,
            lida,
            lida ? new Date().toISOString() : null,
            push_enviado,
            push_enviado ? new Date().toISOString() : null,
          ]
        );
      };

      // ── Notificações para CLIENTES (RN093) ────────────────────────────────

      // Orçamento ENVIADO → cliente[1] recebe aviso de orçamento pronto
      const orcEnviado = orc.find((o: any) => o.status === 'ENVIADO');
      if (orcEnviado && cliIds[1]) {
        await notif(
          cliIds[1], 'budget',
          'Orçamento disponível para aprovação',
          'Seu orçamento está pronto! Acesse o app para revisar e aprovar.',
          orcEnviado.id, 'orcamento',
          false, true // não lida, push enviado
        );
      }

      // Orçamento APROVADO → cliente[3] recebe confirmação de agendamento
      const orcAprovado = orc.find((o: any) => o.status === 'APROVADO');
      const agendConfirmado = agend[0];
      if (orcAprovado && cliIds[3]) {
        await notif(
          cliIds[3], 'budget',
          'Orçamento aprovado! Serviço agendado.',
          'Seu orçamento foi aprovado e o serviço está agendado. A oficina entrará em contato.',
          orcAprovado.id, 'orcamento',
          true, true // lida, push enviado
        );
        if (agendConfirmado) {
          await notif(
            cliIds[3], 'new_schedule',
            'Agendamento confirmado',
            'Seu veículo está agendado para manutenção. Compareça no horário combinado.',
            agendConfirmado.id, 'agendamento',
            true, true
          );
        }
      }

      // Execução CONCLUIDO → cliente[4] recebe "veículo pronto" (RN093)
      const orcConcluido = orc.find((o: any) => o.status === 'APROVADO' && o !== orcAprovado);
      if (orcConcluido && cliIds[4]) {
        await notif(
          cliIds[4], 'budget',
          'Veículo pronto para retirada! 🚗',
          'A manutenção do seu veículo foi concluída. Passe na oficina para retirar.',
          orcConcluido.id, 'orcamento',
          false, true
        );
      }

      // Status PAGO → cliente[5] recebe lembrete de pagamento confirmado
      const orcPago = orc.find((o: any) => o.status === 'PAGO');
      if (orcPago && cliIds[5]) {
        await notif(
          cliIds[5], 'budget',
          'Pagamento confirmado ✅',
          'Seu pagamento foi registrado. Obrigado por confiar na OmniConnect!',
          orcPago.id, 'orcamento',
          true, true
        );
      }

      // Orçamento REJEITADO → cliente[2] recebe notificação de status atualizado
      const orcRejeitado = orc.find((o: any) => o.status === 'REJEITADO');
      if (orcRejeitado && cliIds[2]) {
        await notif(
          cliIds[2], 'budget',
          'Orçamento recusado',
          'Recebemos sua recusa do orçamento. Entre em contato se quiser negociar.',
          orcRejeitado.id, 'orcamento',
          true, false // lida, push não enviado
        );
      }

      // ── Notificações para INTERNOS — Admin e Mecânicos (RN094) ───────────

      // Nova solicitação / agendamento → todos os internos recebem
      if (agend[0] && intIds.length > 0) {
        for (const uid of intIds) {
          await notif(
            uid, 'new_schedule',
            'Novo agendamento recebido',
            'Um cliente acabou de confirmar um agendamento. Verifique a agenda.',
            agend[0].id, 'agendamento',
            false, true
          );
        }
      }

      // Aprovação de orçamento → internos são notificados (RN094)
      if (orcAprovado && intIds.length > 0) {
        for (const uid of intIds) {
          await notif(
            uid, 'approved_budget',
            'Orçamento aprovado pelo cliente',
            'Um cliente aprovou o orçamento. Inicie a ordem de serviço.',
            orcAprovado.id, 'orcamento',
            false, true
          );
        }
      }

      // Estoque baixo → todos os internos (low_stock usa referencia_tipo: 'produto')
      if (prodBx.length > 0 && intIds.length > 0) {
        for (const prod of prodBx) {
          for (const uid of intIds) {
            await notif(
              uid, 'low_stock',
              'Peça com estoque baixo ⚠️',
              `"${prod.nome}" está com estoque crítico. Solicite reposição.`,
              prod.id, 'produto',
              false, true
            );
          }
        }
      }

      console.log('✓ Notificações inseridas (clientes: budget/new_schedule; internos: approved_budget/new_schedule/low_stock) — RN093/RN094');
    }

    console.log('\n✅ Seeds finalizados com sucesso!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erro na execução dos seeds:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  runSeeds();
}
