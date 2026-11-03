/*
# Phase 2 — Business Logic & Security

1. Schema: add resolution_notes to safety_incidents
2. RLS write policies: role-restricted INSERT/UPDATE/DELETE for tables that need direct browser writes
3. SECURITY DEFINER RPCs for atomic multi-step operations:
   - update_equipment_status (equipment + event + status_history)
   - transition_safety_incident (validate transition + update + resolution_date)
   - resolve_environmental_alert (set resolved_at + resolution_notes)
   - assign_employee_shift (end previous shift + insert new + update employee)
4. Service-role policies for workforce_assignments and employee_shifts (missing)
*/

-- ============================================================
-- 1. SCHEMA FIX: resolution_notes on safety_incidents
-- ============================================================
ALTER TABLE safety_incidents ADD COLUMN IF NOT EXISTS resolution_notes text;

-- ============================================================
-- 2. RLS WRITE POLICIES (role-restricted)
-- ============================================================

-- Helper: role check for management roles
-- We inline the role checks in each policy for clarity.

-- warehouse_items: warehouse_manager, admin, plant_director can manage
DROP POLICY IF EXISTS "witem_insert_mgmt" ON warehouse_items;
CREATE POLICY "witem_insert_mgmt" ON warehouse_items FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'warehouse_manager'))
  );
DROP POLICY IF EXISTS "witem_update_mgmt" ON warehouse_items;
CREATE POLICY "witem_update_mgmt" ON warehouse_items FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'warehouse_manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'warehouse_manager'))
  );

-- employees: admin, plant_director, manager can manage
DROP POLICY IF EXISTS "emp_insert_mgmt" ON employees;
CREATE POLICY "emp_insert_mgmt" ON employees FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "emp_update_mgmt" ON employees;
CREATE POLICY "emp_update_mgmt" ON employees FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- departments: admin, plant_director can manage
DROP POLICY IF EXISTS "dept_insert_admin" ON departments;
CREATE POLICY "dept_insert_admin" ON departments FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  );
DROP POLICY IF EXISTS "dept_update_admin" ON departments;
CREATE POLICY "dept_update_admin" ON departments FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  );

-- shifts: admin, plant_director, manager can manage
DROP POLICY IF EXISTS "shift_insert_mgmt" ON shifts;
CREATE POLICY "shift_insert_mgmt" ON shifts FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "shift_update_mgmt" ON shifts;
CREATE POLICY "shift_update_mgmt" ON shifts FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- safety_incidents: safety_officer, admin, plant_director, manager
DROP POLICY IF EXISTS "safety_insert_priv" ON safety_incidents;
CREATE POLICY "safety_insert_priv" ON safety_incidents FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );
DROP POLICY IF EXISTS "safety_update_priv" ON safety_incidents;
CREATE POLICY "safety_update_priv" ON safety_incidents FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );

-- corrective_actions: safety_officer, admin, plant_director, manager
DROP POLICY IF EXISTS "ca_insert_priv" ON corrective_actions;
CREATE POLICY "ca_insert_priv" ON corrective_actions FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );
DROP POLICY IF EXISTS "ca_update_priv" ON corrective_actions;
CREATE POLICY "ca_update_priv" ON corrective_actions FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );

-- safety_inspections: safety_officer, admin, plant_director, manager
DROP POLICY IF EXISTS "sinsp_insert_priv" ON safety_inspections;
CREATE POLICY "sinsp_insert_priv" ON safety_inspections FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );
DROP POLICY IF EXISTS "sinsp_update_priv" ON safety_inspections;
CREATE POLICY "sinsp_update_priv" ON safety_inspections FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );

-- environmental_readings: admin, plant_director, manager can insert
DROP POLICY IF EXISTS "env_read_insert_mgmt" ON environmental_readings;
CREATE POLICY "env_read_insert_mgmt" ON environmental_readings FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- environmental_alerts: admin, plant_director, manager can update (resolve)
DROP POLICY IF EXISTS "envalert_update_mgmt" ON environmental_alerts;
CREATE POLICY "envalert_update_mgmt" ON environmental_alerts FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- attendance_records: admin, plant_director, manager
DROP POLICY IF EXISTS "att_insert_mgmt" ON attendance_records;
CREATE POLICY "att_insert_mgmt" ON attendance_records FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "att_update_mgmt" ON attendance_records;
CREATE POLICY "att_update_mgmt" ON attendance_records FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- qualifications: admin, plant_director, manager
DROP POLICY IF EXISTS "qual_insert_mgmt" ON qualifications;
CREATE POLICY "qual_insert_mgmt" ON qualifications FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "qual_update_mgmt" ON qualifications;
CREATE POLICY "qual_update_mgmt" ON qualifications FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- training_records: admin, plant_director, manager
DROP POLICY IF EXISTS "train_insert_mgmt" ON training_records;
CREATE POLICY "train_insert_mgmt" ON training_records FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "train_update_mgmt" ON training_records;
CREATE POLICY "train_update_mgmt" ON training_records FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- workforce_assignments: admin, plant_director, manager + service_role (was missing)
DROP POLICY IF EXISTS "wa_insert_mgmt" ON workforce_assignments;
CREATE POLICY "wa_insert_mgmt" ON workforce_assignments FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "wa_update_mgmt" ON workforce_assignments;
CREATE POLICY "wa_update_mgmt" ON workforce_assignments FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "wa_service" ON workforce_assignments;
CREATE POLICY "wa_service" ON workforce_assignments FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- employee_shifts: admin, plant_director, manager + service_role (was missing)
DROP POLICY IF EXISTS "es_insert_mgmt" ON employee_shifts;
CREATE POLICY "es_insert_mgmt" ON employee_shifts FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "es_update_mgmt" ON employee_shifts;
CREATE POLICY "es_update_mgmt" ON employee_shifts FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "es_service" ON employee_shifts;
CREATE POLICY "es_service" ON employee_shifts FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- equipment: admin, plant_director, manager, maintenance_manager can manage
DROP POLICY IF EXISTS "equip_insert_mgmt" ON equipment;
CREATE POLICY "equip_insert_mgmt" ON equipment FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager'))
  );
DROP POLICY IF EXISTS "equip_update_mgmt" ON equipment;
CREATE POLICY "equip_update_mgmt" ON equipment FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager', 'engineer'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager'))
  );

-- equipment_events: insert for management/engineer roles (for direct event logging)
DROP POLICY IF EXISTS "eqevt_insert_mgmt" ON equipment_events;
CREATE POLICY "eqevt_insert_mgmt" ON equipment_events FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager', 'engineer'))
  );

-- equipment_status_history: insert for management/engineer roles
DROP POLICY IF EXISTS "ehist_insert_mgmt" ON equipment_status_history;
CREATE POLICY "ehist_insert_mgmt" ON equipment_status_history FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager', 'engineer'))
  );

-- production_lines: admin, plant_director can manage
DROP POLICY IF EXISTS "plines_insert_admin" ON production_lines;
CREATE POLICY "plines_insert_admin" ON production_lines FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  );
DROP POLICY IF EXISTS "plines_update_admin" ON production_lines;
CREATE POLICY "plines_update_admin" ON production_lines FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director'))
  );

-- ============================================================
-- 3. SECURITY DEFINER RPCs for atomic multi-step operations
-- ============================================================

-- update_equipment_status: atomically update equipment, insert event, insert status history
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
  v_old_status equipment_status;
  v_event_id uuid;
  v_history_id uuid;
BEGIN
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

-- transition_safety_incident: validate status transition + update + resolution
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
  v_old_status incident_status;
  v_reported_by uuid;
BEGIN
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

-- resolve_environmental_alert: set resolved_at + resolution_notes
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
  v_resolved_at timestamptz;
BEGIN
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

-- assign_employee_shift: end previous active shift + insert new + update employee
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
  v_new_id uuid;
  v_old_id uuid;
  v_emp_exists boolean;
  v_shift_exists boolean;
BEGIN
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