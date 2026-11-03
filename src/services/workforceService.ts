import { supabase } from '@/lib/supabase';
import type {
  AttendanceRecord,
  Qualification,
  TrainingRecord,
  Employee,
  EmployeeStatus,
  AttendanceStatus,
  TrainingStatus,
  WorkforceAssignment,
  EmployeeShift,
} from '@/types/database';
import { ServiceError } from './serviceError';

// ============================================================
// EMPLOYEE CRUD
// ============================================================

export async function getEmployees(): Promise<Employee[]> {
  const { data, error } = await supabase
    .from('employees')
    .select('*')
    .order('full_name');
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function createEmployee(payload: {
  employee_number: string;
  full_name: string;
  department_id?: string | null;
  position?: string | null;
  shift_id?: string | null;
  hire_date?: string | null;
  status?: EmployeeStatus;
}): Promise<Employee> {
  if (!payload.employee_number?.trim()) throw new ServiceError('Employee number is required', 'VALIDATION_ERROR');
  if (!payload.full_name?.trim()) throw new ServiceError('Full name is required', 'VALIDATION_ERROR');

  if (payload.department_id) {
    const { data: dept } = await supabase
      .from('departments')
      .select('id')
      .eq('id', payload.department_id)
      .eq('is_active', true)
      .single();
    if (!dept) throw new ServiceError('Department not found or inactive', 'VALIDATION_ERROR');
  }

  if (payload.shift_id) {
    const { data: shift } = await supabase
      .from('shifts')
      .select('id')
      .eq('id', payload.shift_id)
      .eq('is_active', true)
      .single();
    if (!shift) throw new ServiceError('Shift not found or inactive', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('employees')
    .insert({
      employee_number: payload.employee_number.trim(),
      full_name: payload.full_name.trim(),
      department_id: payload.department_id ?? null,
      position: payload.position ?? null,
      shift_id: payload.shift_id ?? null,
      hire_date: payload.hire_date ?? null,
      status: payload.status ?? 'active',
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Employee;
}

export async function updateEmployee(
  id: string,
  updates: Partial<Pick<Employee, 'full_name' | 'department_id' | 'position' | 'shift_id' | 'hire_date' | 'status'>>,
): Promise<void> {
  if (!id) throw new ServiceError('Employee ID is required', 'VALIDATION_ERROR');

  if (updates.department_id) {
    const { data: dept } = await supabase
      .from('departments')
      .select('id')
      .eq('id', updates.department_id)
      .eq('is_active', true)
      .single();
    if (!dept) throw new ServiceError('Department not found or inactive', 'VALIDATION_ERROR');
  }

  if (updates.shift_id) {
    const { data: shift } = await supabase
      .from('shifts')
      .select('id')
      .eq('id', updates.shift_id)
      .eq('is_active', true)
      .single();
    if (!shift) throw new ServiceError('Shift not found or inactive', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.from('employees').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// WORKFORCE ASSIGNMENTS
// ============================================================

export async function getWorkforceAssignments(employeeId?: string): Promise<WorkforceAssignment[]> {
  let query = supabase
    .from('workforce_assignments')
    .select('*')
    .order('start_date', { ascending: false });
  if (employeeId) query = query.eq('employee_id', employeeId);
  const { data, error } = query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function assignEmployee(payload: {
  employee_id: string;
  department_id?: string | null;
  production_line_id?: string | null;
  role_title?: string | null;
  start_date: string;
}): Promise<WorkforceAssignment> {
  if (!payload.employee_id) throw new ServiceError('Employee ID is required', 'VALIDATION_ERROR');
  if (!payload.start_date) throw new ServiceError('Start date is required', 'VALIDATION_ERROR');

  const { data: emp } = await supabase
    .from('employees')
    .select('id')
    .eq('id', payload.employee_id)
    .single();
  if (!emp) throw new ServiceError('Employee not found', 'NOT_FOUND');

  if (payload.department_id) {
    const { data: dept } = await supabase
      .from('departments')
      .select('id')
      .eq('id', payload.department_id)
      .eq('is_active', true)
      .single();
    if (!dept) throw new ServiceError('Department not found or inactive', 'VALIDATION_ERROR');
  }

  if (payload.production_line_id) {
    const { data: line } = await supabase
      .from('production_lines')
      .select('id')
      .eq('id', payload.production_line_id)
      .eq('is_active', true)
      .single();
    if (!line) throw new ServiceError('Production line not found or inactive', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('workforce_assignments')
    .insert({
      employee_id: payload.employee_id,
      department_id: payload.department_id ?? null,
      production_line_id: payload.production_line_id ?? null,
      role_title: payload.role_title ?? null,
      start_date: payload.start_date,
      is_active: true,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as WorkforceAssignment;
}

export async function endAssignment(assignmentId: string, endDate: string): Promise<void> {
  if (!assignmentId) throw new ServiceError('Assignment ID is required', 'VALIDATION_ERROR');
  if (!endDate) throw new ServiceError('End date is required', 'VALIDATION_ERROR');

  const { error } = await supabase
    .from('workforce_assignments')
    .update({ end_date: endDate, is_active: false })
    .eq('id', assignmentId);
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// SHIFT ASSIGNMENTS (via atomic RPC)
// ============================================================

export async function assignEmployeeShift(
  employeeId: string,
  shiftId: string,
  effectiveDate?: string,
): Promise<string> {
  if (!employeeId) throw new ServiceError('Employee ID is required', 'VALIDATION_ERROR');
  if (!shiftId) throw new ServiceError('Shift ID is required', 'VALIDATION_ERROR');

  const { data, error } = await supabase.rpc('assign_employee_shift', {
    p_employee_id: employeeId,
    p_shift_id: shiftId,
    p_effective_date: effectiveDate ?? new Date().toISOString().split('T')[0],
  });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as unknown as string;
}

export async function getEmployeeShifts(employeeId?: string): Promise<EmployeeShift[]> {
  let query = supabase
    .from('employee_shifts')
    .select('*')
    .order('effective_date', { ascending: false });
  if (employeeId) query = query.eq('employee_id', employeeId);
  const { data, error } = query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

// ============================================================
// ATTENDANCE MANAGEMENT
// ============================================================

export async function getAttendanceRecords(days = 30): Promise<AttendanceRecord[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  const { data, error } = await supabase
    .from('attendance_records')
    .select('*')
    .gte('record_date', startDate.toISOString().split('T')[0])
    .order('record_date', { ascending: false });
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function recordAttendance(payload: {
  employee_id: string;
  record_date: string;
  status: AttendanceStatus;
  hours_worked?: number;
}): Promise<AttendanceRecord> {
  if (!payload.employee_id) throw new ServiceError('Employee ID is required', 'VALIDATION_ERROR');
  if (!payload.record_date) throw new ServiceError('Record date is required', 'VALIDATION_ERROR');
  if (payload.hours_worked !== undefined && payload.hours_worked < 0) {
    throw new ServiceError('Hours worked cannot be negative', 'VALIDATION_ERROR');
  }

  const { data: emp } = await supabase
    .from('employees')
    .select('id')
    .eq('id', payload.employee_id)
    .single();
  if (!emp) throw new ServiceError('Employee not found', 'NOT_FOUND');

  const { data, error } = await supabase
    .from('attendance_records')
    .insert({
      employee_id: payload.employee_id,
      record_date: payload.record_date,
      status: payload.status,
      hours_worked: payload.hours_worked ?? 8,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as AttendanceRecord;
}

// ============================================================
// QUALIFICATIONS & TRAINING
// ============================================================

export async function getQualifications(employeeId?: string): Promise<Qualification[]> {
  let query = supabase.from('qualifications').select('*').order('name');
  if (employeeId) query = query.eq('employee_id', employeeId);
  const { data, error } = await query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function addQualification(payload: {
  employee_id: string;
  name: string;
  issued_date?: string | null;
  expiry_date?: string | null;
  issuer?: string | null;
}): Promise<Qualification> {
  if (!payload.employee_id) throw new ServiceError('Employee ID is required', 'VALIDATION_ERROR');
  if (!payload.name?.trim()) throw new ServiceError('Qualification name is required', 'VALIDATION_ERROR');

  if (payload.expiry_date && payload.issued_date && payload.expiry_date < payload.issued_date) {
    throw new ServiceError('Expiry date cannot be before issue date', 'VALIDATION_ERROR');
  }

  const { data, error } = await supabase
    .from('qualifications')
    .insert({ ...payload, is_demo: false })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as Qualification;
}

export async function getTrainingRecords(employeeId?: string): Promise<TrainingRecord[]> {
  let query = supabase.from('training_records').select('*').order('created_at', { ascending: false });
  if (employeeId) query = query.eq('employee_id', employeeId);
  const { data, error } = await query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function addTrainingRecord(payload: {
  employee_id: string;
  course_name: string;
  completion_date?: string | null;
  status?: TrainingStatus;
}): Promise<TrainingRecord> {
  if (!payload.employee_id) throw new ServiceError('Employee ID is required', 'VALIDATION_ERROR');
  if (!payload.course_name?.trim()) throw new ServiceError('Course name is required', 'VALIDATION_ERROR');

  const { data, error } = await supabase
    .from('training_records')
    .insert({
      employee_id: payload.employee_id,
      course_name: payload.course_name.trim(),
      completion_date: payload.completion_date ?? null,
      status: payload.status ?? 'scheduled',
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as TrainingRecord;
}

export async function updateTrainingStatus(
  id: string,
  status: TrainingStatus,
  completionDate?: string | null,
): Promise<void> {
  if (!id) throw new ServiceError('Training record ID is required', 'VALIDATION_ERROR');
  const updates: Record<string, unknown> = { status };
  if (status === 'completed' && completionDate) updates.completion_date = completionDate;
  const { error } = await supabase.from('training_records').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}
