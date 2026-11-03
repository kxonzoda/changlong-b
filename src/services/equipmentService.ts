import { supabase } from '@/lib/supabase';
import type {
  Equipment,
  EquipmentTelemetry,
  EquipmentEvent,
  EquipmentOperatingHours,
  EquipmentComponent,
  EquipmentStatus,
} from '@/types/database';
import { ServiceError } from './serviceError';

// ============================================================
// READ OPERATIONS
// ============================================================

export async function getEquipment(): Promise<Equipment[]> {
  const { data, error } = await supabase
    .from('equipment')
    .select('*')
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Equipment[];
}

export async function getEquipmentHealth(): Promise<{ avgHealth: number; operational: number; total: number }> {
  const equipment = await getEquipment();
  const total = equipment.length;
  const operational = equipment.filter((e) => e.status === 'operational').length;
  const avgHealth = total > 0 ? equipment.reduce((s, e) => s + e.health_score, 0) / total : 0;
  return { avgHealth, operational, total };
}

export async function getEquipmentTelemetry(equipmentId: string, hours = 24): Promise<EquipmentTelemetry[]> {
  const startTime = new Date();
  startTime.setHours(startTime.getHours() - hours);
  const { data, error } = await supabase
    .from('equipment_telemetry')
    .select('*')
    .eq('equipment_id', equipmentId)
    .gte('reading_time', startTime.toISOString())
    .order('reading_time', { ascending: true });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as EquipmentTelemetry[];
}

export async function getEquipmentEvents(equipmentId?: string, days = 30): Promise<EquipmentEvent[]> {
  const startTime = new Date();
  startTime.setDate(startTime.getDate() - days);
  let query = supabase
    .from('equipment_events')
    .select('*')
    .gte('event_time', startTime.toISOString())
    .order('event_time', { ascending: false });
  if (equipmentId) query = query.eq('equipment_id', equipmentId);
  const { data, error } = query.limit(100);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getEquipmentOperatingHours(equipmentId?: string, days = 30): Promise<EquipmentOperatingHours[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const dateStr = startDate.toISOString().split('T')[0];
  let query = supabase
    .from('equipment_operating_hours')
    .select('*')
    .gte('record_date', dateStr)
    .order('record_date', { ascending: false });
  if (equipmentId) query = query.eq('equipment_id', equipmentId);
  const { data, error } = query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getEquipmentComponents(equipmentId: string): Promise<EquipmentComponent[]> {
  const { data, error } = await supabase
    .from('equipment_components')
    .select('*')
    .eq('equipment_id', equipmentId)
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

// ============================================================
// TELEMETRY INSERT
// ============================================================

export async function insertEquipmentTelemetry(payload: {
  equipment_id: string;
  metric: string;
  value: number;
  unit: string;
  quality?: 'good' | 'suspect' | 'estimated' | 'invalid';
  is_demo?: boolean;
}): Promise<void> {
  if (!payload.equipment_id) throw new ServiceError('Equipment ID is required', 'VALIDATION_ERROR');
  if (!payload.metric?.trim()) throw new ServiceError('Metric is required', 'VALIDATION_ERROR');
  if (payload.value === undefined || payload.value === null) {
    throw new ServiceError('Value is required', 'VALIDATION_ERROR');
  }
  if (!payload.unit?.trim()) throw new ServiceError('Unit is required', 'VALIDATION_ERROR');

  const { error } = await supabase
    .from('equipment_telemetry')
    .insert({
      ...payload,
      quality: payload.quality ?? 'good',
      is_demo: payload.is_demo ?? false,
    });
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// EQUIPMENT STATUS MANAGEMENT (atomic via SECURITY DEFINER RPC)
// ============================================================

const VALID_STATUSES: EquipmentStatus[] = ['operational', 'idle', 'under_maintenance', 'fault', 'decommissioned'];

/**
 * Update equipment status atomically via SECURITY DEFINER RPC.
 * Inserts a status_change event and a status_history record in the same transaction.
 * Prevents no-op transitions (same status).
 */
export async function updateEquipmentStatus(
  id: string,
  status: EquipmentStatus,
  healthScore?: number,
  reason?: string | null,
): Promise<void> {
  if (!id) throw new ServiceError('Equipment ID is required', 'VALIDATION_ERROR');
  if (!VALID_STATUSES.includes(status)) {
    throw new ServiceError(`Invalid status. Must be one of: ${VALID_STATUSES.join(', ')}`, 'VALIDATION_ERROR');
  }
  if (healthScore !== undefined && (healthScore < 0 || healthScore > 100)) {
    throw new ServiceError('Health score must be between 0 and 100', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.rpc('update_equipment_status', {
    p_equipment_id: id,
    p_new_status: status,
    p_health_score: healthScore ?? null,
    p_reason: reason ?? null,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// EQUIPMENT CRUD
// ============================================================

export async function createEquipment(payload: {
  name: string;
  equipment_code: string;
  category_id?: string | null;
  department_id?: string | null;
  production_line_id?: string | null;
  status?: EquipmentStatus;
  health_score?: number;
  operating_hours?: number;
}): Promise<Equipment> {
  if (!payload.name?.trim()) throw new ServiceError('Equipment name is required', 'VALIDATION_ERROR');
  if (!payload.equipment_code?.trim()) throw new ServiceError('Equipment code is required', 'VALIDATION_ERROR');
  if (payload.health_score !== undefined && (payload.health_score < 0 || payload.health_score > 100)) {
    throw new ServiceError('Health score must be between 0 and 100', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('equipment')
    .insert({
      name: payload.name.trim(),
      equipment_code: payload.equipment_code.trim(),
      category_id: payload.category_id ?? null,
      department_id: payload.department_id ?? null,
      production_line_id: payload.production_line_id ?? null,
      status: payload.status ?? 'operational',
      health_score: payload.health_score ?? 100,
      operating_hours: payload.operating_hours ?? 0,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Equipment;
}

/**
 * Record an equipment event (startup, shutdown, fault, etc.)
 */
export async function recordEquipmentEvent(payload: {
  equipment_id: string;
  event_type: 'startup' | 'shutdown' | 'fault' | 'maintenance_start' | 'maintenance_end' | 'status_change';
  description?: string | null;
}): Promise<void> {
  if (!payload.equipment_id) throw new ServiceError('Equipment ID is required', 'VALIDATION_ERROR');
  if (!payload.event_type) throw new ServiceError('Event type is required', 'VALIDATION_ERROR');

  const { error } = await supabase
    .from('equipment_events')
    .insert({
      equipment_id: payload.equipment_id,
      event_type: payload.event_type,
      description: payload.description ?? null,
      event_time: new Date().toISOString(),
      is_demo: false,
    });
  if (error) throw ServiceError.fromSupabaseError(error);
}

/**
 * Record daily operating hours for equipment.
 * Validates that operating + idle + downtime = 24 hours.
 */
export async function recordOperatingHours(payload: {
  equipment_id: string;
  record_date: string;
  operating_hours: number;
  idle_hours: number;
  downtime_hours: number;
}): Promise<void> {
  if (!payload.equipment_id) throw new ServiceError('Equipment ID is required', 'VALIDATION_ERROR');
  if (!payload.record_date) throw new ServiceError('Record date is required', 'VALIDATION_ERROR');

  const total = payload.operating_hours + payload.idle_hours + payload.downtime_hours;
  if (Math.abs(total - 24) > 0.01) {
    throw new ServiceError(
      `Operating + idle + downtime hours must sum to 24 (got ${total})`,
      'VALIDATION_ERROR',
    );
  }
  if (payload.operating_hours < 0 || payload.idle_hours < 0 || payload.downtime_hours < 0) {
    throw new ServiceError('Hours cannot be negative', 'VALIDATION_ERROR');
  }

  const { error } = await supabase
    .from('equipment_operating_hours')
    .insert({
      equipment_id: payload.equipment_id,
      record_date: payload.record_date,
      operating_hours: payload.operating_hours,
      idle_hours: payload.idle_hours,
      downtime_hours: payload.downtime_hours,
      is_demo: false,
    });
  if (error) throw ServiceError.fromSupabaseError(error);
}
