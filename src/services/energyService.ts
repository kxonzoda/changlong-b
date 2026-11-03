import { supabase } from '@/lib/supabase';
import type { EnergyMeter, EnergyTrendPoint, EnergySource, EnergyAnomaly } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getEnergyMeters(): Promise<EnergyMeter[]> {
  const { data, error } = await supabase
    .from('energy_meters')
    .select('*')
    .eq('is_active', true)
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as EnergyMeter[];
}

export async function getEnergyTrend(days = 30): Promise<EnergyTrendPoint[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('energy_consumption_daily')
    .select(`
      consumption_date,
      total_value,
      unit,
      meter:energy_meters(energy_type)
    `)
    .gte('consumption_date', dateStr)
    .order('consumption_date', { ascending: true });

  if (error) throw ServiceError.fromSupabaseError(error);

  const byDate = new Map<string, EnergyTrendPoint>();
  for (const row of data as unknown as Array<{
    consumption_date: string;
    total_value: number;
    meter: { energy_type: string } | null;
  }>) {
    const point = byDate.get(row.consumption_date) ?? {
      date: row.consumption_date,
      electricity: 0,
      gas: 0,
      water: 0,
    };
    const type = row.meter?.energy_type;
    if (type === 'electricity') point.electricity += Number(row.total_value) || 0;
    else if (type === 'natural_gas') point.gas += Number(row.total_value) || 0;
    else if (type === 'water') point.water += Number(row.total_value) || 0;
    byDate.set(row.consumption_date, point);
  }

  return Array.from(byDate.values()).sort((a, b) => a.date.localeCompare(b.date));
}

export async function getTotalEnergyKwh(days = 30): Promise<number> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('energy_consumption_daily')
    .select('total_value, meter:energy_meters(energy_type)')
    .gte('consumption_date', dateStr);

  if (error) throw ServiceError.fromSupabaseError(error);

  return (data as unknown as Array<{ total_value: number; meter: { energy_type: string } | null }>)
    .filter((r) => r.meter?.energy_type === 'electricity')
    .reduce((sum, r) => sum + (Number(r.total_value) || 0), 0);
}

export async function getEnergySources(): Promise<EnergySource[]> {
  const { data, error } = await supabase
    .from('energy_sources')
    .select('*')
    .eq('is_active', true)
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getEnergyAnomalies(days = 30, limit = 50): Promise<EnergyAnomaly[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];
  const { data, error } = await supabase
    .from('energy_anomalies')
    .select('*')
    .gte('anomaly_date', dateStr)
    .order('anomaly_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function insertEnergyReading(payload: {
  meter_id: string;
  reading_time: string;
  value: number;
  unit: string;
  quality?: 'good' | 'suspect' | 'estimated' | 'invalid';
  is_demo?: boolean;
}): Promise<void> {
  const { error } = await supabase
    .from('energy_readings')
    .insert({
      ...payload,
      quality: payload.quality ?? 'good',
      is_demo: payload.is_demo ?? false,
    });
  if (error) throw ServiceError.fromSupabaseError(error);
}
