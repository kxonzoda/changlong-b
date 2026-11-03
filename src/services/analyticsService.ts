import { supabase } from '@/lib/supabase';
import type { MaintenanceCompletionRate } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getMaintenanceCompletionRate(days = 30): Promise<MaintenanceCompletionRate> {
  const { data, error } = await supabase.rpc('get_maintenance_completion_rate', { p_days: days });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as MaintenanceCompletionRate;
}

export async function getProductionEfficiency(days = 30): Promise<number> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('production_records')
    .select('output_weight_kg, target_weight_kg')
    .gte('record_date', dateStr);

  if (error) throw ServiceError.fromSupabaseError(error);

  const records = data ?? [];
  const totalOutput = records.reduce((s, r) => s + (Number(r.output_weight_kg) || 0), 0);
  const totalTarget = records.reduce((s, r) => s + (Number(r.target_weight_kg) || 0), 0);
  return totalTarget > 0 ? (totalOutput / totalTarget) * 100 : 0;
}

export async function getRejectionRate(days = 30): Promise<number> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('production_records')
    .select('output_weight_kg, rejected_weight_kg')
    .gte('record_date', dateStr);

  if (error) throw ServiceError.fromSupabaseError(error);

  const records = data ?? [];
  const totalOutput = records.reduce((s, r) => s + (Number(r.output_weight_kg) || 0), 0);
  const totalRejected = records.reduce((s, r) => s + (Number(r.rejected_weight_kg) || 0), 0);
  return totalOutput > 0 ? (totalRejected / totalOutput) * 100 : 0;
}

export async function getEnergyIntensity(days = 30): Promise<number> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const [energyRes, prodRes] = await Promise.all([
    supabase
      .from('energy_consumption_daily')
      .select('total_value, meter:energy_meters(energy_type)')
      .gte('consumption_date', dateStr),
    supabase
      .from('production_records')
      .select('output_weight_kg')
      .gte('record_date', dateStr),
  ]);

  if (energyRes.error) throw ServiceError.fromSupabaseError(energyRes.error);
  if (prodRes.error) throw ServiceError.fromSupabaseError(prodRes.error);

  const totalKwh = (energyRes.data ?? [])
    .filter((r) => (r as unknown as { meter: { energy_type: string } | null }).meter?.energy_type === 'electricity')
    .reduce((s, r) => s + (Number(r.total_value) || 0), 0);

  const totalOutputKg = (prodRes.data ?? []).reduce((s, r) => s + (Number(r.output_weight_kg) || 0), 0);
  const totalOutputTons = totalOutputKg / 1000;
  return totalOutputTons > 0 ? totalKwh / totalOutputTons : 0;
}

export async function getEquipmentDowntimeByEquipment(equipmentId?: string, days = 30): Promise<Array<{
  equipment_id: string;
  equipment_code: string;
  equipment_name: string;
  total_downtime_hours: number;
  downtime_count: number;
}>> {
  const startTime = new Date();
  startTime.setDate(startTime.getDate() - days);

  let query = supabase
    .from('equipment_downtime')
    .select(`
      equipment_id,
      duration_hours,
      equipment:equipment(id, equipment_code, name)
    `)
    .gte('start_time', startTime.toISOString())
    .not('end_time', 'is', null);

  if (equipmentId) query = query.eq('equipment_id', equipmentId);

  const { data, error } = await query;
  if (error) throw ServiceError.fromSupabaseError(error);

  const byEquipment = new Map<string, { equipment_id: string; equipment_code: string; equipment_name: string; total_downtime_hours: number; downtime_count: number }>();
  for (const row of data ?? []) {
    const eq = row.equipment as unknown as { id: string; equipment_code: string; name: string } | null;
    if (!eq) continue;
    const existing = byEquipment.get(row.equipment_id) ?? {
      equipment_id: row.equipment_id,
      equipment_code: eq.equipment_code,
      equipment_name: eq.name,
      total_downtime_hours: 0,
      downtime_count: 0,
    };
    existing.total_downtime_hours += Number(row.duration_hours) || 0;
    existing.downtime_count += 1;
    byEquipment.set(row.equipment_id, existing);
  }

  return Array.from(byEquipment.values()).sort((a, b) => b.total_downtime_hours - a.total_downtime_hours);
}

export async function getStockMovementSummary(days = 30): Promise<{
  total_incoming: number;
  total_outgoing: number;
  total_adjustments: number;
  movement_count: number;
}> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('stock_transactions')
    .select('transaction_type, quantity')
    .gte('transaction_date', dateStr);

  if (error) throw ServiceError.fromSupabaseError(error);

  const rows = data ?? [];
  return {
    total_incoming: rows.filter((r) => r.transaction_type === 'receipt').reduce((s, r) => s + (Number(r.quantity) || 0), 0),
    total_outgoing: rows.filter((r) => r.transaction_type === 'issue').reduce((s, r) => s + (Number(r.quantity) || 0), 0),
    total_adjustments: rows.filter((r) => r.transaction_type === 'adjustment').reduce((s, r) => s + (Number(r.quantity) || 0), 0),
    movement_count: rows.length,
  };
}
