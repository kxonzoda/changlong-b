/*
# Demo Seed Data — CHANGLONG INTELLIGENCE Metallurgical Plant (retry)

Fixes the enum cast issue in the energy_readings insert by casting the CASE
result to reading_quality. All other content identical to the previous attempt.
*/

-- ============================================================
-- CLEAN EXISTING DEMO DATA
-- ============================================================
DELETE FROM inventory_movements WHERE is_demo = true;
DELETE FROM warehouse_items WHERE is_demo = true;
DELETE FROM warehouse_categories WHERE code IN ('SP', 'RM', 'CON');
DELETE FROM safety_incidents WHERE is_demo = true;
DELETE FROM maintenance_work_orders WHERE is_demo = true;
DELETE FROM maintenance_schedules WHERE is_demo = true;
DELETE FROM energy_consumption_daily WHERE is_demo = true;
DELETE FROM energy_readings WHERE is_demo = true;
DELETE FROM equipment_telemetry WHERE is_demo = true;
DELETE FROM energy_meters WHERE is_demo = true;
DELETE FROM equipment WHERE is_demo = true;
DELETE FROM equipment_categories WHERE code IN ('FUR', 'CRN', 'MIL', 'PMP', 'CMP');
DELETE FROM production_targets WHERE is_demo = true;
DELETE FROM production_records WHERE is_demo = true;
DELETE FROM production_batches WHERE is_demo = true;
DELETE FROM production_lines WHERE is_demo = true;
DELETE FROM employees WHERE is_demo = true;
DELETE FROM shifts WHERE is_demo = true;
DELETE FROM departments WHERE is_demo = true;

-- ============================================================
-- DEPARTMENTS
-- ============================================================
INSERT INTO departments (name, code, description, is_demo) VALUES
  ('Steelmaking', 'SM', 'Electric arc furnace steelmaking operations', true),
  ('Rolling Mill', 'RM', 'Hot and cold rolling operations', true),
  ('Energy & Utilities', 'EU', 'Power, gas, water, and compressed air supply', true),
  ('Maintenance', 'MT', 'Equipment maintenance and reliability', true),
  ('Quality Control', 'QC', 'Product quality inspection and laboratory', true),
  ('Warehouse & Logistics', 'WH', 'Inventory, spare parts, and material handling', true);

-- ============================================================
-- SHIFTS
-- ============================================================
INSERT INTO shifts (name, start_time, end_time, description, is_demo) VALUES
  ('Morning', '06:00', '14:00', 'Day shift - primary production', true),
  ('Afternoon', '14:00', '22:00', 'Evening shift', true),
  ('Night', '22:00', '06:00', 'Night shift', true);

-- ============================================================
-- EQUIPMENT CATEGORIES
-- ============================================================
INSERT INTO equipment_categories (name, code, description) VALUES
  ('Furnace', 'FUR', 'Electric arc furnaces and ladle furnaces'),
  ('Crane', 'CRN', 'Overhead and gantry cranes'),
  ('Mill Stand', 'MIL', 'Rolling mill stands and drives'),
  ('Pump', 'PMP', 'Cooling water and hydraulic pumps'),
  ('Compressor', 'CMP', 'Air compressors and blowers');

-- ============================================================
-- PRODUCTION LINES
-- ============================================================
INSERT INTO production_lines (name, code, department_id, is_demo) VALUES
  ('EAF Line 1', 'EAF1', (SELECT id FROM departments WHERE code = 'SM'), true),
  ('EAF Line 2', 'EAF2', (SELECT id FROM departments WHERE code = 'SM'), true),
  ('Rolling Line A', 'RLA', (SELECT id FROM departments WHERE code = 'RM'), true),
  ('Rolling Line B', 'RLB', (SELECT id FROM departments WHERE code = 'RM'), true);

-- ============================================================
-- EQUIPMENT
-- ============================================================
INSERT INTO equipment (equipment_code, name, category_id, department_id, production_line_id, status, health_score, operating_hours, is_demo) VALUES
  ('EAF-01', 'Electric Arc Furnace #1',
    (SELECT id FROM equipment_categories WHERE code = 'FUR'),
    (SELECT id FROM departments WHERE code = 'SM'),
    (SELECT id FROM production_lines WHERE code = 'EAF1'),
    'operational', 87, 14250.5, true),
  ('EAF-02', 'Electric Arc Furnace #2',
    (SELECT id FROM equipment_categories WHERE code = 'FUR'),
    (SELECT id FROM departments WHERE code = 'SM'),
    (SELECT id FROM production_lines WHERE code = 'EAF2'),
    'operational', 92, 11830.0, true),
  ('RM-A', 'Rolling Mill Stand A',
    (SELECT id FROM equipment_categories WHERE code = 'MIL'),
    (SELECT id FROM departments WHERE code = 'RM'),
    (SELECT id FROM production_lines WHERE code = 'RLA'),
    'operational', 78, 22100.3, true),
  ('RM-B', 'Rolling Mill Stand B',
    (SELECT id FROM equipment_categories WHERE code = 'MIL'),
    (SELECT id FROM departments WHERE code = 'RM'),
    (SELECT id FROM production_lines WHERE code = 'RLB'),
    'under_maintenance', 65, 19850.7, true),
  ('CRN-01', 'Charging Crane',
    (SELECT id FROM equipment_categories WHERE code = 'CRN'),
    (SELECT id FROM departments WHERE code = 'SM'),
    NULL, 'operational', 90, 30120.0, true),
  ('CRN-02', 'Ladle Crane',
    (SELECT id FROM equipment_categories WHERE code = 'CRN'),
    (SELECT id FROM departments WHERE code = 'SM'),
    NULL, 'idle', 85, 28700.2, true),
  ('PMP-01', 'Cooling Water Pump #1',
    (SELECT id FROM equipment_categories WHERE code = 'PMP'),
    (SELECT id FROM departments WHERE code = 'EU'),
    NULL, 'operational', 95, 45200.8, true),
  ('CMP-01', 'Main Air Compressor',
    (SELECT id FROM equipment_categories WHERE code = 'CMP'),
    (SELECT id FROM departments WHERE code = 'EU'),
    NULL, 'operational', 82, 38900.5, true);

-- ============================================================
-- ENERGY METERS
-- ============================================================
INSERT INTO energy_meters (meter_code, name, energy_type, department_id, unit, is_demo) VALUES
  ('ELEC-SM', 'Steelmaking Electricity', 'electricity',
    (SELECT id FROM departments WHERE code = 'SM'), 'kWh', true),
  ('ELEC-RM', 'Rolling Mill Electricity', 'electricity',
    (SELECT id FROM departments WHERE code = 'RM'), 'kWh', true),
  ('GAS-SM', 'Steelmaking Natural Gas', 'natural_gas',
    (SELECT id FROM departments WHERE code = 'SM'), 'm3', true),
  ('GAS-RM', 'Rolling Furnace Gas', 'natural_gas',
    (SELECT id FROM departments WHERE code = 'RM'), 'm3', true),
  ('WATER-PLANT', 'Plant Water Intake', 'water',
    (SELECT id FROM departments WHERE code = 'EU'), 'm3', true),
  ('AIR-PLANT', 'Compressed Air', 'compressed_air',
    (SELECT id FROM departments WHERE code = 'EU'), 'm3', true);

-- ============================================================
-- WAREHOUSE CATEGORIES
-- ============================================================
INSERT INTO warehouse_categories (name, code, description) VALUES
  ('Spare Parts', 'SP', 'Equipment spare parts and consumables'),
  ('Raw Materials', 'RM', 'Raw materials and inputs'),
  ('Consumables', 'CON', 'Operational consumables');

-- ============================================================
-- WAREHOUSE ITEMS
-- ============================================================
INSERT INTO warehouse_items (item_code, name, category_id, unit, current_stock, min_stock, max_stock, unit_cost, is_demo) VALUES
  ('ELC-001', 'EAF Electrode', (SELECT id FROM warehouse_categories WHERE code = 'SP'), 'pcs', 8, 5, 20, 12500.00, true),
  ('RLF-002', 'Refractory Bricks', (SELECT id FROM warehouse_categories WHERE code = 'SP'), 'pcs', 450, 200, 1000, 85.00, true),
  ('BRG-003', 'Rolling Mill Bearing', (SELECT id FROM warehouse_categories WHERE code = 'SP'), 'pcs', 3, 8, 30, 3200.00, true),
  ('HYD-004', 'Hydraulic Oil', (SELECT id FROM warehouse_categories WHERE code = 'CON'), 'L', 320, 100, 800, 45.00, true),
  ('SCR-005', 'Steel Scrap', (SELECT id FROM warehouse_categories WHERE code = 'RM'), 'tonne', 850, 200, 2000, 320.00, true),
  ('ALY-006', 'Ferroalloy', (SELECT id FROM warehouse_categories WHERE code = 'RM'), 'tonne', 45, 20, 100, 1800.00, true),
  ('COG-007', 'Coke', (SELECT id FROM warehouse_categories WHERE code = 'RM'), 'tonne', 120, 50, 300, 450.00, true),
  ('LME-008', 'Lime', (SELECT id FROM warehouse_categories WHERE code = 'RM'), 'tonne', 60, 30, 150, 120.00, true),
  ('COL-009', 'Cooling Water Treatment', (SELECT id FROM warehouse_categories WHERE code = 'CON'), 'L', 180, 50, 500, 28.00, true),
  ('GSK-010', 'Crane Wire Rope', (SELECT id FROM warehouse_categories WHERE code = 'SP'), 'm', 75, 30, 200, 65.00, true);

-- ============================================================
-- PRODUCTION BATCHES + RECORDS (30 days)
-- ============================================================
DO $$
DECLARE
  v_line record;
  v_day integer;
  v_date date;
  v_batch_id uuid;
  v_shift_id uuid;
  v_shift_name text;
  v_shift_start interval;
  v_output numeric(12,2);
  v_rejected numeric(12,2);
  v_target numeric(12,2);
  v_batch_num text;
  v_heat_num text;
  v_steel_grade text;
  v_grades text[] := ARRAY['Q235B','Q345B','SPHC','SS400','45#','HRB400'];
  v_shift_idx integer;
BEGIN
  FOR v_day IN 0..29 LOOP
    v_date := CURRENT_DATE - v_day;
    FOR v_line IN SELECT id, code FROM production_lines WHERE is_demo = true LOOP
      FOR v_shift_idx IN 0..2 LOOP
        CASE v_shift_idx
          WHEN 0 THEN v_shift_name := 'Morning'; v_shift_start := INTERVAL '6 hours';
          WHEN 1 THEN v_shift_name := 'Afternoon'; v_shift_start := INTERVAL '14 hours';
          ELSE v_shift_name := 'Night'; v_shift_start := INTERVAL '22 hours';
        END CASE;

        SELECT id INTO v_shift_id FROM shifts WHERE name = v_shift_name AND is_demo = true;

        v_output := 80 + (random() * 40);
        v_rejected := v_output * (0.01 + random() * 0.04);
        v_target := 100;
        v_steel_grade := v_grades[1 + (v_day % array_length(v_grades,1))];
        v_batch_num := v_line.code || '-' || to_char(v_date, 'YYMMDD') || '-' || substring(v_shift_name, 1, 1);
        v_heat_num := 'H' || to_char(v_date, 'YYMMDD') || (floor(random()*900)+100)::text;

        INSERT INTO production_batches (batch_number, heat_number, steel_grade, production_line_id, status, start_time, end_time, input_weight_kg, output_weight_kg, rejected_weight_kg, is_demo)
        VALUES (v_batch_num, v_heat_num, v_steel_grade, v_line.id, 'completed',
          v_date + v_shift_start,
          v_date + v_shift_start + INTERVAL '8 hours',
          v_output * 1000 * 1.05, v_output * 1000, v_rejected * 1000, true)
        RETURNING id INTO v_batch_id;

        INSERT INTO production_records (batch_id, production_line_id, shift_id, record_date, steel_grade, output_weight_kg, rejected_weight_kg, target_weight_kg, is_demo)
        VALUES (v_batch_id, v_line.id, v_shift_id, v_date, v_steel_grade, v_output * 1000, v_rejected * 1000, v_target * 1000, true);
      END LOOP;

      INSERT INTO production_targets (production_line_id, target_date, target_weight_kg, is_demo)
      VALUES (v_line.id, v_date, 300000, true)
      ON CONFLICT (production_line_id, target_date) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- ENERGY READINGS (30 days daily per meter)
-- ============================================================
DO $$
DECLARE
  v_meter record;
  v_day integer;
  v_date date;
  v_value numeric(14,3);
  v_base numeric(14,3);
  v_quality reading_quality;
BEGIN
  FOR v_meter IN SELECT id, energy_type, unit FROM energy_meters WHERE is_demo = true LOOP
    CASE v_meter.energy_type
      WHEN 'electricity' THEN v_base := 45000 + (random() * 10000);
      WHEN 'natural_gas' THEN v_base := 3200 + (random() * 800);
      WHEN 'water' THEN v_base := 1800 + (random() * 400);
      WHEN 'compressed_air' THEN v_base := 5200 + (random() * 1200);
      ELSE v_base := 1000;
    END CASE;

    FOR v_day IN 0..29 LOOP
      v_date := CURRENT_DATE - v_day;
      v_value := v_base + (random() * v_base * 0.15) - (v_base * 0.05);
      v_value := GREATEST(v_value, v_base * 0.7);

      v_quality := CASE WHEN random() < 0.05 THEN 'estimated'::reading_quality ELSE 'good'::reading_quality END;

      INSERT INTO energy_readings (meter_id, reading_time, value, unit, quality, is_demo)
      VALUES (v_meter.id, v_date + INTERVAL '12 hours', v_value, v_meter.unit, v_quality, true);

      INSERT INTO energy_consumption_daily (meter_id, consumption_date, total_value, unit, is_demo)
      VALUES (v_meter.id, v_date, v_value, v_meter.unit, true)
      ON CONFLICT (meter_id, consumption_date) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- EQUIPMENT TELEMETRY (last 7 days, hourly, for EAF-01)
-- ============================================================
DO $$
DECLARE
  v_equip uuid;
  v_hour integer;
  v_temp numeric;
  v_vib numeric;
  v_start timestamptz;
BEGIN
  SELECT id INTO v_equip FROM equipment WHERE equipment_code = 'EAF-01';

  FOR v_hour IN 0..167 LOOP
    v_start := now() - (v_hour || ' hours')::interval;
    v_temp := 1450 + (random() * 80) - 20;
    v_vib := 2.5 + (random() * 1.0);

    INSERT INTO equipment_telemetry (equipment_id, reading_time, metric, value, unit, quality, is_demo)
    VALUES (v_equip, v_start, 'temperature', v_temp, 'C', 'good', true);

    INSERT INTO equipment_telemetry (equipment_id, reading_time, metric, value, unit, quality, is_demo)
    VALUES (v_equip, v_start, 'vibration', v_vib, 'mm/s', 'good', true);
  END LOOP;
END $$;

-- ============================================================
-- MAINTENANCE WORK ORDERS
-- ============================================================
INSERT INTO maintenance_work_orders (work_order_number, equipment_id, type, priority, status, description, scheduled_date, completed_date, downtime_hours, cost, is_demo) VALUES
  ('WO-2025-001', (SELECT id FROM equipment WHERE equipment_code = 'RM-B'), 'corrective', 'high', 'in_progress',
    'Replace worn rolling mill bearings on stand B', CURRENT_DATE - 2, NULL, 0, 8500.00, true),
  ('WO-2025-002', (SELECT id FROM equipment WHERE equipment_code = 'EAF-01'), 'preventive', 'medium', 'completed',
    'Scheduled electrode replacement and furnace inspection', CURRENT_DATE - 10, CURRENT_DATE - 8, 6, 12500.00, true),
  ('WO-2025-003', (SELECT id FROM equipment WHERE equipment_code = 'CMP-01'), 'preventive', 'medium', 'completed',
    'Air compressor filter and oil change', CURRENT_DATE - 15, CURRENT_DATE - 14, 4, 1800.00, true),
  ('WO-2025-004', (SELECT id FROM equipment WHERE equipment_code = 'CRN-01'), 'corrective', 'critical', 'open',
    'Crane wire rope fraying - requires immediate replacement', CURRENT_DATE + 1, NULL, 0, 6500.00, true),
  ('WO-2025-005', (SELECT id FROM equipment WHERE equipment_code = 'PMP-01'), 'inspection', 'low', 'completed',
    'Quarterly pump performance inspection', CURRENT_DATE - 20, CURRENT_DATE - 20, 2, 500.00, true),
  ('WO-2025-006', (SELECT id FROM equipment WHERE equipment_code = 'EAF-02'), 'predictive', 'high', 'in_progress',
    'Vibration analysis indicates bearing wear - schedule replacement', CURRENT_DATE - 3, NULL, 0, 4200.00, true),
  ('WO-2025-007', (SELECT id FROM equipment WHERE equipment_code = 'RM-A'), 'preventive', 'medium', 'open',
    'Monthly lubrication and alignment check', CURRENT_DATE + 3, NULL, 0, 0, true),
  ('WO-2025-008', (SELECT id FROM equipment WHERE equipment_code = 'CRN-02'), 'corrective', 'medium', 'completed',
    'Hydraulic system leak repair', CURRENT_DATE - 25, CURRENT_DATE - 24, 8, 3200.00, true),
  ('WO-2025-009', (SELECT id FROM equipment WHERE equipment_code = 'EAF-01'), 'corrective', 'high', 'completed',
    'Cooling water valve replacement', CURRENT_DATE - 30, CURRENT_DATE - 29, 5, 2800.00, true),
  ('WO-2025-010', (SELECT id FROM equipment WHERE equipment_code = 'RM-B'), 'preventive', 'low', 'overdue',
    'Scheduled bearing inspection (overdue)', CURRENT_DATE - 5, NULL, 0, 0, true),
  ('WO-2025-011', (SELECT id FROM equipment WHERE equipment_code = 'CMP-01'), 'inspection', 'low', 'open',
    'Air quality output test', CURRENT_DATE + 5, NULL, 0, 0, true),
  ('WO-2025-012', (SELECT id FROM equipment WHERE equipment_code = 'PMP-01'), 'preventive', 'medium', 'completed',
    'Impeller cleaning and seal replacement', CURRENT_DATE - 40, CURRENT_DATE - 39, 6, 2100.00, true);

-- ============================================================
-- SAFETY INCIDENTS
-- ============================================================
INSERT INTO safety_incidents (incident_number, title, description, severity, status, department_id, incident_date, resolution_date, is_demo) VALUES
  ('SI-2025-001', 'Hot metal splash during tapping', 'Minor splash during EAF tapping operation, no injuries',
    'minor', 'closed', (SELECT id FROM departments WHERE code = 'SM'),
    CURRENT_DATE - 28, CURRENT_DATE - 25, true),
  ('SI-2025-002', 'Crane near-miss event', 'Load swing incident near walkway, no contact',
    'moderate', 'closed', (SELECT id FROM departments WHERE code = 'SM'),
    CURRENT_DATE - 20, CURRENT_DATE - 15, true),
  ('SI-2025-003', 'Hydraulic oil spill', 'Oil leak from rolling mill hydraulic system, contained',
    'moderate', 'investigating', (SELECT id FROM departments WHERE code = 'RM'),
    CURRENT_DATE - 5, NULL, true),
  ('SI-2025-004', 'Furnace refractory failure', 'Refractory lining degradation detected during inspection',
    'serious', 'investigating', (SELECT id FROM departments WHERE code = 'SM'),
    CURRENT_DATE - 3, NULL, true),
  ('SI-2025-005', 'Compressed air line burst', 'Air line fitting failure, no injuries, equipment isolated',
    'minor', 'reported', (SELECT id FROM departments WHERE code = 'EU'),
    CURRENT_DATE - 1, NULL, true);
