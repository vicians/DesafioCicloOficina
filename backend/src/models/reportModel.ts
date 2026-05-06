import { getDb } from '../config/database';

export type ReportStatusItem = {
  label: string;
  value: number;
  total: number;
};

export type ReportTopServiceItem = {
  name: string;
  count: number;
  revenue: number;
};

export type InternalReportDTO = {
  month: string;
  revenue: number;
  revenueGrowth: number;
  services: number;
  servicesGrowth: number;
  avgTicket: number;
  avgTicketGrowth: number;
  pending: number;
  byStatus: ReportStatusItem[];
  topServices: ReportTopServiceItem[];
};

type PeriodMetrics = {
  revenueCents: number;
  concludedCount: number;
  pendingCount: number;
  statusConcluded: number;
  statusInProgress: number;
  statusWaiting: number;
};

const toNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
};

const calcGrowth = (current: number, previous: number): number => {
  if (current === 0) {
    return 0;
  }
  if (previous === 0) {
    return current > 0 ? 100 : 0;
  }
  return ((current - previous) / previous) * 100;
};

export class ReportModel {
  private static async loadPeriodMetrics(start: Date, end: Date): Promise<PeriodMetrics> {
    const db = getDb();
    const result = await db.query(
      `SELECT
         COALESCE(SUM(CASE WHEN e.status = 'CONCLUIDO' THEN o.valor_total ELSE 0 END), 0) AS revenue_cents,
         COALESCE(SUM(CASE WHEN e.status = 'CONCLUIDO' THEN 1 ELSE 0 END), 0) AS concluded_count,
         COALESCE(SUM(CASE WHEN e.status IN ('AGUARDANDO', 'AGUARDANDO_RETIRADA') THEN 1 ELSE 0 END), 0) AS pending_count,
         COALESCE(SUM(CASE WHEN e.status = 'CONCLUIDO' THEN 1 ELSE 0 END), 0) AS status_concluded,
         COALESCE(SUM(CASE WHEN e.status IN ('EM_EXECUCAO', 'REVISAO_TECNICA') THEN 1 ELSE 0 END), 0) AS status_in_progress,
         COALESCE(SUM(CASE WHEN e.status IN ('AGUARDANDO', 'AGUARDANDO_RETIRADA') THEN 1 ELSE 0 END), 0) AS status_waiting
       FROM execucoes_servico e
       JOIN orcamentos o ON o.id = e.orcamento_id
       WHERE COALESCE(e.iniciado_em, o.criado_em) >= $1
         AND COALESCE(e.iniciado_em, o.criado_em) < $2`,
      [start, end]
    );

    const row = result.rows[0] ?? {};
    return {
      revenueCents: toNumber(row.revenue_cents),
      concludedCount: toNumber(row.concluded_count),
      pendingCount: toNumber(row.pending_count),
      statusConcluded: toNumber(row.status_concluded),
      statusInProgress: toNumber(row.status_in_progress),
      statusWaiting: toNumber(row.status_waiting),
    };
  }

  private static async loadTopServices(start: Date, end: Date): Promise<ReportTopServiceItem[]> {
    const db = getDb();
    const result = await db.query(
      `SELECT
         cs.nome AS name,
         COALESCE(SUM(ios.quantidade), 0) AS service_count,
         COALESCE(SUM(ios.quantidade * ios.preco_unitario), 0) AS revenue_cents
       FROM execucoes_servico e
       JOIN orcamentos o ON o.id = e.orcamento_id
       JOIN itens_orcamento_servico ios ON ios.orcamento_id = o.id
       JOIN catalogo_servicos cs ON cs.id = ios.servico_id
       WHERE COALESCE(e.iniciado_em, o.criado_em) >= $1
         AND COALESCE(e.iniciado_em, o.criado_em) < $2
       GROUP BY cs.nome
       ORDER BY service_count DESC, revenue_cents DESC
       LIMIT 5`,
      [start, end]
    );

    return result.rows.map((row: { name: string; service_count: string | number; revenue_cents: string | number }) => ({
      name: row.name,
      count: toNumber(row.service_count),
      revenue: toNumber(row.revenue_cents) / 100,
    }));
  }

  static async getInternalReport(
    start: Date,
    end: Date,
    previousStart: Date,
    previousEnd: Date,
    monthLabel: string,
  ): Promise<InternalReportDTO> {
    const [current, previous, topServices] = await Promise.all([
      this.loadPeriodMetrics(start, end),
      this.loadPeriodMetrics(previousStart, previousEnd),
      this.loadTopServices(start, end),
    ]);

    const revenue = current.revenueCents / 100;
    const previousRevenue = previous.revenueCents / 100;
    const services = current.concludedCount;
    const previousServices = previous.concludedCount;
    const avgTicket = services > 0 ? revenue / services : 0;
    const previousAvgTicket = previousServices > 0 ? previousRevenue / previousServices : 0;

    const statusTotal = current.statusConcluded + current.statusInProgress + current.statusWaiting;

    return {
      month: monthLabel,
      revenue,
      revenueGrowth: calcGrowth(revenue, previousRevenue),
      services,
      servicesGrowth: calcGrowth(services, previousServices),
      avgTicket,
      avgTicketGrowth: calcGrowth(avgTicket, previousAvgTicket),
      pending: current.pendingCount,
      byStatus: [
        { label: 'Concluidos', value: current.statusConcluded, total: statusTotal },
        { label: 'Em andamento', value: current.statusInProgress, total: statusTotal },
        { label: 'Aguardando', value: current.statusWaiting, total: statusTotal },
      ],
      topServices,
    };
  }
}
