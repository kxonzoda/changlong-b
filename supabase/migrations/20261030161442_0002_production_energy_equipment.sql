/*
# Production, Energy, and Equipment Core Domains

## Purpose
Implements the primary industrial data domains for CHANGLONG INTELLIGENCE:
production tracking, energy intelligence, and equipment management.

## New Tables

### production_lines
- `id`, `name`, `code` (unique), `department_id` (FK), `is_active`, `is_demo`, timestamps

### production_batches
- `id`, `batch_number` (unique), `heat_number` (text), `steel_grade` (text),
  `production_line_id` (FK), `status` (enum: planned/in_progress/completed/on_hold/cancelled),
  `start_time`, `end_time`, `input_weight_kg`, `output_weight_kg`, `rejected_weight_kg`,
  `is_demo`, timestamps

### production_records
- `id`, `batch_id` (FK), `production_line_id` (FK), `shift_id` (FK),
  `record_date` (date), `steel_grade`, `output_weight_kg`, `rejected_weight_kg`,
  `target_weight_kg`, `operator_id` (FK profiles), `notes`, `is_demo`, timestamps

### production_targets
- `id`, `production_line_id` (FK), `target_date` (date), `target_weight_kg`,
  `is_demo`, timestamps

### energy_meters
- `id`, `meter_code` (unique), `name`, `energy_type` (enum: electricity/natural_gas/water/steam/compressed_air),
  `department_id` (FK), `equipment_id` (FK, nullable), `unit` (text), `is_active`, `is_demo`, timestamps

### energy_readings
- `id`, `meter_id` (FK), `reading_time` (timestamptz), `value` (numeric), `unit`,
  `quality` (enum: good/suspect/estimated/invalid), `is_demo`, timestamps

### energy_consumption_daily
- `id`, `meter_id` (FK), `consumption_date` (date), `total_value`, `unit`,
  `is_demo`, timestamps (aggregated daily consumption per meter)

### equipment
- `id`, `equipment_code` (unique), `name`, `category_id` (FK), `department_id` (FK),
  `production_line_id` (FK nullable), `status` (enum: operational/under_maintenance/idle/fault/decommissioned),
  `health_score` (int 0-100), `operating_hours` (numeric), `is_demo`, timestamps

### equipment_categories
- `id`, `name`, `code` (unique), `description`, timestamps

### equipment_telemetry
- `id`, `equipment_id` (FK), `reading_time` (timestamptz), `metric` (text: temperature/vibration/pressure/etc),
  `value` (numeric), `unit`, `quality` (enum), `is_demo`, timestamps

## Security
- RLS on all tables. Authenticated users can read operational data.
- Write access restricted to service_role (edge functions / privileged services).
- Equipment telemetry is read-only for authenticated (ingested via edge function).

## Important Notes
1. Energy and production tables are linked for energy-intensity calculations (kWh per tonne).
2. Telemetry table is designed for future IoT ingestion but currently populated with clearly-labeled demo data.
3. All measurement values use numeric type for industrial precision.
4. Unique constraints prevent duplicate batch numbers and meter codes.
*/

-- ============================================================
-- ENUM TYPES
-- ============================================================
DO $$ BEGIN
  CREATE TYPE batch_status AS ENUM ('planned', 'in_progress', 'completed', 'on_hold', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE energy_type AS ENUM ('electricity', 'natural_gas', 'water', 'steam', 'compressed_air');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE reading_quality AS ENUM ('good', 'suspect', 'estimated', 'invalid');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE equipment_status AS ENUM ('operational', 'under_maintenance', 'idle', 'fault', 'decommissioned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PRODUCTION LINES
-- ============================================================
CREATE TABLE IF NOT EXISTS production_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE production_lines ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON production_lines TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_lines TO service_role;

DROP POLICY IF EXISTS "plines_select_auth" ON production_lines;
CREATE POLICY "plines_select_auth" ON production_lines FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "plines_service" ON production_lines;
CREATE POLICY "plines_service" ON production_lines FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_plines_dept ON production_lines(department_id);

-- ============================================================
-- PRODUCTION BATCHES
-- ============================================================
CREATE TABLE IF NOT EXISTS production_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_number text NOT NULL UNIQUE,
  heat_number text,
  steel_grade text NOT NULL,
  production_line_id uuid REFERENCES production_lines(id) ON DELETE SET NULL,
  status batch_status NOT NULL DEFAULT 'planned',
  start_time timestamptz,
  end_time timestamptz,
  input_weight_kg numeric(12,2),
  output_weight_kg numeric(12,2),
  rejected_weight_kg numeric(12,2) DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE production_batches ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON production_batches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_batches TO service_role;

DROP POLICY IF EXISTS "pbatch_select_auth" ON production_batches;
CREATE POLICY "pbatch_select_auth" ON production_batches FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "pbatch_service" ON production_batches;
CREATE POLICY "pbatch_service" ON production_batches FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_pbatch_line ON production_batches(production_line_id);
CREATE INDEX IF NOT EXISTS idx_pbatch_status ON production_batches(status);
CREATE INDEX IF NOT EXISTS idx_pbatch_start ON production_batches(start_time);

-- ============================================================
-- PRODUCTION RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS production_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid REFERENCES production_batches(id) ON DELETE SET NULL,
  production_line_id uuid REFERENCES production_lines(id) ON DELETE SET NULL,
  shift_id uuid REFERENCES shifts(id) ON DELETE SET NULL,
  record_date date NOT NULL,
  steel_grade text,
  output_weight_kg numeric(12,2) NOT NULL DEFAULT 0,
  rejected_weight_kg numeric(12,2) NOT NULL DEFAULT 0,
  target_weight_kg numeric(12,2),
  operator_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  notes text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE production_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON production_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_records TO service_role;

DROP POLICY IF EXISTS "prec_select_auth" ON production_records;
CREATE POLICY "prec_select_auth" ON production_records FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "prec_service" ON production_records;
CREATE POLICY "prec_service" ON production_records FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_prec_date ON production_records(record_date);
CREATE INDEX IF NOT EXISTS idx_prec_line ON production_records(production_line_id);

-- ============================================================
-- PRODUCTION TARGETS
-- ============================================================
CREATE TABLE IF NOT EXISTS production_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_line_id uuid REFERENCES production_lines(id) ON DELETE CASCADE,
  target_date date NOT NULL,
  target_weight_kg numeric(12,2) NOT NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (production_line_id, target_date)
);

ALTER TABLE production_targets ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON production_targets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_targets TO service_role;

DROP POLICY IF EXISTS "ptarget_select_auth" ON production_targets;
CREATE POLICY "ptarget_select_auth" ON production_targets FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "ptarget_service" ON production_targets;
CREATE POLICY "ptarget_service" ON production_targets FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- ENERGY METERS
-- ============================================================
CREATE TABLE IF NOT EXISTS energy_meters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_code text NOT NULL UNIQUE,
  name text NOT NULL,
  energy_type energy_type NOT NULL,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  equipment_id uuid,
  unit text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE energy_meters ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_meters TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON energy_meters TO service_role;

DROP POLICY IF EXISTS "emeter_select_auth" ON energy_meters;
CREATE POLICY "emeter_select_auth" ON energy_meters FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "emeter_service" ON energy_meters;
CREATE POLICY "emeter_service" ON energy_meters FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_emeter_type ON energy_meters(energy_type);
CREATE INDEX IF NOT EXISTS idx_emeter_dept ON energy_meters(department_id);

-- ============================================================
-- ENERGY READINGS
-- ============================================================
CREATE TABLE IF NOT EXISTS energy_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id uuid REFERENCES energy_meters(id) ON DELETE CASCADE,
  reading_time timestamptz NOT NULL,
  value numeric(14,3) NOT NULL,
  unit text NOT NULL,
  quality reading_quality NOT NULL DEFAULT 'good',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE energy_readings ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_readings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON energy_readings TO service_role;

DROP POLICY IF EXISTS "eread_select_auth" ON energy_readings;
CREATE POLICY "eread_select_auth" ON energy_readings FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "eread_service" ON energy_readings;
CREATE POLICY "eread_service" ON energy_readings FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_eread_meter_time ON energy_readings(meter_id, reading_time);
CREATE INDEX IF NOT EXISTS idx_eread_time ON energy_readings(reading_time);

-- ============================================================
-- ENERGY DAILY CONSUMPTION (aggregation)
-- ============================================================
CREATE TABLE IF NOT EXISTS energy_consumption_daily (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id uuid REFERENCES energy_meters(id) ON DELETE CASCADE,
  consumption_date date NOT NULL,
  total_value numeric(14,3) NOT NULL,
  unit text NOT NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meter_id, consumption_date)
);

ALTER TABLE energy_consumption_daily ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON energy_consumption_daily TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON energy_consumption_daily TO service_role;

DROP POLICY IF EXISTS "edaily_select_auth" ON energy_consumption_daily;
CREATE POLICY "edaily_select_auth" ON energy_consumption_daily FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "edaily_service" ON energy_consumption_daily;
CREATE POLICY "edaily_service" ON energy_consumption_daily FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- EQUIPMENT CATEGORIES
-- ============================================================
CREATE TABLE IF NOT EXISTS equipment_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment_categories ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON equipment_categories TO service_role;

DROP POLICY IF EXISTS "ecat_select_auth" ON equipment_categories;
CREATE POLICY "ecat_select_auth" ON equipment_categories FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "ecat_service" ON equipment_categories;
CREATE POLICY "ecat_service" ON equipment_categories FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- EQUIPMENT
-- ============================================================
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_code text NOT NULL UNIQUE,
  name text NOT NULL,
  category_id uuid REFERENCES equipment_categories(id) ON DELETE SET NULL,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  production_line_id uuid REFERENCES production_lines(id) ON DELETE SET NULL,
  status equipment_status NOT NULL DEFAULT 'operational',
  health_score integer NOT NULL DEFAULT 100 CHECK (health_score >= 0 AND health_score <= 100),
  operating_hours numeric(10,2) NOT NULL DEFAULT 0,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON equipment TO service_role;

DROP POLICY IF EXISTS "equip_select_auth" ON equipment;
CREATE POLICY "equip_select_auth" ON equipment FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "equip_service" ON equipment;
CREATE POLICY "equip_service" ON equipment FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_equip_dept ON equipment(department_id);
CREATE INDEX IF NOT EXISTS idx_equip_status ON equipment(status);

-- ============================================================
-- EQUIPMENT TELEMETRY
-- ============================================================
CREATE TABLE IF NOT EXISTS equipment_telemetry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  reading_time timestamptz NOT NULL,
  metric text NOT NULL,
  value numeric(14,3) NOT NULL,
  unit text NOT NULL,
  quality reading_quality NOT NULL DEFAULT 'good',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment_telemetry ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON equipment_telemetry TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON equipment_telemetry TO service_role;

DROP POLICY IF EXISTS "telem_select_auth" ON equipment_telemetry;
CREATE POLICY "telem_select_auth" ON equipment_telemetry FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "telem_service" ON equipment_telemetry;
CREATE POLICY "telem_service" ON equipment_telemetry FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_telem_equip_time ON equipment_telemetry(equipment_id, reading_time);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================
DROP TRIGGER IF EXISTS plines_set_updated_at ON production_lines;
CREATE TRIGGER plines_set_updated_at BEFORE UPDATE ON production_lines
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS pbatch_set_updated_at ON production_batches;
CREATE TRIGGER pbatch_set_updated_at BEFORE UPDATE ON production_batches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS prec_set_updated_at ON production_records;
CREATE TRIGGER prec_set_updated_at BEFORE UPDATE ON production_records
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ptarget_set_updated_at ON production_targets;
CREATE TRIGGER ptarget_set_updated_at BEFORE UPDATE ON production_targets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS emeter_set_updated_at ON energy_meters;
CREATE TRIGGER emeter_set_updated_at BEFORE UPDATE ON energy_meters
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS equip_set_updated_at ON equipment;
CREATE TRIGGER equip_set_updated_at BEFORE UPDATE ON equipment
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
