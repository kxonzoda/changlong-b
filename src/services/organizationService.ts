import { supabase } from '@/lib/supabase';
import type { Department, ProductionLine, Shift } from '@/types/database';
import { ServiceError } from './serviceError';

// ============================================================
// READ OPERATIONS
// ============================================================

export async function getDepartments(): Promise<Department[]> {
  const { data, error } = await supabase
    .from('departments')
    .select('*')
    .eq('is_active', true)
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Department[];
}

export async function getShifts(): Promise<Shift[]> {
  const { data, error } = await supabase
    .from('shifts')
    .select('*')
    .eq('is_active', true)
    .order('start_time');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Shift[];
}

export async function getProductionLines(): Promise<ProductionLine[]> {
  const { data, error } = await supabase
    .from('production_lines')
    .select('*')
    .eq('is_active', true)
    .order('name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as ProductionLine[];
}

// ============================================================
// DEPARTMENT MANAGEMENT
// ============================================================

export async function createDepartment(payload: {
  name: string;
  code: string;
  description?: string | null;
}): Promise<Department> {
  if (!payload.name?.trim()) throw new ServiceError('Department name is required', 'VALIDATION_ERROR');
  if (!payload.code?.trim()) throw new ServiceError('Department code is required', 'VALIDATION_ERROR');

  const { data, error } = await supabase
    .from('departments')
    .insert({
      name: payload.name.trim(),
      code: payload.code.trim(),
      description: payload.description ?? null,
      is_active: true,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Department;
}

export async function updateDepartment(
  id: string,
  updates: Partial<Pick<Department, 'name' | 'code' | 'description'>>,
): Promise<void> {
  if (!id) throw new ServiceError('Department ID is required', 'VALIDATION_ERROR');
  if (updates.name !== undefined && !updates.name.trim()) {
    throw new ServiceError('Department name cannot be empty', 'VALIDATION_ERROR');
  }
  if (updates.code !== undefined && !updates.code.trim()) {
    throw new ServiceError('Department code cannot be empty', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.from('departments').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

/**
 * Deactivate a department (soft delete). Checks for dependent employees first.
 */
export async function deactivateDepartment(id: string): Promise<void> {
  if (!id) throw new ServiceError('Department ID is required', 'VALIDATION_ERROR');

  const { data: employees } = await supabase
    .from('employees')
    .select('id')
    .eq('department_id', id)
    .eq('status', 'active');
  if (employees && employees.length > 0) {
    throw new ServiceError(
      `Cannot deactivate department: ${employees.length} active employee(s) are still assigned`,
      'CONSTRAINT_ERROR',
    );
  }

  const { error } = await supabase
    .from('departments')
    .update({ is_active: false })
    .eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// SHIFT MANAGEMENT
// ============================================================

export async function createShift(payload: {
  name: string;
  start_time: string;
  end_time: string;
  description?: string | null;
}): Promise<Shift> {
  if (!payload.name?.trim()) throw new ServiceError('Shift name is required', 'VALIDATION_ERROR');
  if (!payload.start_time) throw new ServiceError('Start time is required', 'VALIDATION_ERROR');
  if (!payload.end_time) throw new ServiceError('End time is required', 'VALIDATION_ERROR');

  const { data, error } = await supabase
    .from('shifts')
    .insert({
      name: payload.name.trim(),
      start_time: payload.start_time,
      end_time: payload.end_time,
      description: payload.description ?? null,
      is_active: true,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Shift;
}

export async function updateShift(
  id: string,
  updates: Partial<Pick<Shift, 'name' | 'start_time' | 'end_time' | 'description'>>,
): Promise<void> {
  if (!id) throw new ServiceError('Shift ID is required', 'VALIDATION_ERROR');
  if (updates.name !== undefined && !updates.name.trim()) {
    throw new ServiceError('Shift name cannot be empty', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.from('shifts').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

export async function deactivateShift(id: string): Promise<void> {
  if (!id) throw new ServiceError('Shift ID is required', 'VALIDATION_ERROR');

  const { data: employees } = await supabase
    .from('employees')
    .select('id')
    .eq('shift_id', id)
    .eq('status', 'active');
  if (employees && employees.length > 0) {
    throw new ServiceError(
      `Cannot deactivate shift: ${employees.length} active employee(s) are still assigned`,
      'CONSTRAINT_ERROR',
    );
  }

  const { error } = await supabase.from('shifts').update({ is_active: false }).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// PRODUCTION LINE MANAGEMENT
// ============================================================

export async function createProductionLine(payload: {
  name: string;
  code: string;
  department_id?: string | null;
  description?: string | null;
}): Promise<ProductionLine> {
  if (!payload.name?.trim()) throw new ServiceError('Production line name is required', 'VALIDATION_ERROR');
  if (!payload.code?.trim()) throw new ServiceError('Production line code is required', 'VALIDATION_ERROR');

  if (payload.department_id) {
    const { data: dept } = await supabase
      .from('departments')
      .select('id')
      .eq('id', payload.department_id)
      .eq('is_active', true)
      .single();
    if (!dept) throw new ServiceError('Department not found or inactive', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('production_lines')
    .insert({
      name: payload.name.trim(),
      code: payload.code.trim(),
      department_id: payload.department_id ?? null,
      is_active: true,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as ProductionLine;
}

export async function updateProductionLine(
  id: string,
  updates: Partial<Pick<ProductionLine, 'name' | 'code' | 'department_id'>>,
): Promise<void> {
  if (!id) throw new ServiceError('Production line ID is required', 'VALIDATION_ERROR');

  if (updates.department_id) {
    const { data: dept } = await supabase
      .from('departments')
      .select('id')
      .eq('id', updates.department_id)
      .eq('is_active', true)
      .single();
    if (!dept) throw new ServiceError('Department not found or inactive', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.from('production_lines').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}
