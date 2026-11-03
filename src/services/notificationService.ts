import { supabase } from '@/lib/supabase';
import type { Notification } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getNotifications(): Promise<Notification[]> {
  const { data: authData } = await supabase.auth.getUser();
  if (!authData.user) return [];

  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', authData.user.id)
    .order('created_at', { ascending: false })
    .limit(20);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Notification[];
}

export async function markNotificationRead(id: string): Promise<void> {
  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}
