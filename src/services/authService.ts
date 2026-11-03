import { supabase } from '@/lib/supabase';
import type { Profile, UserRole } from '@/types/database';
import { ServiceError } from './serviceError';

export async function getCurrentProfile(): Promise<Profile | null> {
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', authData.user.id)
    .maybeSingle();

  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Profile | null;
}

export async function signIn(email: string, password: string): Promise<void> {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function signUp(email: string, password: string, fullName?: string): Promise<void> {
  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName ?? email } },
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function signOut(): Promise<void> {
  const { error } = await supabase.auth.signOut();
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function resetPassword(email: string): Promise<void> {
  const { error } = await supabase.auth.resetPasswordForEmail(email);
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function updateProfile(updates: Partial<Pick<Profile, 'full_name' | 'phone' | 'language'>>): Promise<void> {
  const { data: authData } = await supabase.auth.getUser();
  if (!authData.user) throw new ServiceError('Not authenticated', 'NOT_AUTH');

  const { error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('id', authData.user.id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

export function hasRole(profile: Profile | null, ...roles: UserRole[]): boolean {
  if (!profile) return false;
  return roles.includes(profile.role);
}
