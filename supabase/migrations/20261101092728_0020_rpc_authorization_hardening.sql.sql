/*
# Phase 2 Security Hardening — Add internal role checks to SECURITY DEFINER RPCs

The security advisor flags that any authenticated user can call these functions
via the REST API. Since SECURITY DEFINER bypasses RLS, each function must
verify the caller's role internally, matching the pattern in admin_update_profile.
*/

-- ============================================================
-- update_equipment_status: admin, plant_director, manager, maintenance_manager, engineer
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_equipment_status(
  p_equipment_id uuid,
  p_new_status equipment_status,
  p_health_score integer DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_role user_role;
  v_old_status equipment_status;
  v_event_id uuid;
  v_history_id uuid;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director', 'manager', 'maintenance_manager', 'engineer') THEN
    RAISE EXCEPTION 'Permission denied: equipment management role required';
  END IF;

  IF p_health_score IS NOT NULL AND (p_health_score < 0 OR p_health_score > 100) THEN
    RAISE EXCEPTION 'Health score must be between 0 and 100';
  END IF;

  SELECT status INTO v_old_status FROM equipment WHERE id = p_equipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Equipment % not found', p_equipment_id;
  END IF;

  IF v_old_status = p_new_status THEN
    RAISE EXCEPTION 'Equipment is already in % status', p_new_status;
  END IF;

  UPDATE equipment
    SET status = p_new_status,
        health_score = COALESCE(p_health_score, health_score),
        updated_at = now()
    WHERE id = p_equipment_id;

  INSERT INTO equipment_events (equipment_id, event_type, event_time, description, old_status, new_status, is_demo)
  VALUES (p_equipment_id, 'status_change', now(),
    COALESCE(p_reason, 'Status changed from ' || v_old_status || ' to ' || p_new_status),
    v_old_status, p_new_status, false)
  RETURNING id INTO v_event_id;

  INSERT INTO equipment_status_history (equipment_id, status, changed_at, reason, is_demo)
  VALUES (p_equipment_id, p_new_status, now(), p_reason, false)
  RETURNING id INTO v_history_id;

  RETURN v_event_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_equipment_status(uuid, equipment_status, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_equipment_status(uuid, equipment_status, integer, text) TO authenticated;

-- ============================================================
-- transition_safety_incident: admin, plant_director, manager, safety_officer
-- ============================================================
CREATE OR REPLACE FUNCTION public.transition_safety_incident(
  p_incident_id uuid,
  p_new_status incident_status,
  p_resolution_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_role user_role;
  v_old_status incident_status;
  v_reported_by uuid;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director', 'manager', 'safety_officer') THEN
    RAISE EXCEPTION 'Permission denied: safety management role required';
  END IF;

  SELECT status, reported_by INTO v_old_status, v_reported_by
  FROM safety_incidents WHERE id = p_incident_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Safety incident % not found', p_incident_id;
  END IF;

  -- Validate forward transitions: reported -> investigating -> resolved -> closed
  IF p_new_status = 'investigating' AND v_old_status NOT IN ('reported', 'investigating') THEN
    RAISE EXCEPTION 'Cannot transition from % to investigating', v_old_status;
  ELSIF p_new_status = 'resolved' AND v_old_status NOT IN ('investigating', 'reported') THEN
    RAISE EXCEPTION 'Cannot transition from % to resolved', v_old_status;
  ELSIF p_new_status = 'closed' AND v_old_status NOT IN ('resolved', 'investigating', 'reported') THEN
    RAISE EXCEPTION 'Cannot transition from % to closed', v_old_status;
  ELSIF p_new_status = v_old_status THEN
    RAISE EXCEPTION 'Incident is already in % status', p_new_status;
  END IF;

  UPDATE safety_incidents
    SET status = p_new_status,
        resolution_notes = CASE WHEN p_new_status IN ('resolved', 'closed') THEN p_resolution_notes ELSE resolution_notes END,
        resolution_date = CASE WHEN p_new_status IN ('resolved', 'closed') THEN now() ELSE resolution_date END,
        updated_at = now()
    WHERE id = p_incident_id;

  RETURN p_incident_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.transition_safety_incident(uuid, incident_status, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transition_safety_incident(uuid, incident_status, text) TO authenticated;

-- ============================================================
-- resolve_environmental_alert: admin, plant_director, manager
-- ============================================================
CREATE OR REPLACE FUNCTION public.resolve_environmental_alert(
  p_alert_id uuid,
  p_resolution_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_role user_role;
  v_resolved_at timestamptz;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director', 'manager') THEN
    RAISE EXCEPTION 'Permission denied: management role required';
  END IF;

  SELECT resolved_at INTO v_resolved_at FROM environmental_alerts WHERE id = p_alert_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Environmental alert % not found', p_alert_id;
  END IF;
  IF v_resolved_at IS NOT NULL THEN
    RAISE EXCEPTION 'Alert % is already resolved', p_alert_id;
  END IF;

  UPDATE environmental_alerts
    SET resolved_at = now(),
        resolution_notes = p_resolution_notes
    WHERE id = p_alert_id;

  RETURN p_alert_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_environmental_alert(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_environmental_alert(uuid, text) TO authenticated;

-- ============================================================
-- assign_employee_shift: admin, plant_director, manager
-- ============================================================
CREATE OR REPLACE FUNCTION public.assign_employee_shift(
  p_employee_id uuid,
  p_shift_id uuid,
  p_effective_date date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_role user_role;
  v_new_id uuid;
  v_emp_exists boolean;
  v_shift_exists boolean;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director', 'manager') THEN
    RAISE EXCEPTION 'Permission denied: management role required';
  END IF;

  SELECT EXISTS(SELECT 1 FROM employees WHERE id = p_employee_id) INTO v_emp_exists;
  IF NOT v_emp_exists THEN
    RAISE EXCEPTION 'Employee % not found', p_employee_id;
  END IF;

  SELECT EXISTS(SELECT 1 FROM shifts WHERE id = p_shift_id AND is_active = true) INTO v_shift_exists;
  IF NOT v_shift_exists THEN
    RAISE EXCEPTION 'Shift % not found or inactive', p_shift_id;
  END IF;

  -- End any currently active shift assignment
  UPDATE employee_shifts
    SET end_date = p_effective_date - 1,
        is_active = false
    WHERE employee_id = p_employee_id
      AND is_active = true
      AND end_date IS NULL;

  -- Insert new shift assignment
  INSERT INTO employee_shifts (employee_id, shift_id, effective_date, is_active, is_demo)
  VALUES (p_employee_id, p_shift_id, p_effective_date, true, false)
  RETURNING id INTO v_new_id;

  -- Update employee's shift_id for quick reference
  UPDATE employees SET shift_id = p_shift_id, updated_at = now()
    WHERE id = p_employee_id;

  RETURN v_new_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.assign_employee_shift(uuid, uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_employee_shift(uuid, uuid, date) TO authenticated;