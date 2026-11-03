export class ServiceError extends Error {
  constructor(
    message: string,
    public readonly code: string = 'UNKNOWN',
    public readonly details?: unknown
  ) {
    super(message);
    this.name = 'ServiceError';
  }

  static fromSupabaseError(error: { code?: string; message: string; details?: unknown }): ServiceError {
    return new ServiceError(error.message, error.code ?? 'DATABASE_ERROR', error.details);
  }
}
