export function extractBackendErrorMessage(error: any, fallback = 'Erro desconhecido no backend'): string {
  const data = error?.response?.data;

  if (data !== undefined && data !== null) {
    if (typeof data === 'string') return data;
    if (typeof data.error === 'string') return data.error;
    if (Array.isArray(data.error)) return data.error.join(', ');
    if (typeof data.message === 'string') return data.message;
    if (Array.isArray(data.message)) return data.message.join(', ');

    try {
      return JSON.stringify(data);
    } catch {
      return String(data);
    }
  }

  return error?.message ?? fallback;
}

export function getBackendErrorStatus(error: any, fallback = 500): number {
  return error?.response?.status ?? fallback;
}

export function formatBackendValidationError(error: any, fallback?: string): string {
  return `Backend validation failed: ${extractBackendErrorMessage(error, fallback)}`;
}
