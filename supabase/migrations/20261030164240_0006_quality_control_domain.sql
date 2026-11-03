/*
# Quality Control Domain

## Purpose
Implements the quality control and laboratory data model for the CHANGLONG INTELLIGENCE platform.
Allows authorized administrators to configure quality standards and record inspection results.

## New Tables

### quality_standards
- `id`, `name`, `steel_grade` (text), `parameter` (text), `min_value` (numeric),
  `max_value` (numeric), `unit` (text), `is_active`, `created_at`, `updated_at`

### quality_inspections
- `id`, `inspection_number` (unique), `batch_id` (FK production_batches),
  `steel_grade`, `inspector_id` (FK profiles), `inspection_date` (timestamptz),
  `result` (enum: pass/fail/conditional), `notes`, `is_demo`, timestamps

### quality_measurements
- `id`, `inspection_id` (FK), `parameter` (text), `value` (numeric), `unit` (text),
  `min_value`, `max_value`, `result` (enum: pass/fail), `is_demo`, `created_at`

### quality_defects
- `id`, `inspection_id` (FK), `defect_type` (text), `severity` (enum), `description`,
  `count` (int), `is_demo`, `created_at`

## Security
- RLS on all tables. Authenticated read; service_role write.
- Quality standards readable by all authenticated; managed by service_role only.
*/

DO $$ BEGIN
  CREATE TYPE quality_result AS ENUM ('pass', 'fail', 'conditional');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE defect_severity AS ENUM ('minor', 'major', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- QUALITY STANDARDS
-- ============================================================
CREATE TABLE IF NOT EXISTS quality_standards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  steel_grade text NOT NULL,
  parameter text NOT NULL,
  min_value numeric(12,3),
  max_value numeric(12,3),
  unit text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quality_standards ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON quality_standards TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON quality_standards TO service_role;

DROP POLICY IF EXISTS "qstd_select_auth" ON quality_standards;
CREATE POLICY "qstd_select_auth" ON quality_standards FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "qstd_service" ON quality_standards;
CREATE POLICY "qstd_service" ON quality_standards FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- QUALITY INSPECTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS quality_inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_number text NOT NULL UNIQUE,
  batch_id uuid REFERENCES production_batches(id) ON DELETE SET NULL,
  steel_grade text,
  inspector_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  inspection_date timestamptz NOT NULL DEFAULT now(),
  result quality_result NOT NULL DEFAULT 'pass',
  notes text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quality_inspections ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON quality_inspections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON quality_inspections TO service_role;

DROP POLICY IF EXISTS "qinsp_select_auth" ON quality_inspections;
CREATE POLICY "qinsp_select_auth" ON quality_inspections FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "qinsp_service" ON quality_inspections;
CREATE POLICY "qinsp_service" ON quality_inspections FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_qinsp_batch ON quality_inspections(batch_id);
CREATE INDEX IF NOT EXISTS idx_qinsp_date ON quality_inspections(inspection_date);

-- ============================================================
-- QUALITY MEASUREMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS quality_measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id uuid REFERENCES quality_inspections(id) ON DELETE CASCADE,
  parameter text NOT NULL,
  value numeric(12,3) NOT NULL,
  unit text NOT NULL,
  min_value numeric(12,3),
  max_value numeric(12,3),
  result quality_result NOT NULL DEFAULT 'pass',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quality_measurements ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON quality_measurements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON quality_measurements TO service_role;

DROP POLICY IF EXISTS "qmeas_select_auth" ON quality_measurements;
CREATE POLICY "qmeas_select_auth" ON quality_measurements FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "qmeas_service" ON quality_measurements;
CREATE POLICY "qmeas_service" ON quality_measurements FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_qmeas_insp ON quality_measurements(inspection_id);

-- ============================================================
-- QUALITY DEFECTS
-- ============================================================
CREATE TABLE IF NOT EXISTS quality_defects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id uuid REFERENCES quality_inspections(id) ON DELETE CASCADE,
  defect_type text NOT NULL,
  severity defect_severity NOT NULL DEFAULT 'minor',
  description text,
  count integer NOT NULL DEFAULT 1 CHECK (count > 0),
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quality_defects ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON quality_defects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON quality_defects TO service_role;

DROP POLICY IF EXISTS "qdef_select_auth" ON quality_defects;
CREATE POLICY "qdef_select_auth" ON quality_defects FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "qdef_service" ON quality_defects;
CREATE POLICY "qdef_service" ON quality_defects FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================
DROP TRIGGER IF EXISTS qstd_set_updated_at ON quality_standards;
CREATE TRIGGER qstd_set_updated_at BEFORE UPDATE ON quality_standards
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS qinsp_set_updated_at ON quality_inspections;
CREATE TRIGGER qinsp_set_updated_at BEFORE UPDATE ON quality_inspections
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
