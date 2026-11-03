/*
# Final Spec Completion Tables

1. New Tables (remaining spec entities not yet created)
- `equipment_events`, `equipment_operating_hours`, `maintenance_history`
- `quality_parameters`, `quality_batches`, `laboratory_results`
- `stock_transactions`
- `workforce_assignments`, `employee_shifts`
- `environmental_alerts`
- `energy_sources`
- `production_shifts`

2. Security
- RLS on all, SELECT to authenticated, ALL to service_role.
- workforce_assignments, employee_shifts restricted to admin/manager.
*/

-- equipment_events
CREATE TABLE IF NOT EXISTS equipment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('startup', 'shutdown', 'fault', 'maintenance_start', 'maintenance_end', 'status_change')),
  event_time timestamptz NOT NULL DEFAULT now(),
  description text,
  old_status equipment_status,
  new_status equipment_status,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE equipment_events ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_events TO authenticated;
GRANT ALL ON equipment_events TO service_role;
CREATE INDEX IF NOT EXISTS idx_equipment_events_equipment_id ON equipment_events(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_events_event_time ON equipment_events(event_time DESC);

-- equipment_operating_hours
CREATE TABLE IF NOT EXISTS equipment_operating_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  record_date date NOT NULL DEFAULT CURRENT_DATE,
  operating_hours numeric NOT NULL DEFAULT 0,
  idle_hours numeric NOT NULL DEFAULT 0,
  downtime_hours numeric NOT NULL DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE (equipment_id, record_date)
);
ALTER TABLE equipment_operating_hours ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_operating_hours TO authenticated;
GRANT ALL ON equipment_operating_hours TO service_role;
CREATE INDEX IF NOT EXISTS idx_equipment_op_hours_date ON equipment_operating_hours(record_date);

-- maintenance_history
CREATE TABLE IF NOT EXISTS maintenance_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id uuid NOT NULL REFERENCES maintenance_work_orders(id) ON DELETE CASCADE,
  equipment_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  technician text,
  completion_notes text,
  parts_used text,
  labor_hours numeric DEFAULT 0,
  completed_at timestamptz DEFAULT now(),
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE maintenance_history ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON maintenance_history TO authenticated;
GRANT ALL ON maintenance_history TO service_role;
CREATE INDEX IF NOT EXISTS idx_maintenance_history_wo ON maintenance_history(work_order_id);

-- quality_parameters
CREATE TABLE IF NOT EXISTS quality_parameters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL CHECK (category IN ('chemical', 'mechanical', 'dimensional', 'surface')),
  unit text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE quality_parameters ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON quality_parameters TO authenticated;
GRANT ALL ON quality_parameters TO service_role;
CREATE TRIGGER set_updated_at_quality_parameters
  BEFORE UPDATE ON quality_parameters
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- quality_batches
CREATE TABLE IF NOT EXISTS quality_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES production_batches(id) ON DELETE CASCADE,
  quality_status text NOT NULL DEFAULT 'pending' CHECK (quality_status IN ('pending', 'in_progress', 'passed', 'failed', 'conditional')),
  overall_grade text CHECK (overall_grade IN ('A', 'B', 'C', 'reject')),
  inspection_count integer DEFAULT 0,
  defect_count integer DEFAULT 0,
  inspector_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  completed_at timestamptz,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE quality_batches ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON quality_batches TO authenticated;
GRANT ALL ON quality_batches TO service_role;
CREATE INDEX IF NOT EXISTS idx_quality_batches_batch_id ON quality_batches(batch_id);
CREATE TRIGGER set_updated_at_quality_batches
  BEFORE UPDATE ON quality_batches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- laboratory_results
CREATE TABLE IF NOT EXISTS laboratory_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid REFERENCES production_batches(id) ON DELETE SET NULL,
  test_name text NOT NULL,
  test_method text,
  result_value numeric,
  unit text,
  specification_min numeric,
  specification_max numeric,
  pass_fail text NOT NULL DEFAULT 'pass' CHECK (pass_fail IN ('pass', 'fail', 'conditional')),
  lab_technician text,
  test_date timestamptz DEFAULT now(),
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE laboratory_results ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON laboratory_results TO authenticated;
GRANT ALL ON laboratory_results TO service_role;
CREATE INDEX IF NOT EXISTS idx_lab_results_batch ON laboratory_results(batch_id);

-- stock_transactions
CREATE TABLE IF NOT EXISTS stock_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES warehouse_items(id) ON DELETE CASCADE,
  transaction_type text NOT NULL CHECK (transaction_type IN ('receipt', 'issue', 'transfer', 'adjustment', 'return')),
  quantity numeric NOT NULL,
  unit text,
  from_location_id uuid REFERENCES warehouse_locations(id) ON DELETE SET NULL,
  to_location_id uuid REFERENCES warehouse_locations(id) ON DELETE SET NULL,
  reference_number text,
  transaction_date timestamptz DEFAULT now(),
  performed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE stock_transactions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON stock_transactions TO authenticated;
GRANT ALL ON stock_transactions TO service_role;
CREATE INDEX IF NOT EXISTS idx_stock_transactions_item ON stock_transactions(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_date ON stock_transactions(transaction_date DESC);

-- workforce_assignments
CREATE TABLE IF NOT EXISTS workforce_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  production_line_id uuid REFERENCES production_lines(id) ON DELETE SET NULL,
  role_title text,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE workforce_assignments ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON workforce_assignments TO authenticated;
GRANT ALL ON workforce_assignments TO service_role;
DROP POLICY IF EXISTS "read_workforce_assignments_restricted" ON workforce_assignments;
CREATE POLICY "read_workforce_assignments_restricted"
  ON workforce_assignments FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('admin', 'plant_director', 'manager')
  ));
CREATE INDEX IF NOT EXISTS idx_workforce_assign_emp ON workforce_assignments(employee_id);
CREATE TRIGGER set_updated_at_workforce_assignments
  BEFORE UPDATE ON workforce_assignments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- employee_shifts
CREATE TABLE IF NOT EXISTS employee_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  shift_id uuid NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  effective_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE employee_shifts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON employee_shifts TO authenticated;
GRANT ALL ON employee_shifts TO service_role;
DROP POLICY IF EXISTS "read_employee_shifts_restricted" ON employee_shifts;
CREATE POLICY "read_employee_shifts_restricted"
  ON employee_shifts FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('admin', 'plant_director', 'manager')
  ));
CREATE INDEX IF NOT EXISTS idx_employee_shifts_emp ON employee_shifts(employee_id);

-- environmental_alerts
CREATE TABLE IF NOT EXISTS environmental_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type text NOT NULL,
  severity notification_severity NOT NULL DEFAULT 'warning',
  reading_type environmental_reading_type,
  threshold_value numeric,
  actual_value numeric,
  unit text,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  triggered_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolution_notes text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE environmental_alerts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON environmental_alerts TO authenticated;
GRANT ALL ON environmental_alerts TO service_role;
CREATE INDEX IF NOT EXISTS idx_env_alerts_triggered ON environmental_alerts(triggered_at DESC);

-- energy_sources
CREATE TABLE IF NOT EXISTS energy_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  source_type energy_type NOT NULL,
  supplier text,
  unit text NOT NULL,
  conversion_factor_kwh numeric DEFAULT 1,
  co2_emission_factor numeric DEFAULT 0,
  co2_emission_unit text DEFAULT 'kg/kWh',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE energy_sources ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_sources TO authenticated;
GRANT ALL ON energy_sources TO service_role;
CREATE TRIGGER set_updated_at_energy_sources
  BEFORE UPDATE ON energy_sources
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- production_shifts
CREATE TABLE IF NOT EXISTS production_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_line_id uuid NOT NULL REFERENCES production_lines(id) ON DELETE CASCADE,
  shift_id uuid NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  record_date date NOT NULL DEFAULT CURRENT_DATE,
  output_weight_kg numeric DEFAULT 0,
  rejected_weight_kg numeric DEFAULT 0,
  target_weight_kg numeric,
  operator_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE (production_line_id, shift_id, record_date)
);
ALTER TABLE production_shifts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON production_shifts TO authenticated;
GRANT ALL ON production_shifts TO service_role;
CREATE INDEX IF NOT EXISTS idx_production_shifts_date ON production_shifts(record_date);
