import { Request, Response } from 'express';
import { ReportModel } from '../models/reportModel';

type ReportPeriod = 'day' | 'month' | 'year';

const monthFormatter = new Intl.DateTimeFormat('pt-BR', {
  month: 'long',
  year: 'numeric',
});

const dayFormatter = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
});

const capitalize = (text: string): string => {
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1);
};

const parsePeriodQuery = (period?: string): ReportPeriod => {
  if (!period) return 'month';
  if (period === 'day' || period === 'month' || period === 'year') {
    return period;
  }
  throw new Error('Query param period inválido. Use day, month ou year.');
};

const parseMonthQuery = (month?: string): Date => {
  if (!month) {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  }

  const match = /^(\d{4})-(\d{2})$/.exec(month);
  if (!match) {
    throw new Error('Query param month inválido. Use YYYY-MM.');
  }

  const year = Number(match[1]);
  const monthIndex = Number(match[2]) - 1;

  if (!Number.isInteger(year) || !Number.isInteger(monthIndex) || monthIndex < 0 || monthIndex > 11) {
    throw new Error('Query param month inválido. Use YYYY-MM.');
  }

  return new Date(year, monthIndex, 1);
};

const parseDayQuery = (date?: string): Date => {
  if (!date) {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!match) {
    throw new Error('Query param date inválido. Use YYYY-MM-DD.');
  }

  const year = Number(match[1]);
  const monthIndex = Number(match[2]) - 1;
  const day = Number(match[3]);
  const parsed = new Date(year, monthIndex, day);

  if (
    !Number.isInteger(year) ||
    !Number.isInteger(monthIndex) ||
    !Number.isInteger(day) ||
    monthIndex < 0 ||
    monthIndex > 11 ||
    parsed.getFullYear() !== year ||
    parsed.getMonth() !== monthIndex ||
    parsed.getDate() !== day
  ) {
    throw new Error('Query param date inválido. Use YYYY-MM-DD.');
  }

  return parsed;
};

const parseYearQuery = (year?: string): Date => {
  if (!year) {
    const now = new Date();
    return new Date(now.getFullYear(), 0, 1);
  }

  const match = /^(\d{4})$/.exec(year);
  if (!match) {
    throw new Error('Query param year inválido. Use YYYY.');
  }

  const parsedYear = Number(match[1]);
  if (!Number.isInteger(parsedYear) || parsedYear < 1900 || parsedYear > 9999) {
    throw new Error('Query param year inválido. Use YYYY.');
  }

  return new Date(parsedYear, 0, 1);
};

const resolveIntervals = (period: ReportPeriod, req: Request): {
  start: Date;
  end: Date;
  previousStart: Date;
  previousEnd: Date;
  label: string;
} => {
  if (period === 'day') {
    const baseDay = parseDayQuery(
      typeof req.query.date === 'string' ? req.query.date : undefined,
    );
    const start = new Date(baseDay.getFullYear(), baseDay.getMonth(), baseDay.getDate());
    const end = new Date(baseDay.getFullYear(), baseDay.getMonth(), baseDay.getDate() + 1);
    const previousStart = new Date(baseDay.getFullYear(), baseDay.getMonth(), baseDay.getDate() - 1);
    const previousEnd = new Date(baseDay.getFullYear(), baseDay.getMonth(), baseDay.getDate());
    return {
      start,
      end,
      previousStart,
      previousEnd,
      label: dayFormatter.format(start),
    };
  }

  if (period === 'year') {
    const baseYear = parseYearQuery(
      typeof req.query.year === 'string' ? req.query.year : undefined,
    );
    const year = baseYear.getFullYear();
    return {
      start: new Date(year, 0, 1),
      end: new Date(year + 1, 0, 1),
      previousStart: new Date(year - 1, 0, 1),
      previousEnd: new Date(year, 0, 1),
      label: String(year),
    };
  }

  const baseMonth = parseMonthQuery(
    typeof req.query.month === 'string' ? req.query.month : undefined,
  );
  const start = new Date(baseMonth.getFullYear(), baseMonth.getMonth(), 1);
  return {
    start,
    end: new Date(baseMonth.getFullYear(), baseMonth.getMonth() + 1, 1),
    previousStart: new Date(baseMonth.getFullYear(), baseMonth.getMonth() - 1, 1),
    previousEnd: new Date(baseMonth.getFullYear(), baseMonth.getMonth(), 1),
    label: capitalize(monthFormatter.format(start)),
  };
};

export class ReportController {
  static async internal(req: Request, res: Response) {
    try {
      const period = parsePeriodQuery(
        typeof req.query.period === 'string' ? req.query.period : undefined,
      );
      const { start, end, previousStart, previousEnd, label } = resolveIntervals(period, req);

      const report = await ReportModel.getInternalReport(
        start,
        end,
        previousStart,
        previousEnd,
        label,
      );
      return res.json(report);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Falha ao gerar relatório';
      const status =
        message.includes('period inválido') ||
        message.includes('month inválido') ||
        message.includes('date inválido') ||
        message.includes('year inválido')
          ? 400
          : 500;
      return res.status(status).json({ error: message });
    }
  }
}
