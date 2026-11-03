import { supabase } from '@/lib/supabase';
import type { Profile, UserRole } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getAllProfiles(): Promise<Profile[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .order('full_name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Profile[];
}

export async function updateProfileRole(userId: string, role: UserRole): Promise<void> {
  const { data: currentUser } = await supabase.auth.getUser();
  if (!currentUser.user) throw new ServiceError('Not authenticated', 'NOT_AUTH');

  if (currentUser.user.id === userId) {
    throw new ServiceError('Cannot change your own role', 'SELF_ROLE_CHANGE');
  }

  const { error } = await supabase.rpc('admin_update_profile', {
    p_target_user_id: userId,
    p_role: role,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function setUserActive(userId: string, isActive: boolean): Promise<void> {
  const { data: currentUser } = await supabase.auth.getUser();
  if (!currentUser.user) throw new ServiceError('Not authenticated', 'NOT_AUTH');

  const { error } = await supabase.rpc('admin_update_profile', {
    p_target_user_id: userId,
    p_is_active: isActive,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function assignDepartment(userId: string, departmentId: string | null): Promise<void> {
  const { data: currentUser } = await supabase.auth.getUser();
  if (!currentUser.user) throw new ServiceError('Not authenticated', 'NOT_AUTH');

  const { error } = await supabase.rpc('admin_update_profile', {
    p_target_user_id: userId,
    p_department_id: departmentId,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function getAuditLogs(limit = 50): Promise<Array<{
  id: string;
  user_id: string;
  action: string;
  entity_type: string;
  entity_id: string | null;
  details: Record<string, unknown> | null;
  created_at: string;
}>> {
  const { data, error } = await supabase
    .from('audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getSystemEvents(limit = 50): Promise<Array<{
  id: string;
  event_type: string;
  severity: string;
  message: string;
  source: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
}>> {
  const { data, error } = await supabase
    .from('system_events')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}
