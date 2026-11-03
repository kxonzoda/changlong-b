/*
# Fix RLS Policies for 0014 Tables + Add Equipment Downtime Table

## Problem
10 tables created in migration 0014 have RLS enabled but NO policies.
Authenticated users cannot read ANY data from these tables — they appear empty.

## Changes
1. Add SELECT policies for authenticated on all 10 locked tables
2. Add equipment_downtime table (spec section E)
3. Add maintenance completion rate function
4. Seed equipment_downtime with demo data
*/

-- 1. Fix SELECT policies for locked tables
DROP POLICY IF EXISTS "select_energy_sources_authenticated" ON energy_sources;
CREATE POLICY "select_energy_sources_authenticated" ON energy_sources FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "esrc_service" ON energy_sources;
CREATE POLICY "esrc_service" ON energy_sources FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_environmental_alerts_authenticated" ON environmental_alerts;
CREATE POLICY "select_environmental_alerts_authenticated" ON environmental_alerts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "envalert_service" ON environmental_alerts;
CREATE POLICY "envalert_service" ON environmental_alerts FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_equipment_events_authenticated" ON equipment_events;
CREATE POLICY "select_equipment_events_authenticated" ON equipment_events FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "eqevt_service" ON equipment_events;
CREATE POLICY "eqevt_service" ON equipment_events FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_equipment_operating_hours_authenticated" ON equipment_operating_hours;
CREATE POLICY "select_equipment_operating_hours_authenticated" ON equipment_operating_hours FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "eqoh_service" ON equipment_operating_hours;
CREATE POLICY "eqoh_service" ON equipment_operating_hours FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_laboratory_results_authenticated" ON laboratory_results;
CREATE POLICY "select_laboratory_results_authenticated" ON laboratory_results FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "labres_service" ON laboratory_results;
CREATE POLICY "labres_service" ON laboratory_results FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_maintenance_history_authenticated" ON maintenance_history;
CREATE POLICY "select_maintenance_history_authenticated" ON maintenance_history FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "maint_hist_service" ON maintenance_history;
CREATE POLICY "maint_hist_service" ON maintenance_history FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_production_shifts_authenticated" ON production_shifts;
CREATE POLICY "select_production_shifts_authenticated" ON production_shifts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "prodshift_service" ON production_shifts;
CREATE POLICY "prodshift_service" ON production_shifts FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_quality_batches_authenticated" ON quality_batches;
CREATE POLICY "select_quality_batches_authenticated" ON quality_batches FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "qbatch_service" ON quality_batches;
CREATE POLICY "qbatch_service" ON quality_batches FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_quality_parameters_authenticated" ON quality_parameters;
CREATE POLICY "select_quality_parameters_authenticated" ON quality_parameters FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "qparam_service" ON quality_parameters;
CREATE POLICY "qparam_service" ON quality_parameters FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "select_stock_transactions_authenticated" ON stock_transactions;
CREATE POLICY "select_stock_transactions_authenticated" ON stock_transactions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "stocktxn_service" ON stock_transactions;
CREATE POLICY "stocktxn_service" ON stock_transactions FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 2. Create equipment_downtime table
CREATE TABLE IF NOT EXISTS equipment_downtime (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  work_order_id uuid REFERENCES maintenance_work_orders(id) ON DELETE SET NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  duration_hours numeric(10,2) GENERATED ALWAYS AS (
    CASE WHEN end_time IS NOT NULL
      THEN EXTRACT(EPOCH FROM (end_time - start_time)) / 3600
    ELSE NULL END
  ) STORED,
  reason text,
  category text NOT NULL DEFAULT 'planned',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE equipment_downtime ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_downtime TO authenticated;
GRANT ALL ON equipment_downtime TO service_role;

DROP POLICY IF EXISTS "select_equipment_downtime_authenticated" ON equipment_downtime;
CREATE POLICY "select_equipment_downtime_authenticated" ON equipment_downtime FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "eqdown_service" ON equipment_downtime;
CREATE POLICY "eqdown_service" ON equipment_downtime FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_equipment_downtime_equipment ON equipment_downtime(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_downtime_start ON equipment_downtime(start_time);

-- 3. Maintenance completion rate function
CREATE OR REPLACE FUNCTION get_maintenance_completion_rate(
  p_days integer DEFAULT 30
)
RETURNS TABLE(
  total_work_orders bigint,
  completed_work_orders bigint,
  completion_rate numeric,
  overdue_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::bigint AS total_work_orders,
    COUNT(*) FILTER (WHERE status = 'completed')::bigint AS completed_work_orders,
    CASE
      WHEN COUNT(*) > 0
        THEN ROUND(COUNT(*) FILTER (WHERE status = 'completed')::numeric / COUNT(*) * 100, 2)
      ELSE 0
    END AS completion_rate,
    COUNT(*) FILTER (WHERE status = 'overdue' OR (status IN ('open','in_progress') AND scheduled_date < now()))::bigint AS overdue_count
  FROM maintenance_work_orders
  WHERE created_at >= now() - (p_days || ' days')::interval;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_maintenance_completion_rate(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_maintenance_completion_rate(integer) TO authenticated;

-- 4. Seed equipment_downtime with demo data
DO $$
DECLARE
  v_eaf01 uuid;
  v_eaf02 uuid;
  v_rm_a uuid;
BEGIN
  SELECT id INTO v_eaf01 FROM equipment WHERE equipment_code = 'EAF-01' LIMIT 1;
  SELECT id INTO v_eaf02 FROM equipment WHERE equipment_code = 'EAF-02' LIMIT 1;
  SELECT id INTO v_rm_a FROM equipment WHERE equipment_code = 'RM-A' LIMIT 1;

  IF v_eaf01 IS NOT NULL THEN
    INSERT INTO equipment_downtime (equipment_id, start_time, end_time, reason, category, is_demo)
    VALUES
      (v_eaf01, now() - interval '5 days 8 hours', now() - interval '5 days 5 hours', 'Electrode replacement', 'planned', true),
      (v_eaf01, now() - interval '12 days 14 hours', now() - interval '12 days 10 hours', 'Cooling system leak', 'unplanned', true),
      (v_eaf01, now() - interval '20 days 6 hours', now() - interval '20 days 4 hours', 'Scheduled inspection', 'planned', true)
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_eaf02 IS NOT NULL THEN
    INSERT INTO equipment_downtime (equipment_id, start_time, end_time, reason, category, is_demo)
    VALUES
      (v_eaf02, now() - interval '3 days 2 hours', now() - interval '3 days 1 hour', 'Hydraulic pressure drop', 'unplanned', true),
      (v_eaf02, now() - interval '15 days 10 hours', now() - interval '15 days 6 hours', 'Refractory lining repair', 'planned', true)
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_rm_a IS NOT NULL THEN
    INSERT INTO equipment_downtime (equipment_id, start_time, end_time, reason, category, is_demo)
    VALUES
      (v_rm_a, now() - interval '8 days 16 hours', now() - interval '8 days 12 hours', 'Roll change', 'planned', true),
      (v_rm_a, now() - interval '25 days 4 hours', now() - interval '25 days 3 hours', 'Bearing failure', 'unplanned', true)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;
