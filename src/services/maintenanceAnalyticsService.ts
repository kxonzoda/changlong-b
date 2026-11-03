import { supabase } from '@/lib/supabase';
import type { MtbfResult, MttrResult, MaintenanceProcedure, MaintenancePart } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getEquipmentMtbf(equipmentId?: string, days = 30): Promise<MtbfResult[]> {
  const { data, error } = await supabase.rpc('get_equipment_mtbf', {
    p_equipment_id: equipmentId ?? null,
    p_days: days,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
  return (data ?? []) as MtbfResult[];
}

export async function getEquipmentMttr(equipmentId?: string, days = 30): Promise<MttrResult[]> {
  const { data, error } = await supabase.rpc('get_equipment_mttr', {
    p_equipment_id: equipmentId ?? null,
    p_days: days,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
  return (data ?? []) as MttrResult[];
}

export async function getMaintenanceProcedures(): Promise<MaintenanceProcedure[]> {
  const { data, error } = await supabase
    .from('maintenance_procedures')
    .select('*')
    .eq('is_active', true)
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getMaintenanceParts(workOrderId: string): Promise<MaintenancePart[]> {
  const { data, error } = await supabase
    .from('maintenance_parts')
    .select('*')
    .eq('work_order_id', workOrderId)
    .order('created_at');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}
