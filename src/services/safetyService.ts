import { supabase } from '@/lib/supabase';
import type {
  SafetyIncident,
  RiskAssessment,
  SafetyTrainingRecord,
  CorrectiveAction,
  CorrectiveActionStatus,
  SafetyInspection,
  IncidentSeverity,
  IncidentStatus,
} from '@/types/database';
import { ServiceError } from './serviceError';

// ============================================================
// READ OPERATIONS
// ============================================================

export async function getSafetyIncidents(limit = 50): Promise<SafetyIncident[]> {
  const { data, error } = await supabase
    .from('safety_incidents')
    .select('*')
    .order('incident_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as SafetyIncident[];
}

export async function getOpenIncidentCount(): Promise<number> {
  const { data, error } = await supabase
    .from('safety_incidents')
    .select('id')
    .in('status', ['reported', 'investigating']);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data?.length ?? 0;
}

export async function getSafetyInspections(limit = 50): Promise<SafetyInspection[]> {
  const { data, error } = await supabase
    .from('safety_inspections')
    .select('*')
    .order('inspection_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getRiskAssessments(limit = 50): Promise<RiskAssessment[]> {
  const { data, error } = await supabase
    .from('risk_assessments')
    .select('*')
    .order('assessment_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getSafetyTrainingRecords(limit = 50): Promise<SafetyTrainingRecord[]> {
  const { data, error } = await supabase
    .from('safety_training_records')
    .select('*')
    .order('training_date', { ascending: false })
    .limit(limit);
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

export async function getCorrectiveActions(incidentId?: string): Promise<CorrectiveAction[]> {
  let query = supabase.from('corrective_actions').select('*').order('created_at', { ascending: false });
  if (incidentId) query = query.eq('incident_id', incidentId);
  const { data, error } = await query;
  if (error) throw ServiceError.fromSupabaseError(error);
  return data ?? [];
}

// ============================================================
// INCIDENT LIFECYCLE
// ============================================================

const VALID_SEVERITIES: IncidentSeverity[] = ['minor', 'moderate', 'serious', 'critical'];

export async function createSafetyIncident(payload: {
  title: string;
  description?: string | null;
  severity: IncidentSeverity;
  department_id?: string | null;
  incident_date: string;
}): Promise<SafetyIncident> {
  if (!payload.title?.trim()) throw new ServiceError('Incident title is required', 'VALIDATION_ERROR');
  if (!VALID_SEVERITIES.includes(payload.severity)) {
    throw new ServiceError('Invalid severity level', 'VALIDATION_ERROR');
  }
  if (!payload.incident_date) throw new ServiceError('Incident date is required', 'VALIDATION_ERROR');

  const { data: userData } = await supabase.auth.getUser();

  const { data, error } = await supabase
    .from('safety_incidents')
    .insert({
      title: payload.title.trim(),
      description: payload.description ?? null,
      severity: payload.severity,
      department_id: payload.department_id ?? null,
      incident_date: payload.incident_date,
      status: 'reported',
      reported_by: userData.user?.id ?? null,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as SafetyIncident;
}

/**
 * Transition an incident through its lifecycle via the atomic SECURITY DEFINER RPC.
 * Enforces: reported -> investigating -> resolved -> closed
 */
export async function transitionIncidentStatus(
  id: string,
  newStatus: IncidentStatus,
  resolutionNotes?: string | null,
): Promise<void> {
  if (!id) throw new ServiceError('Incident ID is required', 'VALIDATION_ERROR');
  if (!['reported', 'investigating', 'resolved', 'closed'].includes(newStatus)) {
    throw new ServiceError('Invalid status', 'VALIDATION_ERROR');
  }

  const { error } = await supabase.rpc('transition_safety_incident', {
    p_incident_id: id,
    p_new_status: newStatus,
    p_resolution_notes: resolutionNotes ?? null,
  });
  if (error) throw ServiceError.fromSupabaseError(error);
}

/**
 * Start investigation on an incident. Validates it's in 'reported' state.
 */
export async function startInvestigation(id: string): Promise<void> {
  await transitionIncidentStatus(id, 'investigating');
}

/**
 * Update investigation notes without changing status.
 * Preserves reporter identity — cannot modify reported_by.
 */
export async function updateInvestigationNotes(
  id: string,
  description?: string | null,
  resolutionNotes?: string | null,
): Promise<void> {
  if (!id) throw new ServiceError('Incident ID is required', 'VALIDATION_ERROR');
  const updates: Record<string, unknown> = {};
  if (description !== undefined) updates.description = description;
  if (resolutionNotes !== undefined) updates.resolution_notes = resolutionNotes;
  if (Object.keys(updates).length === 0) return;

  const { error } = await supabase.from('safety_incidents').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}

// ============================================================
// SAFETY INSPECTIONS
// ============================================================

export async function createSafetyInspection(payload: {
  inspection_number: string;
  department_id?: string | null;
  inspection_date: string;
  result?: 'pass' | 'fail' | 'conditional';
  findings?: string | null;
}): Promise<SafetyInspection> {
  if (!payload.inspection_number?.trim()) throw new ServiceError('Inspection number is required', 'VALIDATION_ERROR');
  if (!payload.inspection_date) throw new ServiceError('Inspection date is required', 'VALIDATION_ERROR');

  const { data: userData } = await supabase.auth.getUser();

  const { data, error } = await supabase
    .from('safety_inspections')
    .insert({
      inspection_number: payload.inspection_number.trim(),
      department_id: payload.department_id ?? null,
      inspection_date: payload.inspection_date,
      result: payload.result ?? 'pass',
      findings: payload.findings ?? null,
      inspector_id: userData.user?.id ?? null,
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as SafetyInspection;
}

// ============================================================
// CORRECTIVE ACTIONS
// ============================================================

export async function createCorrectiveAction(payload: {
  incident_id: string;
  description: string;
  assigned_to?: string | null;
  due_date?: string | null;
}): Promise<CorrectiveAction> {
  if (!payload.incident_id) throw new ServiceError('Incident ID is required', 'VALIDATION_ERROR');
  if (!payload.description?.trim()) throw new ServiceError('Description is required', 'VALIDATION_ERROR');

  const { data: incident } = await supabase
    .from('safety_incidents')
    .select('id')
    .eq('id', payload.incident_id)
    .single();
  if (!incident) throw new ServiceError('Safety incident not found', 'NOT_FOUND');

  const { data, error } = await supabase
    .from('corrective_actions')
    .insert({
      incident_id: payload.incident_id,
      description: payload.description.trim(),
      assigned_to: payload.assigned_to ?? null,
      due_date: payload.due_date ?? null,
      status: 'open',
      is_demo: false,
    })
    .select('*')
    .single();
  if (error) throw ServiceError.fromSupabaseError(error);
  return data as CorrectiveAction;
}

export async function updateCorrectiveAction(
  id: string,
  updates: { status?: CorrectiveActionStatus },
): Promise<void> {
  if (!id) throw new ServiceError('Corrective action ID is required', 'VALIDATION_ERROR');
  const { error } = await supabase.from('corrective_actions').update(updates).eq('id', id);
  if (error) throw ServiceError.fromSupabaseError(error);
}
