import { supabase } from '@/lib/supabase';
import type { ProductionRecord, ProductionTrendPoint, ProductionBatch, ProductionShift } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getProductionRecords(days = 30): Promise<ProductionRecord[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const { data, error } = await supabase
    .from('production_records')
    .select('*')
    .gte('record_date', startDate.toISOString().split('T')[0])
    .order('record_date', { ascending: false });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as ProductionRecord[];
}

export async function getProductionTrend(days = 30): Promise<ProductionTrendPoint[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('production_records')
    .select('record_date, output_weight_kg, target_weight_kg')
    .gte('record_date', dateStr)
    .order('record_date', { ascending: true });

  if (error) throw ServiceError.fromSupabaseError(error);

  const byDate = new Map<string, { output: number; target: number }>();
  for (const row of data as ProductionRecord[]) {
    const existing = byDate.get(row.record_date) ?? { output: 0, target: 0 };
    existing.output += Number(row.output_weight_kg) || 0;
    existing.target += Number(row.target_weight_kg) || 0;
    byDate.set(row.record_date, existing);
  }

  return Array.from(byDate.entries())
    .map(([date, v]) => ({ date, output_kg: v.output, target_kg: v.target }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

export async function getTotalOutputKg(days = 30): Promise<number> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const { data, error } = await supabase
    .from('production_records')
    .select('output_weight_kg')
    .gte('record_date', startDate.toISOString().split('T')[0]);
  if (error) throw ServiceError.fromSupabaseError(error);
  return (data as ProductionRecord[]).reduce((sum, r) => sum + (Number(r.output_weight_kg) || 0), 0);
}

export async function getProductionBatches(limit = 50): Promise<ProductionBatch[]> {
  const { data, error } = await supabase
    .from('production_batches')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as ProductionBatch[];
}

export async function getProductionShifts(days = 30): Promise<ProductionShift[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];
  const { data, error } = await supabase
    .from('production_shifts')
    .select('*')
    .gte('record_date', dateStr)
    .order('record_date', { ascending: false });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function createProductionRecord(payload: {
  production_line_id?: string | null;
  shift_id?: string | null;
  batch_id?: string | null;
  record_date: string;
  steel_grade?: string | null;
  output_weight_kg: number;
  rejected_weight_kg?: number;
  target_weight_kg?: number | null;
  operator_id?: string | null;
  notes?: string | null;
}): Promise<ProductionRecord> {
  const { data, error } = await supabase
    .from('production_records')
    .insert(payload)
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as ProductionRecord;
}
