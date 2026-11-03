import { supabase } from '@/lib/supabase';
import type { QualityInspection, QualityMeasurement, QualityStandard, QualityBatch, LaboratoryResult, QualityParameter } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getQualityStandards(): Promise<QualityStandard[]> {
  const { data, error } = await supabase
    .from('quality_standards')
    .select('*')
    .eq('is_active', true)
    .order('steel_grade, parameter');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as QualityStandard[];
}

export async function getQualityInspections(limit = 50): Promise<QualityInspection[]> {
  const { data, error } = await supabase
    .from('quality_inspections')
    .select('*')
    .order('inspection_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as QualityInspection[];
}

export async function getQualityMeasurements(inspectionId: string): Promise<QualityMeasurement[]> {
  const { data, error } = await supabase
    .from('quality_measurements')
    .select('*')
    .eq('inspection_id', inspectionId)
    .order('parameter');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as QualityMeasurement[];
}

export async function getQualityStats(): Promise<{ total: number; passed: number; failed: number; conditional: number; passRate: number }> {
  const inspections = await getQualityInspections(100);
  const total = inspections.length;
  const passed = inspections.filter((i) => i.result === 'pass').length;
  const failed = inspections.filter((i) => i.result === 'fail').length;
  const conditional = inspections.filter((i) => i.result === 'conditional').length;
  const passRate = total > 0 ? (passed / total) * 100 : 0;
  return { total, passed, failed, conditional, passRate };
}

export async function getQualityBatches(limit = 50): Promise<QualityBatch[]> {
  const { data, error } = await supabase
    .from('quality_batches')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getLaboratoryResults(batchId?: string, limit = 50): Promise<LaboratoryResult[]> {
  let query = supabase
    .from('laboratory_results')
    .select('*')
    .order('test_date', { ascending: false })
    .limit(limit);
  if (batchId) query = query.eq('batch_id', batchId);
  const { data, error } = query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getQualityParameters(): Promise<QualityParameter[]> {
  const { data, error } = await supabase
    .from('quality_parameters')
    .select('*')
    .eq('is_active', true)
    .order('category, name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function createQualityInspection(payload: {
  batch_id?: string | null;
  steel_grade?: string | null;
  inspector_id?: string | null;
  inspection_date: string;
  result: 'pass' | 'fail' | 'conditional';
  notes?: string | null;
}): Promise<QualityInspection> {
  const { data, error } = await supabase
    .from('quality_inspections')
    .insert(payload)
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as QualityInspection;
}
