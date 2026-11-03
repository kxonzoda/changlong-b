/*
# Demo seed for final spec completion tables (migration 0014 tables)

Data for: energy_sources, quality_parameters, quality_batches, laboratory_results,
production_shifts, equipment_events, equipment_operating_hours, maintenance_history,
stock_transactions, environmental_alerts, workforce_assignments, employee_shifts.

All is_demo = true. Idempotent.
*/

ALTER TABLE warehouse_locations ADD COLUMN IF NOT EXISTS is_demo boolean NOT NULL DEFAULT false;
ALTER TABLE quality_parameters ADD COLUMN IF NOT EXISTS is_demo boolean NOT NULL DEFAULT false;
ALTER TABLE energy_sources ADD COLUMN IF NOT EXISTS is_demo boolean NOT NULL DEFAULT false;

DO $$
DECLARE
  v_furnace uuid; v_mill uuid; v_crane uuid; v_pump uuid;
  v_line1 uuid; v_line2 uuid; v_line3 uuid;
  v_shift1 uuid; v_shift2 uuid; v_shift3 uuid;
  v_wo1 uuid; v_wo2 uuid; v_wo3 uuid;
  v_emp1 uuid; v_emp2 uuid; v_emp3 uuid;
  v_dept_prod uuid; v_dept_main uuid;
  v_loc1 uuid; v_loc2 uuid;
  v_item1 uuid; v_item2 uuid;
  v_batch1 uuid; v_batch2 uuid; v_batch3 uuid;
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM energy_sources WHERE is_demo = true;
  IF v_count > 0 THEN RETURN; END IF;

  SELECT id INTO v_furnace FROM equipment WHERE equipment_code = 'EAF-01' AND is_demo LIMIT 1;
  SELECT id INTO v_mill FROM equipment WHERE equipment_code = 'RM-A' AND is_demo LIMIT 1;
  SELECT id INTO v_crane FROM equipment WHERE equipment_code = 'CRN-01' AND is_demo LIMIT 1;
  SELECT id INTO v_pump FROM equipment WHERE equipment_code = 'PMP-01' AND is_demo LIMIT 1;

  SELECT id INTO v_line1 FROM production_lines WHERE code = 'EAF1' AND is_demo LIMIT 1;
  SELECT id INTO v_line2 FROM production_lines WHERE code = 'EAF2' AND is_demo LIMIT 1;
  SELECT id INTO v_line3 FROM production_lines WHERE code = 'RLA' AND is_demo LIMIT 1;

  SELECT id INTO v_shift1 FROM shifts WHERE name = 'Morning' AND is_demo LIMIT 1;
  SELECT id INTO v_shift2 FROM shifts WHERE name = 'Afternoon' AND is_demo LIMIT 1;
  SELECT id INTO v_shift3 FROM shifts WHERE name = 'Night' AND is_demo LIMIT 1;

  SELECT id INTO v_wo1 FROM maintenance_work_orders WHERE is_demo ORDER BY created_at LIMIT 1;
  SELECT id INTO v_wo2 FROM maintenance_work_orders WHERE is_demo ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_wo3 FROM maintenance_work_orders WHERE is_demo ORDER BY created_at OFFSET 2 LIMIT 1;

  SELECT id INTO v_emp1 FROM employees WHERE is_demo ORDER BY full_name LIMIT 1;
  SELECT id INTO v_emp2 FROM employees WHERE is_demo ORDER BY full_name OFFSET 1 LIMIT 1;
  SELECT id INTO v_emp3 FROM employees WHERE is_demo ORDER BY full_name OFFSET 2 LIMIT 1;

  SELECT id INTO v_dept_prod FROM departments WHERE code = 'PROD' AND is_demo LIMIT 1;
  SELECT id INTO v_dept_main FROM departments WHERE code = 'MAIN' AND is_demo LIMIT 1;

  SELECT id INTO v_loc1 FROM warehouse_locations ORDER BY code LIMIT 1;
  SELECT id INTO v_loc2 FROM warehouse_locations ORDER BY code OFFSET 1 LIMIT 1;

  SELECT id INTO v_item1 FROM warehouse_items WHERE is_demo ORDER BY item_code LIMIT 1;
  SELECT id INTO v_item2 FROM warehouse_items WHERE is_demo ORDER BY item_code OFFSET 1 LIMIT 1;

  SELECT id INTO v_batch1 FROM production_batches WHERE is_demo ORDER BY batch_number LIMIT 1;
  SELECT id INTO v_batch2 FROM production_batches WHERE is_demo ORDER BY batch_number OFFSET 1 LIMIT 1;
  SELECT id INTO v_batch3 FROM production_batches WHERE is_demo ORDER BY batch_number OFFSET 2 LIMIT 1;

  -- energy_sources
  INSERT INTO energy_sources (name, source_type, supplier, unit, conversion_factor_kwh, co2_emission_factor, co2_emission_unit, is_active, is_demo) VALUES
    ('Grid Electricity', 'electricity', 'State Grid Corporation', 'kWh', 1.0, 0.581, 'kg/kWh', true, true),
    ('Natural Gas Supply', 'natural_gas', 'City Gas Co.', 'm3', 9.5, 2.16, 'kg/m3', true, true),
    ('Municipal Water', 'water', 'City Water Authority', 'm3', 0.0, 0.0, 'kg/m3', true, true),
    ('Compressed Air', 'compressed_air', 'Internal Generation', 'm3', 0.13, 0.0, 'kg/m3', true, true);

  -- quality_parameters
  INSERT INTO quality_parameters (name, category, unit, is_active, is_demo) VALUES
    ('Carbon Content', 'chemical', '%', true, true),
    ('Manganese Content', 'chemical', '%', true, true),
    ('Tensile Strength', 'mechanical', 'MPa', true, true),
    ('Yield Strength', 'mechanical', 'MPa', true, true),
    ('Thickness Tolerance', 'dimensional', 'mm', true, true),
    ('Surface Defect Count', 'surface', 'count', true, true);

  -- quality_batches
  INSERT INTO quality_batches (batch_id, quality_status, overall_grade, inspection_count, defect_count, completed_at, is_demo) VALUES
    (v_batch1, 'passed', 'A', 3, 0, CURRENT_DATE - 5, true),
    (v_batch2, 'passed', 'B', 2, 1, CURRENT_DATE - 3, true),
    (v_batch3, 'conditional', 'C', 2, 2, CURRENT_DATE - 1, true),
    (v_batch1, 'passed', 'A', 1, 0, CURRENT_DATE - 7, true),
    (v_batch2, 'failed', 'reject', 1, 3, CURRENT_DATE - 8, true);

  -- laboratory_results
  INSERT INTO laboratory_results (batch_id, test_name, test_method, result_value, unit, specification_min, specification_max, pass_fail, lab_technician, is_demo) VALUES
    (v_batch1, 'Carbon Content', 'Combustion Analysis', 0.22, '%', 0.18, 0.25, 'pass', 'Lab Tech A', true),
    (v_batch1, 'Tensile Strength', 'ASTM E8', 450, 'MPa', 400, 550, 'pass', 'Lab Tech B', true),
    (v_batch2, 'Carbon Content', 'Combustion Analysis', 0.28, '%', 0.18, 0.25, 'fail', 'Lab Tech A', true),
    (v_batch2, 'Manganese Content', 'Spectrometry', 1.35, '%', 0.80, 1.50, 'pass', 'Lab Tech C', true),
    (v_batch3, 'Yield Strength', 'ASTM E8', 320, 'MPa', 300, 450, 'conditional', 'Lab Tech B', true),
    (v_batch3, 'Thickness Tolerance', 'Ultrasonic', 12.1, 'mm', 11.9, 12.1, 'conditional', 'Lab Tech A', true);

  -- production_shifts (3 lines x 3 shifts)
  INSERT INTO production_shifts (production_line_id, shift_id, record_date, output_weight_kg, rejected_weight_kg, target_weight_kg, is_demo) VALUES
    (v_line1, v_shift1, CURRENT_DATE - 1, 8500, 120, 9000, true),
    (v_line1, v_shift2, CURRENT_DATE - 1, 7800, 95, 9000, true),
    (v_line1, v_shift3, CURRENT_DATE - 1, 6200, 180, 8000, true),
    (v_line2, v_shift1, CURRENT_DATE - 1, 5200, 60, 6000, true),
    (v_line2, v_shift2, CURRENT_DATE - 1, 4800, 45, 6000, true),
    (v_line2, v_shift3, CURRENT_DATE - 1, 4100, 85, 5000, true),
    (v_line3, v_shift1, CURRENT_DATE - 1, 3800, 30, 4000, true),
    (v_line3, v_shift2, CURRENT_DATE - 1, 3500, 25, 4000, true),
    (v_line3, v_shift3, CURRENT_DATE - 1, 2900, 55, 3500, true);

  -- equipment_events
  INSERT INTO equipment_events (equipment_id, event_type, event_time, description, old_status, new_status, is_demo) VALUES
    (v_furnace, 'startup', CURRENT_DATE - 1, 'Furnace startup for morning shift', 'idle', 'operational', true),
    (v_mill, 'fault', CURRENT_DATE - 2, 'Vibration alarm triggered on rolling mill', 'operational', 'fault', true),
    (v_mill, 'maintenance_start', CURRENT_DATE - 2, 'Corrective maintenance initiated', 'fault', 'under_maintenance', true),
    (v_mill, 'maintenance_end', CURRENT_DATE - 1, 'Maintenance completed, back online', 'under_maintenance', 'operational', true),
    (v_crane, 'shutdown', CURRENT_DATE - 3, 'Scheduled shutdown for inspection', 'operational', 'idle', true),
    (v_pump, 'status_change', CURRENT_DATE - 1, 'Pump status updated after maintenance', 'under_maintenance', 'operational', true);

  -- equipment_operating_hours (8 equipment x 7 days)
  INSERT INTO equipment_operating_hours (equipment_id, record_date, operating_hours, idle_hours, downtime_hours, is_demo)
  SELECT e.id, CURRENT_DATE - d, 20 + (random() * 4), 2 + (random() * 2), random() * 2, true
  FROM equipment e CROSS JOIN generate_series(0, 6) AS d
  WHERE e.is_demo;

  -- maintenance_history
  INSERT INTO maintenance_history (work_order_id, equipment_id, technician, completion_notes, parts_used, labor_hours, is_demo) VALUES
    (v_wo1, v_furnace, 'Tech Zhang', 'Replaced refractory lining section, tested thermal integrity', 'Refractory bricks x50, mortar x5', 6.5, true),
    (v_wo2, v_mill, 'Tech Li', 'Replaced bearings and lubricated all joints', 'Bearings x4, grease x2', 4.0, true),
    (v_wo3, v_crane, 'Tech Wang', 'Cable tension adjusted, visual inspection completed', 'None required', 2.5, true);

  -- stock_transactions
  INSERT INTO stock_transactions (item_id, transaction_type, quantity, unit, from_location_id, to_location_id, reference_number, is_demo) VALUES
    (v_item1, 'receipt', 200, 'pcs', NULL, v_loc1, 'PO-2026-001', true),
    (v_item1, 'issue', 45, 'pcs', v_loc1, NULL, 'WO-2026-001', true),
    (v_item2, 'receipt', 100, 'pcs', NULL, v_loc2, 'PO-2026-002', true),
    (v_item2, 'transfer', 30, 'pcs', v_loc2, v_loc1, 'TR-2026-001', true),
    (v_item1, 'adjustment', -5, 'pcs', v_loc1, NULL, 'ADJ-2026-001', true),
    (v_item2, 'return', 10, 'pcs', NULL, v_loc2, 'RET-2026-001', true);

  -- environmental_alerts
  INSERT INTO environmental_alerts (alert_type, severity, reading_type, threshold_value, actual_value, unit, department_id, triggered_at, resolved_at, resolution_notes, is_demo) VALUES
    ('threshold_exceeded', 'warning', 'dust', 50, 68, 'ug/m3', v_dept_prod, CURRENT_DATE - 3, CURRENT_DATE - 2, 'Dust suppression system activated', true),
    ('threshold_exceeded', 'critical', 'noise', 85, 92, 'dB', v_dept_prod, CURRENT_DATE - 5, NULL, NULL, true),
    ('threshold_exceeded', 'warning', 'air_quality', 100, 115, 'AQI', v_dept_main, CURRENT_DATE - 7, CURRENT_DATE - 6, 'Ventilation increased', true);

  -- workforce_assignments
  INSERT INTO workforce_assignments (employee_id, department_id, production_line_id, role_title, start_date, is_active, is_demo) VALUES
    (v_emp1, v_dept_prod, v_line1, 'Furnace Operator', CURRENT_DATE - 90, true, true),
    (v_emp2, v_dept_prod, v_line2, 'Rolling Mill Operator', CURRENT_DATE - 120, true, true),
    (v_emp3, v_dept_main, NULL, 'Maintenance Technician', CURRENT_DATE - 60, true, true),
    (v_emp1, v_dept_prod, NULL, 'Shift Supervisor', CURRENT_DATE - 180, false, true),
    (v_emp2, v_dept_prod, v_line3, 'Line Operator', CURRENT_DATE - 200, false, true),
    (v_emp3, v_dept_main, NULL, 'Inspector', CURRENT_DATE - 30, false, true);

  -- employee_shifts
  INSERT INTO employee_shifts (employee_id, shift_id, effective_date, is_active, is_demo) VALUES
    (v_emp1, v_shift1, CURRENT_DATE - 30, true, true),
    (v_emp2, v_shift2, CURRENT_DATE - 30, true, true),
    (v_emp3, v_shift3, CURRENT_DATE - 30, true, true),
    (v_emp1, v_shift3, CURRENT_DATE - 60, false, true),
    (v_emp2, v_shift1, CURRENT_DATE - 60, false, true),
    (v_emp3, v_shift2, CURRENT_DATE - 90, false, true);
END $$;
