import { z, type ZodType } from 'zod';
import { AppError } from './errors.js';

export function parse<T extends ZodType>(schema: T, data: unknown): z.infer<T> {
  const r = schema.safeParse(data);
  if (!r.success) {
    const issues = r.error.issues.map((i) => ({ field: i.path.join('.'), message: i.message }));
    const first = issues[0];
    throw new AppError(400, 'VALIDATION_ERROR', first ? `${first.field ? first.field + ': ' : ''}${first.message}` : 'Invalid request', { issues });
  }
  return r.data;
}

export const uuid = z.string().uuid();
export const rupees = z.union([z.string(), z.number()]).transform((v) => String(v)).refine((v) => /^\d{1,9}(\.\d{1,2})?$/.test(v), 'Enter an amount like 99 or 99.50');
export const pageParams = z.object({ page: z.coerce.number().int().min(1).default(1), limit: z.coerce.number().int().min(1).max(100).default(20) });
