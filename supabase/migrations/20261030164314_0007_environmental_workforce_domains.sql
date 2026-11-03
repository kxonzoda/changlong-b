/*
# Environmental Management & Workforce Domains

## Purpose
Implements environmental monitoring (emissions, waste, water usage) and
workforce management (attendance, qualifications, training) for the CHANGLONG INTELLIGENCE platform.

## New Tables — Environmental

### environmental_readings
- `id`, `reading_type` (enum: air_quality/water_quality/noise/dust), `reading_time`,
  `value`, `unit`, `department_id` (FK), `equipment_id` (FK nullable),
  `quality` (reading_quality), `is_demo`, `created_at`

### emission_records
- `id`, `emission_type` (enum: co2/sox/nox/pm), `emission_date`, `value`, `unit`,
  `source_type` (enum: measured/estimated), `department_id` (FK), `is_demo`, `created_at`

### waste_records
- `id`, `waste_type` (text), `waste_date`, `quantity`, `unit`,
  `disposal_method` (text), `department_id` (FK), `is_demo`, `created_at`

### environmental_targets
- `id`, `metric` (text), `target_value`, `unit`, `target_date`, `is_demo`, timestamps

## New Tables — Workforce

### attendance_records
- `id`, `employee_id` (FK employees), `record_date` (date),
  `status` (enum: present/absent/late/leave), `hours_worked` (numeric), `is_demo`, `created_at`

### qualifications
- `id`, `employee_id` (FK employees), `name` (text), `issued_date` (date),
  `expiry_date` (date), `issuer` (text), `is_demo`, `created_at`

### training_records
- `id`, `employee_id` (FK employees), `course_name` (text), `completion_date` (date),
  `status` (enum: completed/in_progress/scheduled), `is_demo`, `created_at`

## Security
- RLS on all tables. Authenticated read; service_role write.
- Workforce tables (attendance, qualifications, training) restricted to admins/managers like employees.
- Environmental data readable by all authenticated users.
*/

DO $$ BEGIN
  CREATE TYPE environmental_reading_type AS ENUM ('air_quality', 'water_quality', 'noise', 'dust');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE emission_type AS ENUM ('co2', 'sox', 'nox', 'pm');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE emission_source AS ENUM ('measured', 'estimated');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late', 'leave');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE training_status AS ENUM ('completed', 'in_progress', 'scheduled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- ENVIRONMENTAL READINGS
-- ============================================================
CREATE TABLE IF NOT EXISTS environmental_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reading_type environmental_reading_type NOT NULL,
  reading_time timestamptz NOT NULL,
  value numeric(12,3) NOT NULL,
  unit text NOT NULL,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  equipment_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  quality reading_quality NOT NULL DEFAULT 'good',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE environmental_readings ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON environmental_readings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON environmental_readings TO service_role;

DROP POLICY IF EXISTS "env_read_select_auth" ON environmental_readings;
CREATE POLICY "env_read_select_auth" ON environmental_readings FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "env_read_service" ON environmental_readings;
CREATE POLICY "env_read_service" ON environmental_readings FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_env_read_type_time ON environmental_readings(reading_type, reading_time);

-- ============================================================
-- EMISSION RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS emission_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emission_type emission_type NOT NULL,
  emission_date date NOT NULL,
  value numeric(14,3) NOT NULL,
  unit text NOT NULL,
  source_type emission_source NOT NULL DEFAULT 'estimated',
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE emission_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON emission_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON emission_records TO service_role;

DROP POLICY IF EXISTS "emit_select_auth" ON emission_records;
CREATE POLICY "emit_select_auth" ON emission_records FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "emit_service" ON emission_records;
CREATE POLICY "emit_service" ON emission_records FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_emit_type_date ON emission_records(emission_type, emission_date);

-- ============================================================
-- WASTE RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS waste_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  waste_type text NOT NULL,
  waste_date date NOT NULL,
  quantity numeric(12,3) NOT NULL,
  unit text NOT NULL,
  disposal_method text,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE waste_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON waste_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON waste_records TO service_role;

DROP POLICY IF EXISTS "waste_select_auth" ON waste_records;
CREATE POLICY "waste_select_auth" ON waste_records FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "waste_service" ON waste_records;
CREATE POLICY "waste_service" ON waste_records FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- ENVIRONMENTAL TARGETS
-- ============================================================
CREATE TABLE IF NOT EXISTS environmental_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric text NOT NULL,
  target_value numeric(14,3) NOT NULL,
  unit text NOT NULL,
  target_date date NOT NULL,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE environmental_targets ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON environmental_targets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON environmental_targets TO service_role;

DROP POLICY IF EXISTS "env_tgt_select_auth" ON environmental_targets;
CREATE POLICY "env_tgt_select_auth" ON environmental_targets FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "env_tgt_service" ON environmental_targets;
CREATE POLICY "env_tgt_service" ON environmental_targets FOR ALL
  TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS env_tgt_set_updated_at ON environmental_targets;
CREATE TRIGGER env_tgt_set_updated_at BEFORE UPDATE ON environmental_targets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- ATTENDANCE RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid REFERENCES employees(id) ON DELETE CASCADE,
  record_date date NOT NULL,
  status attendance_status NOT NULL DEFAULT 'present',
  hours_worked numeric(5,2) DEFAULT 8,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON attendance_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON attendance_records TO service_role;

-- Restricted like employees — admins, plant_directors, managers
DROP POLICY IF EXISTS "att_select_privileged" ON attendance_records;
CREATE POLICY "att_select_privileged" ON attendance_records FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "att_service" ON attendance_records;
CREATE POLICY "att_service" ON attendance_records FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_att_emp_date ON attendance_records(employee_id, record_date);

-- ============================================================
-- QUALIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS qualifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid REFERENCES employees(id) ON DELETE CASCADE,
  name text NOT NULL,
  issued_date date,
  expiry_date date,
  issuer text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE qualifications ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON qualifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON qualifications TO service_role;

DROP POLICY IF EXISTS "qual_select_privileged" ON qualifications;
CREATE POLICY "qual_select_privileged" ON qualifications FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "qual_service" ON qualifications;
CREATE POLICY "qual_service" ON qualifications FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- TRAINING RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS training_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid REFERENCES employees(id) ON DELETE CASCADE,
  course_name text NOT NULL,
  completion_date date,
  status training_status NOT NULL DEFAULT 'scheduled',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE training_records ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON training_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON training_records TO service_role;

DROP POLICY IF EXISTS "train_select_privileged" ON training_records;
CREATE POLICY "train_select_privileged" ON training_records FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );
DROP POLICY IF EXISTS "train_service" ON training_records;
CREATE POLICY "train_service" ON training_records FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_train_emp ON training_records(employee_id);
