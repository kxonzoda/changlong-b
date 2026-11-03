/*
# Demo Seed Data — Quality, Environment, Workforce, Supplementary

## Purpose
Populates the new database domains with clearly-labeled demo data.
All records have is_demo = true.

## Data Inserted
1. Quality standards (6): carbon, silicon, manganese for Q235B and Q345B grades
2. Quality inspections (10) with measurements and defects
3. Environmental readings (30 days of air quality + noise)
4. Emission records (30 days of CO2 estimates)
5. Waste records (5)
6. Attendance records (7 days for employees)
7. Suppliers (3) and purchase requests (4)
8. Warehouse locations (4)
9. Energy targets and cost records
*/

-- ============================================================
-- QUALITY STANDARDS
-- ============================================================
INSERT INTO quality_standards (name, steel_grade, parameter, min_value, max_value, unit, is_active) VALUES
  ('Q235B Carbon Content', 'Q235B', 'carbon', 0.12, 0.20, '%', true),
  ('Q235B Silicon Content', 'Q235B', 'silicon', 0.10, 0.35, '%', true),
  ('Q235B Manganese Content', 'Q235B', 'manganese', 0.30, 0.70, '%', true),
  ('Q345B Carbon Content', 'Q345B', 'carbon', 0.15, 0.22, '%', true),
  ('Q345B Silicon Content', 'Q345B', 'silicon', 0.15, 0.40, '%', true),
  ('Q345B Manganese Content', 'Q345B', 'manganese', 1.00, 1.60, '%', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- QUALITY INSPECTIONS + MEASUREMENTS + DEFECTS
-- ============================================================
DO $$
DECLARE
  v_batch record;
  v_insp_id uuid;
  v_result text;
  v_carbon numeric;
  v_silicon numeric;
  v_manganese numeric;
  v_counter integer := 0;
BEGIN
  FOR v_batch IN SELECT id, steel_grade FROM production_batches WHERE is_demo = true ORDER BY created_at DESC LIMIT 10 LOOP
    v_counter := v_counter + 1;
    v_result := CASE WHEN random() < 0.85 THEN 'pass' ELSE 'conditional' END;

    INSERT INTO quality_inspections (inspection_number, batch_id, steel_grade, inspection_date, result, notes, is_demo)
    VALUES ('QI-2025-' || lpad(v_counter::text, 3, '0'), v_batch.id, v_batch.steel_grade,
      now() - (v_counter || ' days')::interval, v_result::quality_result,
      CASE WHEN v_result = 'conditional' THEN 'Minor deviations noted, batch released with conditions' ELSE 'All parameters within specification' END,
      true)
    RETURNING id INTO v_insp_id;

    v_carbon := CASE WHEN v_batch.steel_grade = 'Q235B' THEN 0.14 + random() * 0.05 ELSE 0.17 + random() * 0.04 END;
    v_silicon := CASE WHEN v_batch.steel_grade = 'Q235B' THEN 0.18 + random() * 0.12 ELSE 0.22 + random() * 0.15 END;
    v_manganese := CASE WHEN v_batch.steel_grade = 'Q235B' THEN 0.45 + random() * 0.2 ELSE 1.2 + random() * 0.3 END;

    INSERT INTO quality_measurements (inspection_id, parameter, value, unit, min_value, max_value, result, is_demo)
    VALUES
      (v_insp_id, 'carbon', v_carbon, '%', 0.12, 0.20,
        CASE WHEN v_carbon BETWEEN 0.12 AND 0.20 THEN 'pass'::quality_result ELSE 'fail'::quality_result END, true),
      (v_insp_id, 'silicon', v_silicon, '%', 0.10, 0.35,
        CASE WHEN v_silicon BETWEEN 0.10 AND 0.35 THEN 'pass'::quality_result ELSE 'fail'::quality_result END, true),
      (v_insp_id, 'manganese', v_manganese, '%', 0.30, 0.70,
        CASE WHEN v_manganese BETWEEN 0.30 AND 0.70 THEN 'pass'::quality_result ELSE 'fail'::quality_result END, true);

    IF v_result = 'conditional' THEN
      INSERT INTO quality_defects (inspection_id, defect_type, severity, description, count, is_demo)
      VALUES (v_insp_id, 'surface', 'minor'::defect_severity, 'Minor surface oxidation detected', 3, true);
    END IF;
  END LOOP;
END $$;

-- ============================================================
-- ENVIRONMENTAL READINGS (30 days)
-- ============================================================
DO $$
DECLARE
  v_day integer;
  v_date timestamptz;
  v_dept_sm uuid;
  v_dept_rm uuid;
BEGIN
  SELECT id INTO v_dept_sm FROM departments WHERE code = 'SM' AND is_demo = true;
  SELECT id INTO v_dept_rm FROM departments WHERE code = 'RM' AND is_demo = true;

  FOR v_day IN 0..29 LOOP
    v_date := (CURRENT_DATE - v_day) + INTERVAL '10 hours';

    INSERT INTO environmental_readings (reading_type, reading_time, value, unit, department_id, quality, is_demo)
    VALUES
      ('air_quality', v_date, 35 + random() * 25, 'AQI', v_dept_sm, 'good', true),
      ('dust', v_date, 2.5 + random() * 3.0, 'mg/m3', v_dept_sm, 'good', true),
      ('noise', v_date, 75 + random() * 15, 'dB', v_dept_rm, 'good', true),
      ('water_quality', v_date, 7.0 + random() * 0.5, 'pH', NULL, 'good', true);
  END LOOP;
END $$;

-- ============================================================
-- EMISSION RECORDS (30 days of estimated CO2)
-- ============================================================
DO $$
DECLARE
  v_day integer;
  v_date date;
  v_dept uuid;
BEGIN
  SELECT id INTO v_dept FROM departments WHERE code = 'SM' AND is_demo = true;

  FOR v_day IN 0..29 LOOP
    v_date := CURRENT_DATE - v_day;

    INSERT INTO emission_records (emission_type, emission_date, value, unit, source_type, department_id, is_demo)
    VALUES
      ('co2', v_date, 28000 + random() * 6000, 'kg', 'estimated', v_dept, true),
      ('sox', v_date, 15 + random() * 10, 'kg', 'estimated', v_dept, true),
      ('nox', v_date, 22 + random() * 12, 'kg', 'estimated', v_dept, true),
      ('pm', v_date, 8 + random() * 6, 'kg', 'estimated', v_dept, true);
  END LOOP;
END $$;

-- ============================================================
-- WASTE RECORDS
-- ============================================================
INSERT INTO waste_records (waste_type, waste_date, quantity, unit, disposal_method, department_id, is_demo)
SELECT 'Slag', CURRENT_DATE - d, 45 + random() * 30, 'tonne', 'Recycled to construction', (SELECT id FROM departments WHERE code = 'SM' AND is_demo = true), true
FROM generate_series(0, 4) AS d;

INSERT INTO waste_records (waste_type, waste_date, quantity, unit, disposal_method, department_id, is_demo)
SELECT 'Used Refractory', CURRENT_DATE - d, 5 + random() * 5, 'tonne', 'Hazardous waste disposal', (SELECT id FROM departments WHERE code = 'SM' AND is_demo = true), true
FROM generate_series(0, 2) AS d;

-- ============================================================
-- EMPLOYEES (needed for workforce tables)
-- ============================================================
INSERT INTO employees (employee_number, full_name, department_id, position, hire_date, status, is_demo)
VALUES
  ('EMP-001', 'Zhang Wei', (SELECT id FROM departments WHERE code = 'SM' AND is_demo = true), 'Furnace Operator', '2020-03-15', 'active', true),
  ('EMP-002', 'Li Ming', (SELECT id FROM departments WHERE code = 'SM' AND is_demo = true), 'Shift Supervisor', '2019-07-01', 'active', true),
  ('EMP-003', 'Wang Fang', (SELECT id FROM departments WHERE code = 'RM' AND is_demo = true), 'Mill Operator', '2021-01-20', 'active', true),
  ('EMP-004', 'Chen Hua', (SELECT id FROM departments WHERE code = 'RM' AND is_demo = true), 'Quality Inspector', '2018-11-10', 'active', true),
  ('EMP-005', 'Liu Yang', (SELECT id FROM departments WHERE code = 'EU' AND is_demo = true), 'Utility Technician', '2022-05-08', 'on_leave', true),
  ('EMP-006', 'Zhao Ling', (SELECT id FROM departments WHERE code = 'MT' AND is_demo = true), 'Maintenance Technician', '2017-09-25', 'active', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- ATTENDANCE RECORDS (7 days)
-- ============================================================
DO $$
DECLARE
  v_emp record;
  v_day integer;
  v_date date;
  v_status text;
BEGIN
  FOR v_emp IN SELECT id FROM employees WHERE is_demo = true LOOP
    FOR v_day IN 0..6 LOOP
      v_date := CURRENT_DATE - v_day;
      v_status := CASE
        WHEN random() < 0.85 THEN 'present'
        WHEN random() < 0.5 THEN 'late'
        ELSE 'absent'
      END;

      INSERT INTO attendance_records (employee_id, record_date, status, hours_worked, is_demo)
      VALUES (v_emp.id, v_date, v_status::attendance_status,
        CASE WHEN v_status = 'present' THEN 8.0 WHEN v_status = 'late' THEN 7.5 ELSE 0 END, true)
      ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- QUALIFICATIONS
-- ============================================================
INSERT INTO qualifications (employee_id, name, issued_date, expiry_date, issuer, is_demo)
SELECT e.id, 'Furnace Operation Certificate', '2023-01-15', '2026-01-15', 'National Metallurgy Institute', true
FROM employees e WHERE e.employee_number = 'EMP-001' AND e.is_demo = true;

INSERT INTO qualifications (employee_id, name, issued_date, expiry_date, issuer, is_demo)
SELECT e.id, 'Safety Management Certification', '2022-06-01', '2025-06-01', 'Work Safety Bureau', true
FROM employees e WHERE e.employee_number = 'EMP-002' AND e.is_demo = true;

INSERT INTO qualifications (employee_id, name, issued_date, expiry_date, issuer, is_demo)
SELECT e.id, 'Welding Inspector Certification', '2023-03-20', '2026-03-20', 'International Welding Institute', true
FROM employees e WHERE e.employee_number = 'EMP-004' AND e.is_demo = true;

-- ============================================================
-- TRAINING RECORDS
-- ============================================================
INSERT INTO training_records (employee_id, course_name, completion_date, status, is_demo)
VALUES
  ((SELECT id FROM employees WHERE employee_number = 'EMP-001' AND is_demo = true), 'Advanced Furnace Operations', CURRENT_DATE - 60, 'completed', true),
  ((SELECT id FROM employees WHERE employee_number = 'EMP-003' AND is_demo = true), 'Rolling Mill Safety', CURRENT_DATE - 30, 'completed', true),
  ((SELECT id FROM employees WHERE employee_number = 'EMP-006' AND is_demo = true), 'Predictive Maintenance Techniques', NULL, 'in_progress', true),
  ((SELECT id FROM employees WHERE employee_number = 'EMP-002' AND is_demo = true), 'Emergency Response Leadership', NULL, 'scheduled', true);

-- ============================================================
-- SUPPLIERS
-- ============================================================
INSERT INTO suppliers (name, code, contact_name, contact_phone, contact_email, address, is_active, is_demo) VALUES
  ('Shanghai Refractory Co.', 'SUP-001', 'Mr. Chen', '+86 21 5555 0100', 'sales@shrefractory.com', 'Shanghai, China', true, true),
  ('Beijing Steel Parts Ltd.', 'SUP-002', 'Ms. Wang', '+86 10 6666 0200', 'orders@bjparts.com', 'Beijing, China', true, true),
  ('Tianjin Hydraulics Inc.', 'SUP-003', 'Mr. Liu', '+86 22 7777 0300', 'info@tjhydraulics.com', 'Tianjin, China', true, true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- PURCHASE REQUESTS
-- ============================================================
INSERT INTO purchase_requests (request_number, item_id, supplier_id, quantity, unit, status, requested_by, is_demo) VALUES
  ('PR-2025-001', (SELECT id FROM warehouse_items WHERE item_code = 'ELC-001' AND is_demo = true),
    (SELECT id FROM suppliers WHERE code = 'SUP-001' AND is_demo = true), 10, 'pcs', 'approved', NULL, true),
  ('PR-2025-002', (SELECT id FROM warehouse_items WHERE item_code = 'BRG-003' AND is_demo = true),
    (SELECT id FROM suppliers WHERE code = 'SUP-002' AND is_demo = true), 15, 'pcs', 'ordered', NULL, true),
  ('PR-2025-003', (SELECT id FROM warehouse_items WHERE item_code = 'GSK-010' AND is_demo = true),
    (SELECT id FROM suppliers WHERE code = 'SUP-003' AND is_demo = true), 100, 'm', 'pending', NULL, true),
  ('PR-2025-004', (SELECT id FROM warehouse_items WHERE item_code = 'HYD-004' AND is_demo = true),
    (SELECT id FROM suppliers WHERE code = 'SUP-003' AND is_demo = true), 200, 'L', 'received', NULL, true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- WAREHOUSE LOCATIONS
-- ============================================================
INSERT INTO warehouse_locations (name, code, description, is_active) VALUES
  ('Main Store A1', 'LOC-A1', 'Primary spare parts storage', true),
  ('Raw Materials Yard', 'LOC-RMY', 'Outdoor raw material storage', true),
  ('Chemical Store C1', 'LOC-C1', 'Chemicals and consumables', true),
  ('Heavy Equipment Bay', 'LOC-HEB', 'Large equipment and motors', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- ENERGY TARGETS (last 30 days for electricity meters)
-- ============================================================
DO $$
DECLARE
  v_meter record;
  v_day integer;
  v_date date;
BEGIN
  FOR v_meter IN SELECT id, unit FROM energy_meters WHERE is_demo = true AND energy_type = 'electricity' LOOP
    FOR v_day IN 0..29 LOOP
      v_date := CURRENT_DATE - v_day;
      INSERT INTO energy_targets (meter_id, target_date, target_value, unit, is_demo)
      VALUES (v_meter.id, v_date, 50000, v_meter.unit, true)
      ON CONFLICT (meter_id, target_date) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- ENERGY COST RECORDS (30 days)
-- ============================================================
DO $$
DECLARE
  v_meter record;
  v_day integer;
  v_date date;
  v_value numeric;
  v_unit_cost numeric;
BEGIN
  FOR v_meter IN SELECT id, energy_type FROM energy_meters WHERE is_demo = true LOOP
    v_unit_cost := CASE v_meter.energy_type
      WHEN 'electricity' THEN 0.65
      WHEN 'natural_gas' THEN 3.50
      WHEN 'water' THEN 0.15
      WHEN 'compressed_air' THEN 0.08
      ELSE 1.00
    END;

    FOR v_day IN 0..29 LOOP
      v_date := CURRENT_DATE - v_day;
      v_value := 40000 + random() * 20000;
      INSERT INTO energy_cost_records (meter_id, cost_date, unit_cost, total_cost, currency, is_demo)
      VALUES (v_meter.id, v_date, v_unit_cost, round((v_value * v_unit_cost)::numeric, 2), 'CNY', true)
      ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;
