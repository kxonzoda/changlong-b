import { supabase } from '@/lib/supabase';
import type { MaintenanceWorkOrder, EquipmentDowntime } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getWorkOrders(limit = 50): Promise<MaintenanceWorkOrder[]> {
  const { data, error } = await supabase
    .from('maintenance_work_orders')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as MaintenanceWorkOrder[];
}

export async function getCriticalMaintenanceCount(): Promise<number> {
  const { data, error } = await supabase
    .from('maintenance_work_orders')
    .select('id')
    .in('priority', ['critical', 'high'])
    .in('status', ['open', 'in_progress', 'overdue']);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data?.length ?? 0;
}

export async function createWorkOrder(payload: {
  equipment_id?: string | null;
  type: 'preventive' | 'corrective' | 'predictive' | 'inspection';
  priority: 'low' | 'medium' | 'high' | 'critical';
  description?: string | null;
  scheduled_date?: string | null;
  assigned_to?: string | null;
}): Promise<MaintenanceWorkOrder> {
  const { data, error } = await supabase
    .from('maintenance_work_orders')
    .insert(payload)
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as MaintenanceWorkOrder;
}

export async function updateWorkOrderStatus(
  id: string,
  status: 'open' | 'in_progress' | 'completed' | 'cancelled' | 'overdue',
  completedDate?: string,
): Promise<void> {
  const updates: Record<string, string> = { status };
  if (status === 'completed' && completedDate) updates.completed_date = completedDate;
  const { error } = await supabase
    .from('maintenance_work_orders')
    .update(updates)
    .eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function getMaintenanceSchedules(limit = 50): Promise<Array<{
  id: string;
  equipment_id: string;
  procedure_id: string | null;
  frequency_days: number;
  next_due_date: string;
  is_active: boolean;
}>> {
  const { data, error } = await supabase
    .from('maintenance_schedules')
    .select('*')
    .order('next_due_date', { ascending: true })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getEquipmentDowntime(equipmentId?: string, days = 30): Promise<EquipmentDowntime[]> {
  const startTime = new Date();
  startTime.setDate(startTime.getDate() - days);
  let query = supabase
    .from('equipment_downtime')
    .select('*')
    .gte('start_time', startTime.toISOString())
    .order('start_time', { ascending: false });
  if (equipmentId) query = query.eq('equipment_id', equipmentId);
  const { data, error } = await query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}
