export function nextBusinessDay9am(): Date {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  while (d.getDay() === 0 || d.getDay() === 6) {
    d.setDate(d.getDate() + 1);
  }
  d.setHours(9, 0, 0, 0);
  return d;
}

const REQUESTED_DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

function startOfLocalDay(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}

export function toDateOnlyString(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function parseRequestedAppointmentDate(requestedDate: string): Date {
  const trimmed = requestedDate.trim();
  const match = REQUESTED_DATE_PATTERN.exec(trimmed);

  if (!match) {
    throw new Error('requestedDate deve estar no formato YYYY-MM-DD.');
  }

  const [, yearText, monthText, dayText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const utcDate = new Date(Date.UTC(year, month - 1, day));

  if (
    utcDate.getUTCFullYear() !== year ||
    utcDate.getUTCMonth() !== month - 1 ||
    utcDate.getUTCDate() !== day
  ) {
    throw new Error('requestedDate deve ser uma data valida.');
  }

  const weekDay = utcDate.getUTCDay();
  if (weekDay === 0 || weekDay === 6) {
    throw new Error('requestedDate deve cair em um dia util.');
  }

  const appointmentDate = new Date(year, month - 1, day, 9, 0, 0, 0);
  if (startOfLocalDay(appointmentDate) < startOfLocalDay(new Date())) {
    throw new Error('requestedDate nao pode ser uma data passada.');
  }

  return appointmentDate;
}

export function isValidRequestedAppointmentDate(requestedDate: string): boolean {
  try {
    parseRequestedAppointmentDate(requestedDate);
    return true;
  } catch {
    return false;
  }
}

export function resolveAppointmentDate(requestedDate?: string): Date {
  if (typeof requestedDate === 'string' && requestedDate.trim()) {
    return parseRequestedAppointmentDate(requestedDate);
  }

  return nextBusinessDay9am();
}
