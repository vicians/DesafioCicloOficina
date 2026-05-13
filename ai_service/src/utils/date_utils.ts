export function nextBusinessDay9am(): Date {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  while (d.getDay() === 0 || d.getDay() === 6) {
    d.setDate(d.getDate() + 1);
  }
  d.setHours(9, 0, 0, 0);
  return d;
}
