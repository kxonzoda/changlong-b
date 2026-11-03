/*
# Extended Industrial Tables, Analytics Functions, and Audit Triggers

1. New Tables
- `equipment_components` — sub-components of equipment (for hierarchical asset tracking)
- `maintenance_procedures` — documented step-by-step maintenance procedures
- `maintenance_parts` — spare parts required per work order
- `risk_assessments` — safety risk assessments with risk matrix scoring
- `safety_training_records` — safety-specific training completions
- `water_usage_records` — water consumption tracking (separate from energy)
- `system_events` — system-level event log (startup, config change, alert)
- `energy_anomalies` — detected energy anomalies (persisted, not just computed)

2. New Functions
- `get_equipment_mtbf(p_equipment_id, p_days)` — Mean Time Between Failures in hours
- `get_equipment_mttr(p_equipment_id, p_days)` — Mean Time To Repair in hours
- `log_audit_event(p_user_id, p_action, p_entity_type, p_entity_id, p_details)` — SECURITY DEFINER audit insert

3. New Triggers
- Audit triggers on safety_incidents, maintenance_work_orders, warehouse_items for UPDATE/DELETE

4. Security
- RLS enabled on all 8 new tables.
- Grants scoped to authenticated (read) + service_role (write via edge functions).
- log_audit_event: SECURITY DEFINER, search_path locked, EXECUTE granted to authenticated.
- Risk-restricted tables (risk_assessments, safety_training_records) limited to admin/manager/safety_officer.

5. Notes
- MTBF = total_operating_hours / number_of_failures. A "failure" = work order of type 'corrective' with status 'completed'.
- MTTR = average downtime_hours across completed corrective work orders.
- If no failures exist, MTBF returns NULL (not zero) to avoid division-by-zero and misrepresentation.
- Audit trigger captures old_values via to_jsonb(OLD) and action via TG_OP.
*/

-- =========================================================
-- 1. equipment_components
-- =========================================================
CREATE TABLE IF NOT EXISTS equipment_components (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  name text NOT NULL,
  component_code text,
  serial_number text,
  installed_date date,
  status text NOT NULL DEFAULT 'operational',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE equipment_components ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_components TO authenticated;
GRANT ALL ON equipment_components TO service_role;

CREATE INDEX IF NOT EXISTS idx_equipment_components_equipment_id ON equipment_components(equipment_id);

CREATE TRIGGER set_updated_at_equipment_components
  BEFORE UPDATE ON equipment_components
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =========================================================
-- 2. maintenance_procedures
-- =========================================================
CREATE TABLE IF NOT EXISTS maintenance_procedures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  equipment_category_id uuid REFERENCES equipment_categories(id) ON DELETE SET NULL,
  type maintenance_type NOT NULL DEFAULT 'preventive',
  description text,
  estimated_duration_hours numeric DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE maintenance_procedures ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON maintenance_procedures TO authenticated;
GRANT ALL ON maintenance_procedures TO service_role;

CREATE TRIGGER set_updated_at_maintenance_procedures
  BEFORE UPDATE ON maintenance_procedures
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =========================================================
-- 3. maintenance_parts
-- =========================================================
CREATE TABLE IF NOT EXISTS maintenance_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id uuid NOT NULL REFERENCES maintenance_work_orders(id) ON DELETE CASCADE,
  warehouse_item_id uuid REFERENCES warehouse_items(id) ON DELETE SET NULL,
  part_name text NOT NULL,
  quantity numeric NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_cost numeric DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE maintenance_parts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON maintenance_parts TO authenticated;
GRANT ALL ON maintenance_parts TO service_role;

CREATE INDEX IF NOT EXISTS idx_maintenance_parts_work_order_id ON maintenance_parts(work_order_id);

-- =========================================================
-- 4. risk_assessments
-- =========================================================
CREATE TABLE IF NOT EXISTS risk_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  area text NOT NULL,
  hazard_description text NOT NULL,
  likelihood text NOT NULL CHECK (likelihood IN ('low', 'medium', 'high')),
  severity text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  risk_score integer NOT NULL DEFAULT 0 CHECK (risk_score >= 0 AND risk_score <= 100),
  mitigation_plan text,
  assessor_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  assessment_date date NOT NULL DEFAULT CURRENT_DATE,
  next_review_date date,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE risk_assessments ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON risk_assessments TO authenticated;
GRANT ALL ON risk_assessments TO service_role;

DROP POLICY IF EXISTS "read_risk_assessments_admin_manager_safety" ON risk_assessments;
CREATE POLICY "read_risk_assessments_admin_manager_safety"
  ON risk_assessments FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer')
  ));

CREATE INDEX IF NOT EXISTS idx_risk_assessments_assessment_date ON risk_assessments(assessment_date);

CREATE TRIGGER set_updated_at_risk_assessments
  BEFORE UPDATE ON risk_assessments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =========================================================
-- 5. safety_training_records
-- =========================================================
CREATE TABLE IF NOT EXISTS safety_training_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  course_name text NOT NULL,
  trainer text,
  training_date date NOT NULL DEFAULT CURRENT_DATE,
  completion_status text NOT NULL DEFAULT 'completed' CHECK (completion_status IN ('scheduled', 'in_progress', 'completed', 'failed')),
  expiry_date date,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE safety_training_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON safety_training_records TO authenticated;
GRANT ALL ON safety_training_records TO service_role;

DROP POLICY IF EXISTS "read_safety_training_admin_manager_safety" ON safety_training_records;
CREATE POLICY "read_safety_training_admin_manager_safety"
  ON safety_training_records FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer')
  ));

CREATE INDEX IF NOT EXISTS idx_safety_training_employee_id ON safety_training_records(employee_id);

-- =========================================================
-- 6. water_usage_records
-- =========================================================
CREATE TABLE IF NOT EXISTS water_usage_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  usage_date date NOT NULL DEFAULT CURRENT_DATE,
  source text,
  intake_volume numeric NOT NULL DEFAULT 0,
  discharge_volume numeric NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'm3',
  recycling_rate numeric DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE water_usage_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON water_usage_records TO authenticated;
GRANT ALL ON water_usage_records TO service_role;

CREATE INDEX IF NOT EXISTS idx_water_usage_date ON water_usage_records(usage_date);
CREATE INDEX IF NOT EXISTS idx_water_usage_dept ON water_usage_records(department_id);

-- =========================================================
-- 7. system_events
-- =========================================================
CREATE TABLE IF NOT EXISTS system_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  severity notification_severity NOT NULL DEFAULT 'info',
  message text NOT NULL,
  source text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE system_events ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON system_events TO authenticated;
GRANT ALL ON system_events TO service_role;

DROP POLICY IF EXISTS "read_system_events_admin_director" ON system_events;
CREATE POLICY "read_system_events_admin_director"
  ON system_events FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('admin', 'plant_director')
  ));

CREATE INDEX IF NOT EXISTS idx_system_events_created_at ON system_events(created_at DESC);

-- =========================================================
-- 8. energy_anomalies
-- =========================================================
CREATE TABLE IF NOT EXISTS energy_anomalies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id uuid REFERENCES energy_meters(id) ON DELETE SET NULL,
  anomaly_date date NOT NULL DEFAULT CURRENT_DATE,
  detected_value numeric NOT NULL,
  expected_value numeric,
  deviation_pct numeric,
  anomaly_type text NOT NULL DEFAULT 'peak' CHECK (anomaly_type IN ('peak', 'dip', 'usage_spike', 'meter_fault')),
  description text,
  is_resolved boolean NOT NULL DEFAULT false,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE energy_anomalies ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_anomalies TO authenticated;
GRANT ALL ON energy_anomalies TO service_role;

CREATE INDEX IF NOT EXISTS idx_energy_anomalies_date ON energy_anomalies(anomaly_date);
CREATE INDEX IF NOT EXISTS idx_energy_anomalies_meter ON energy_anomalies(meter_id);

-- =========================================================
-- 9. MTBF function
-- =========================================================
CREATE OR REPLACE FUNCTION get_equipment_mtbf(
  p_equipment_id uuid DEFAULT NULL,
  p_days integer DEFAULT 30
) RETURNS TABLE (
  equipment_id uuid,
  equipment_code text,
  equipment_name text,
  failure_count integer,
  total_operating_hours numeric,
  mtbf_hours numeric
) LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.equipment_code,
    e.name,
    COALESCE(fc.failure_count, 0)::integer,
    e.operating_hours,
    CASE
      WHEN COALESCE(fc.failure_count, 0) = 0 THEN NULL
      ELSE e.operating_hours / fc.failure_count
    END
  FROM equipment e
  LEFT JOIN (
    SELECT equipment_id, count(*) AS failure_count
    FROM maintenance_work_orders
    WHERE type = 'corrective'
      AND status = 'completed'
      AND completed_date >= (CURRENT_DATE - p_days)
    GROUP BY equipment_id
  ) fc ON fc.equipment_id = e.id
  WHERE p_equipment_id IS NULL OR e.id = p_equipment_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_equipment_mtbf(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_equipment_mtbf(uuid, integer) TO authenticated;

-- =========================================================
-- 10. MTTR function
-- =========================================================
CREATE OR REPLACE FUNCTION get_equipment_mttr(
  p_equipment_id uuid DEFAULT NULL,
  p_days integer DEFAULT 30
) RETURNS TABLE (
  equipment_id uuid,
  equipment_code text,
  equipment_name text,
  repair_count integer,
  total_downtime_hours numeric,
  mttr_hours numeric
) LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.equipment_code,
    e.name,
    COALESCE(rc.repair_count, 0)::integer,
    COALESCE(rc.total_downtime, 0),
    CASE
      WHEN COALESCE(rc.repair_count, 0) = 0 THEN NULL
      ELSE rc.total_downtime / rc.repair_count
    END
  FROM equipment e
  LEFT JOIN (
    SELECT
      equipment_id,
      count(*) AS repair_count,
      COALESCE(SUM(downtime_hours), 0) AS total_downtime
    FROM maintenance_work_orders
    WHERE type = 'corrective'
      AND status = 'completed'
      AND completed_date >= (CURRENT_DATE - p_days)
    GROUP BY equipment_id
  ) rc ON rc.equipment_id = e.id
  WHERE p_equipment_id IS NULL OR e.id = p_equipment_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_equipment_mttr(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_equipment_mttr(uuid, integer) TO authenticated;

-- =========================================================
-- 11. log_audit_event function
-- =========================================================
CREATE OR REPLACE FUNCTION log_audit_event(
  p_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid DEFAULT NULL,
  p_details jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
  VALUES (p_user_id, p_action, p_entity_type, p_entity_id, p_details)
  RETURNING id INTO v_log_id;
  RETURN v_log_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_audit_event(uuid, text, text, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_audit_event(uuid, text, text, uuid, jsonb) TO authenticated, service_role;

-- =========================================================
-- 12. Audit trigger function (generic)
-- =========================================================
CREATE OR REPLACE FUNCTION audit_trigger_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM log_audit_event(
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(OLD.id, NEW.id),
    CASE
      WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)
      WHEN TG_OP = 'UPDATE' THEN jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW))
      ELSE NULL
    END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE EXECUTE ON FUNCTION audit_trigger_fn() FROM PUBLIC, anon;

-- Audit triggers on critical tables
DROP TRIGGER IF EXISTS audit_safety_incidents ON safety_incidents;
CREATE TRIGGER audit_safety_incidents
  AFTER UPDATE OR DELETE ON safety_incidents
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();

DROP TRIGGER IF EXISTS audit_maintenance_work_orders ON maintenance_work_orders;
CREATE TRIGGER audit_maintenance_work_orders
  AFTER UPDATE OR DELETE ON maintenance_work_orders
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();

DROP TRIGGER IF EXISTS audit_warehouse_items ON warehouse_items;
CREATE TRIGGER audit_warehouse_items
  AFTER UPDATE OR DELETE ON warehouse_items
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();
