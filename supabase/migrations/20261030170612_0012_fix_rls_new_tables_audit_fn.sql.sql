/*
# Fix RLS policies for new tables and restrict audit_trigger_fn

1. Security Changes
- Added SELECT policies on equipment_components, maintenance_procedures, maintenance_parts, water_usage_records, energy_anomalies so authenticated users can read them (currently RLS blocks all access).
- Revoked EXECUTE on audit_trigger_fn from PUBLIC, anon, and authenticated — it should only be called by triggers, not via RPC.
- log_audit_event, get_equipment_mtbf, get_equipment_mttr are intentionally SECURITY DEFINER callable by authenticated (privileged analytics/mutation pattern).
*/

-- equipment_components: authenticated read
DROP POLICY IF EXISTS "select_equipment_components_authenticated" ON equipment_components;
CREATE POLICY "select_equipment_components_authenticated"
  ON equipment_components FOR SELECT TO authenticated USING (true);

-- maintenance_procedures: authenticated read
DROP POLICY IF EXISTS "select_maintenance_procedures_authenticated" ON maintenance_procedures;
CREATE POLICY "select_maintenance_procedures_authenticated"
  ON maintenance_procedures FOR SELECT TO authenticated USING (true);

-- maintenance_parts: authenticated read
DROP POLICY IF EXISTS "select_maintenance_parts_authenticated" ON maintenance_parts;
CREATE POLICY "select_maintenance_parts_authenticated"
  ON maintenance_parts FOR SELECT TO authenticated USING (true);

-- water_usage_records: authenticated read
DROP POLICY IF EXISTS "select_water_usage_records_authenticated" ON water_usage_records;
CREATE POLICY "select_water_usage_records_authenticated"
  ON water_usage_records FOR SELECT TO authenticated USING (true);

-- energy_anomalies: authenticated read
DROP POLICY IF EXISTS "select_energy_anomalies_authenticated" ON energy_anomalies;
CREATE POLICY "select_energy_anomalies_authenticated"
  ON energy_anomalies FOR SELECT TO authenticated USING (true);

-- Restrict audit_trigger_fn — should NOT be callable via RPC, only by triggers
REVOKE EXECUTE ON FUNCTION public.audit_trigger_fn() FROM PUBLIC, anon, authenticated;
