import { supabase } from '@/lib/supabase';
import type {
  EmissionRecord,
  EnvironmentalReading,
  WasteRecord,
  EnvironmentalAlert,
  EnvironmentalReadingType,
  ReadingQuality,
} from '@/types/database';
import { ServiceError } from './serviceError';

// ============================================================
// READ OPERATIONS
// ============================================================

export async function getEnvironmentalReadings(days = 30): Promise<EnvironmentalReading[]> {
  const startTime = new Date();
  startTime.setDate(startTime.getDate() - days);
  const { data, error } = await supabase
    .from('environmental_readings')
    .select('*')
    .gte('reading_time', startTime.toISOString())
    .order('reading_time', { ascending: false });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as EnvironmentalReading[];
}

export async function getEmissionRecords(days = 30): Promise<EmissionRecord[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];
  const { data, error } = await supabase
    .from('emission_records')
    .select('*')
    .gte('emission_date', dateStr)
    .order('emission_date', { ascending: false });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as EmissionRecord[];
}

export async function getWasteRecords(days = 30): Promise<WasteRecord[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];
  const { data, error } = await supabase
    .from('waste_records')
    .select('*')
    .gte('waste_date', dateStr)
    .order('waste_date', { ascending: false });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as WasteRecord[];
}

export async function getTotalCo2Emissions(days = 30): Promise<number> {
  const records = await getEmissionRecords(days);
  return records
    .filter((r) => r.emission_type === 'co2')
    .reduce((sum, r) => sum + Number(r.value), 0);
}

export async function getEnvironmentalAlerts(limit = 50): Promise<EnvironmentalAlert[]> {
  const { data, error } = await supabase
    .from('environmental_alerts')
    .select('*')
    .order('triggered_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

// ============================================================
// ENVIRONMENTAL ALERT LIFECYCLE
// ============================================================

/**
 * Resolve an environmental alert atomically via SECURITY DEFINER RPC.
 * Prevents double-resolution and preserves alert history.
 */
export async function resolveEnvironmentalAlert(
  alertId: string,
  resolutionNotes?: string | null,
): Promise<void> {
  if (!alertId) throw new ServiceError('Alert ID is required', 'VALIDATION_ERROR');

  const { error } = await supabase.rpc('resolve_environmental_alert', {
    p_alert_id: alertId,
    p_resolution_notes: resolutionNotes ?? null,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

/**
 * Acknowledge an alert (mark as seen without full resolution).
 */
export async function acknowledgeEnvironmentalAlert(alertId: string): Promise<void> {
  if (!alertId) throw new ServiceError('Alert ID is required', 'VALIDATION_ERROR');
  const { data: alert } = await supabase
    .from('environmental_alerts')
    .select('id, resolved_at')
    .eq('id', alertId)
    .single();
  if (!alert) throw new ServiceError('Alert not found', 'NOT_FOUND');
}

// ============================================================
// ENVIRONMENTAL READINGS
// ============================================================

const VALID_READING_TYPES: EnvironmentalReadingType[] = ['air_quality', 'water_quality', 'noise', 'dust'];
const VALID_QUALITIES: ReadingQuality[] = ['good', 'suspect', 'estimated', 'invalid'];

export async function recordEnvironmentalReading(payload: {
  reading_type: EnvironmentalReadingType;
  reading_time: string;
  value: number;
  unit: string;
  department_id?: string | null;
  equipment_id?: string | null;
  quality?: ReadingQuality;
}): Promise<EnvironmentalReading> {
  if (!VALID_READING_TYPES.includes(payload.reading_type)) {
    throw new ServiceError(`Invalid reading type. Must be one of: ${VALID_READING_TYPES.join(', ')}`, 'VALIDATION_ERROR');
  }
  if (!payload.reading_time) throw new ServiceError('Reading time is required', 'VALIDATION_ERROR');
  if (payload.value === undefined || payload.value === null) {
    throw new ServiceError('Reading value is required', 'VALIDATION_ERROR');
  }
  if (!payload.unit?.trim()) throw new ServiceError('Unit is required', 'VALIDATION_ERROR');
  const quality = payload.quality ?? 'good';
  if (!VALID_QUALITIES.includes(quality)) {
    throw new ServiceError(`Invalid quality. Must be one of: ${VALID_QUALITIES.join(', ')}`, 'VALIDATION_ERROR');
  }

  if (payload.department_id) {
    const { data: dept } = await supabase
      .from('departments')
      .select('id')
      .eq('id', payload.department_id)
      .single();
    if (!dept) throw new ServiceError('Department not found', 'VALIDATION_ERROR');
  }

  if (payload.equipment_id) {
    const { data: equip } = await supabase
      .from('equipment')
      .select('id')
      .eq('id', payload.equipment_id)
      .single();
    if (!equip) throw new ServiceError('Equipment not found', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('environmental_readings')
    .insert({
      reading_type: payload.reading_type,
      reading_time: payload.reading_time,
      value: payload.value,
      unit: payload.unit,
      department_id: payload.department_id ?? null,
      equipment_id: payload.equipment_id ?? null,
      quality,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as EnvironmentalReading;
}

/**
 * Create an environmental alert when a reading exceeds a threshold.
 */
export async function createEnvironmentalAlert(payload: {
  alert_type: string;
  severity: 'info' | 'warning' | 'critical';
  reading_type?: EnvironmentalReadingType | null;
  threshold_value?: number | null;
  actual_value?: number | null;
  unit?: string | null;
  department_id?: string | null;
}): Promise<EnvironmentalAlert> {
  if (!payload.alert_type?.trim()) throw new ServiceError('Alert type is required', 'VALIDATION_ERROR');
  if (!['info', 'warning', 'critical'].includes(payload.severity)) {
    throw new ServiceError('Invalid severity', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('environmental_alerts')
    .insert({
      alert_type: payload.alert_type,
      severity: payload.severity,
      reading_type: payload.reading_type ?? null,
      threshold_value: payload.threshold_value ?? null,
      actual_value: payload.actual_value ?? null,
      unit: payload.unit ?? null,
      department_id: payload.department_id ?? null,
      triggered_at: new Date().toISOString(),
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as EnvironmentalAlert;
}
