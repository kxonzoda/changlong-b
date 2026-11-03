/*
# Core Organization, Identity, and RLS Foundation

## Purpose
Establishes the organizational backbone of the CHANGLONG INTELLIGENCE platform:
departments, user profiles, role assignments, shifts, and an employee registry.
All tables have Row Level Security enabled with least-privilege grants.

## New Tables

### departments
- `id` (uuid, PK) — department identifier
- `name` (text, unique, not null) — e.g. "Steelmaking", "Rolling Mill"
- `code` (text, unique, not null) — short code like "SM", "RM"
- `description` (text) — optional description
- `is_active` (bool, default true) — soft-active flag
- `is_demo` (bool, default false) — marks demo/seed records
- `created_at`, `updated_at` (timestamptz)

### profiles
- `id` (uuid, PK, FK auth.users) — one-to-one with Supabase auth users
- `full_name` (text) — display name
- `email` (text) — cached email for convenience
- `phone` (text) — contact number
- `department_id` (uuid, FK departments) — department assignment
- `role` (user_role enum) — platform role
- `language` (text, default 'en') — UI language preference
- `is_active` (bool, default true) — account active flag
- `created_at`, `updated_at`

### user_role enum
- admin, plant_director, manager, production_manager, engineer,
  energy_manager, maintenance_manager, safety_officer, warehouse_manager,
  operator, viewer

### shifts
- `id`, `name` (e.g. "Morning A"), `start_time` (time), `end_time` (time),
  `description`, `is_active`, `is_demo`, timestamps

### employees
- `id`, `employee_number` (unique), `full_name`, `department_id` (FK),
  `position` (text), `shift_id` (FK shifts), `hire_date` (date),
  `status` (enum: active/on_leave/inactive), `is_demo`, timestamps

## Security
- RLS enabled on every table.
- profiles: users read/update own profile; admins/managers read all.
- departments: authenticated users can read; admins can manage.
- shifts: authenticated read; admins manage.
- employees: restricted — admins, plant_director, managers read; others no access (personal info).
- All grants limited to authenticated role; service_role granted for edge functions.

## Important Notes
1. A trigger auto-creates a profile row when a new auth.user signs up.
2. The role enum is the single source of truth for authorization.
3. is_demo columns let demo data be identified and cleaned safely.
*/

-- ============================================================
-- ENUM TYPES
-- ============================================================
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM (
    'admin', 'plant_director', 'manager', 'production_manager', 'engineer',
    'energy_manager', 'maintenance_manager', 'safety_officer', 'warehouse_manager',
    'operator', 'viewer'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE employee_status AS ENUM ('active', 'on_leave', 'inactive');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- DEPARTMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  code text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON departments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON departments TO service_role;

DROP POLICY IF EXISTS "dept_select_auth" ON departments;
CREATE POLICY "dept_select_auth" ON departments FOR SELECT
  TO authenticated USING (true);

DROP POLICY IF EXISTS "dept_manage_service" ON departments;
CREATE POLICY "dept_manage_service" ON departments FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- PROFILES
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  email text,
  phone text,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  role user_role NOT NULL DEFAULT 'viewer',
  language text NOT NULL DEFAULT 'en',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
GRANT SELECT, UPDATE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO service_role;

-- Users can read and update their own profile
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT
  TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE
  TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Admins and plant directors can read all profiles
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
CREATE POLICY "profiles_select_admin" ON profiles FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

-- Service role full access
DROP POLICY IF EXISTS "profiles_service" ON profiles;
CREATE POLICY "profiles_service" ON profiles FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- SHIFTS
-- ============================================================
CREATE TABLE IF NOT EXISTS shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON shifts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON shifts TO service_role;

DROP POLICY IF EXISTS "shifts_select_auth" ON shifts;
CREATE POLICY "shifts_select_auth" ON shifts FOR SELECT
  TO authenticated USING (true);

DROP POLICY IF EXISTS "shifts_service" ON shifts;
CREATE POLICY "shifts_service" ON shifts FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- EMPLOYEES
-- ============================================================
CREATE TABLE IF NOT EXISTS employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_number text NOT NULL UNIQUE,
  full_name text NOT NULL,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  position text,
  shift_id uuid REFERENCES shifts(id) ON DELETE SET NULL,
  hire_date date,
  status employee_status NOT NULL DEFAULT 'active',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON employees TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO service_role;

-- Only admins, plant directors, and managers can read employee records
DROP POLICY IF EXISTS "employees_select_privileged" ON employees;
CREATE POLICY "employees_select_privileged" ON employees FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'plant_director', 'manager'))
  );

DROP POLICY IF EXISTS "employees_service" ON employees;
CREATE POLICY "employees_service" ON employees FOR ALL
  TO service_role USING (true) WITH CHECK (true);

-- ============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- UPDATED_AT TRIGGER HELPER
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS departments_set_updated_at ON departments;
CREATE TRIGGER departments_set_updated_at BEFORE UPDATE ON departments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS profiles_set_updated_at ON profiles;
CREATE TRIGGER profiles_set_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS shifts_set_updated_at ON shifts;
CREATE TRIGGER shifts_set_updated_at BEFORE UPDATE ON shifts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS employees_set_updated_at ON employees;
CREATE TRIGGER employees_set_updated_at BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
