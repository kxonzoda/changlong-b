/*
# Supplementary Tables for Existing Domains

## Purpose
Adds tables that were referenced in the spec but not yet implemented:
production_events, equipment_status_history, safety_inspections, safety_observations,
corrective_actions, energy_targets, energy_cost_records, suppliers, purchase_requests,
warehouse_locations, raw_material_consumption, notification_preferences.

## New Tables

### production_events
- `id`, `production_line_id` (FK), `event_type` (text), `event_time` (timestamptz),
  `description`, `is_demo`, `created_at`

### equipment_status_history
- `id`, `equipment_id` (FK), `status` (equipment_status), `changed_at` (timestamptz),
  `reason` (text), `is_demo`, `created_at`

### safety_inspections
- `id`, `inspection_number` (unique), `department_id` (FK), `inspector_id` (FK profiles),
  `inspection_date` (timestamptz), `result` (enum: pass/fail/conditional), `findings` (text),
  `is_demo`, timestamps

### safety_observations
- `id`, `department_id` (FK), `observer_id` (FK profiles), `observation_date` (timestamptz),
  `description`, `category` (text), `is_demo`, `created_at`

### corrective_actions
- `id`, `incident_id` (FK safety_incidents), `description`, `assigned_to` (FK profiles),
  `due_date` (date), `status` (enum: open/in_progress/completed/verified), `is_demo`, timestamps

### energy_targets
- `id`, `meter_id` (FK energy_meters), `target_date` (date), `target_value` (numeric),
  `unit`, `is_demo`, timestamps

### energy_cost_records
- `id`, `meter_id` (FK), `cost_date` (date), `unit_cost` (numeric), `total_cost` (numeric),
  `currency` (text default 'CNY'), `is_demo`, `created_at`

### suppliers
- `id`, `name`, `code` (unique), `contact_name`, `contact_phone`, `contact_email`,
  `address`, `is_active`, `is_demo`, timestamps

### purchase_requests
- `id`, `request_number` (unique), `item_id` (FK warehouse_items), `supplier_id` (FK suppliers),
  `quantity` (numeric), `unit`, `status` (enum: pending/approved/ordered/received/cancelled),
  `requested_by` (FK profiles), `is_demo`, timestamps

### warehouse_locations
- `id`, `name`, `code` (unique), `description`, `is_active`, `created_at`, `updated_at`

### raw_material_consumption
- `id`, `batch_id` (FK production_batches), `material_name`, `quantity`, `unit`,
  `is_demo`, `created_at`

### notification_preferences
- `id`, `user_id` (FK profiles), `category` (text), `severity` (notification_severity),
  `enabled` (bool), `created_at`

## Security
- RLS on all tables. Authenticated read; service_role write.
- Safety observations/inspections restricted to admins/managers/safety_officer like incidents.
- Corrective actions restricted similarly.
- Notification preferences owner-scoped.
*/

DO $$ BEGIN
  CREATE TYPE corrective_action_status AS ENUM ('open', 'in_progress', 'completed', 'verified');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE purchase_status AS ENUM ('pending', 'approved', 'ordered', 'received', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PRODUCTION EVENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS production_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_line_id uuid REFERENCES production_lines(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  event_time timestamptz NOT NULL DEFAULT now(),
  description text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE production_events ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON production_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_events TO service_role;

DROP POLICY IF EXISTS "pevt_select_auth" ON production_events;
CREATE POLICY "pevt_select_auth" ON production_events FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "pevt_service" ON production_events;
CREATE POLICY "pevt_service" ON production_events FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_pevt_line_time ON production_events(production_line_id, event_time);

-- ============================================================
-- EQUIPMENT STATUS HISTORY
-- ============================================================
CREATE TABLE IF NOT EXISTS equipment_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  status equipment_status NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment_status_history ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_status_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON equipment_status_history TO service_role;

DROP POLICY IF EXISTS "ehist_select_auth" ON equipment_status_history;
CREATE POLICY "ehist_select_auth" ON equipment_status_history FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "ehist_service" ON equipment_status_history;
CREATE POLICY "ehist_service" ON equipment_status_history FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_ehist_equip_time ON equipment_status_history(equipment_id, changed_at);

-- ============================================================
-- SAFETY INSPECTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS safety_inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_number text NOT NULL UNIQUE,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  inspector_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  inspection_date timestamptz NOT NULL DEFAULT now(),
  result quality_result NOT NULL DEFAULT 'pass',
  findings text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE safety_inspections ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON safety_inspections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON safety_inspections TO service_role;

DROP POLICY IF EXISTS "sinsp_select_privileged" ON safety_inspections;
CREATE POLICY "sinsp_select_privileged" ON safety_inspections FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );
DROP POLICY IF EXISTS "sinsp_service" ON safety_inspections;
CREATE POLICY "sinsp_service" ON safety_inspections FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_sinsp_date ON safety_inspections(inspection_date);

-- ============================================================
-- SAFETY OBSERVATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS safety_observations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  observer_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  observation_date timestamptz NOT NULL DEFAULT now(),
  description text NOT NULL,
  category text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE safety_observations ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON safety_observations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON safety_observations TO service_role;

DROP POLICY IF EXISTS "sobs_select_privileged" ON safety_observations;
CREATE POLICY "sobs_select_privileged" ON safety_observations FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );
DROP POLICY IF EXISTS "sobs_service" ON safety_observations;
CREATE POLICY "sobs_service" ON safety_observations FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- CORRECTIVE ACTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS corrective_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid REFERENCES safety_incidents(id) ON DELETE CASCADE,
  description text NOT NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  due_date date,
  status corrective_action_status NOT NULL DEFAULT 'open',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE corrective_actions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON corrective_actions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON corrective_actions TO service_role;

DROP POLICY IF EXISTS "ca_select_privileged" ON corrective_actions;
CREATE POLICY "ca_select_privileged" ON corrective_actions FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager', 'safety_officer'))
  );
DROP POLICY IF EXISTS "ca_service" ON corrective_actions;
CREATE POLICY "ca_service" ON corrective_actions FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_ca_incident ON corrective_actions(incident_id);

DROP TRIGGER IF EXISTS ca_set_updated_at ON corrective_actions;
CREATE TRIGGER ca_set_updated_at BEFORE UPDATE ON corrective_actions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- ENERGY TARGETS
-- ============================================================
CREATE TABLE IF NOT EXISTS energy_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id uuid REFERENCES energy_meters(id) ON DELETE CASCADE,
  target_date date NOT NULL,
  target_value numeric(14,3) NOT NULL,
  unit text NOT NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meter_id, target_date)
);

ALTER TABLE energy_targets ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_targets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON energy_targets TO service_role;

DROP POLICY IF EXISTS "etgt_select_auth" ON energy_targets;
CREATE POLICY "etgt_select_auth" ON energy_targets FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "etgt_service" ON energy_targets;
CREATE POLICY "etgt_service" ON energy_targets FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- ENERGY COST RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS energy_cost_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id uuid REFERENCES energy_meters(id) ON DELETE CASCADE,
  cost_date date NOT NULL,
  unit_cost numeric(12,4) NOT NULL,
  total_cost numeric(14,2) NOT NULL,
  currency text NOT NULL DEFAULT 'CNY',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE energy_cost_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_cost_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON energy_cost_records TO service_role;

DROP POLICY IF EXISTS "ecost_select_auth" ON energy_cost_records;
CREATE POLICY "ecost_select_auth" ON energy_cost_records FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "ecost_service" ON energy_cost_records;
CREATE POLICY "ecost_service" ON energy_cost_records FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- SUPPLIERS
-- ============================================================
CREATE TABLE IF NOT EXISTS suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  contact_name text,
  contact_phone text,
  contact_email text,
  address text,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON suppliers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON suppliers TO service_role;

DROP POLICY IF EXISTS "sup_select_auth" ON suppliers;
CREATE POLICY "sup_select_auth" ON suppliers FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "sup_service" ON suppliers;
CREATE POLICY "sup_service" ON suppliers FOR ALL
  TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS sup_set_updated_at ON suppliers;
CREATE TRIGGER sup_set_updated_at BEFORE UPDATE ON suppliers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- PURCHASE REQUESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_number text NOT NULL UNIQUE,
  item_id uuid REFERENCES warehouse_items(id) ON DELETE SET NULL,
  supplier_id uuid REFERENCES suppliers(id) ON DELETE SET NULL,
  quantity numeric(12,2) NOT NULL,
  unit text NOT NULL,
  status purchase_status NOT NULL DEFAULT 'pending',
  requested_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON purchase_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON purchase_requests TO service_role;

DROP POLICY IF EXISTS "pr_select_auth" ON purchase_requests;
CREATE POLICY "pr_select_auth" ON purchase_requests FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "pr_service" ON purchase_requests;
CREATE POLICY "pr_service" ON purchase_requests FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_pr_item ON purchase_requests(item_id);
CREATE INDEX IF NOT EXISTS idx_pr_status ON purchase_requests(status);

DROP TRIGGER IF EXISTS pr_set_updated_at ON purchase_requests;
CREATE TRIGGER pr_set_updated_at BEFORE UPDATE ON purchase_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- WAREHOUSE LOCATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS warehouse_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_locations ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON warehouse_locations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_locations TO service_role;

DROP POLICY IF EXISTS "wloc_select_auth" ON warehouse_locations;
CREATE POLICY "wloc_select_auth" ON warehouse_locations FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "wloc_service" ON warehouse_locations;
CREATE POLICY "wloc_service" ON warehouse_locations FOR ALL
  TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS wloc_set_updated_at ON warehouse_locations;
CREATE TRIGGER wloc_set_updated_at BEFORE UPDATE ON warehouse_locations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- RAW MATERIAL CONSUMPTION
-- ============================================================
CREATE TABLE IF NOT EXISTS raw_material_consumption (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid REFERENCES production_batches(id) ON DELETE SET NULL,
  material_name text NOT NULL,
  quantity numeric(12,3) NOT NULL,
  unit text NOT NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE raw_material_consumption ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON raw_material_consumption TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON raw_material_consumption TO service_role;

DROP POLICY IF EXISTS "rmc_select_auth" ON raw_material_consumption;
CREATE POLICY "rmc_select_auth" ON raw_material_consumption FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "rmc_service" ON raw_material_consumption;
CREATE POLICY "rmc_service" ON raw_material_consumption FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_rmc_batch ON raw_material_consumption(batch_id);

-- ============================================================
-- NOTIFICATION PREFERENCES
-- ============================================================
CREATE TABLE IF NOT EXISTS notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  category text NOT NULL,
  severity notification_severity NOT NULL DEFAULT 'info',
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON notification_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON notification_preferences TO service_role;

DROP POLICY IF EXISTS "npref_select_own" ON notification_preferences;
CREATE POLICY "npref_select_own" ON notification_preferences FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "npref_insert_own" ON notification_preferences;
CREATE POLICY "npref_insert_own" ON notification_preferences FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "npref_update_own" ON notification_preferences;
CREATE POLICY "npref_update_own" ON notification_preferences FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "npref_service" ON notification_preferences;
CREATE POLICY "npref_service" ON notification_preferences FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_npref_user ON notification_preferences(user_id);

-- ============================================================
-- SAFETY INSPECTION UPDATED_AT
-- ============================================================
DROP TRIGGER IF EXISTS sinsp_set_updated_at ON safety_inspections;
CREATE TRIGGER sinsp_set_updated_at BEFORE UPDATE ON safety_inspections
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
