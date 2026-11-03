/*
# Demo seed data for extended tables (migration 0011)

1. New Data
- equipment_components: 8 components across 4 equipment
- maintenance_procedures: 5 procedures
- maintenance_parts: 6 parts across work orders
- risk_assessments: 4 assessments
- safety_training_records: 6 training records
- water_usage_records: 30 days of data
- system_events: 5 events
- energy_anomalies: 4 anomalies

All records marked is_demo = true.
*/

DO $$
DECLARE
  v_furnace uuid;
  v_mill uuid;
  v_crane uuid;
  v_pump uuid;
  v_wo1 uuid;
  v_wo2 uuid;
  v_emp1 uuid;
  v_emp2 uuid;
  v_meter uuid;
  v_dept uuid;
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM equipment_components WHERE is_demo = true;
  IF v_count > 0 THEN RETURN; END IF;

  SELECT id INTO v_furnace FROM equipment WHERE equipment_code = 'EAF-01' AND is_demo LIMIT 1;
  SELECT id INTO v_mill FROM equipment WHERE equipment_code = 'RM-A' AND is_demo LIMIT 1;
  SELECT id INTO v_crane FROM equipment WHERE equipment_code = 'CRN-01' AND is_demo LIMIT 1;
  SELECT id INTO v_pump FROM equipment WHERE equipment_code = 'PMP-01' AND is_demo LIMIT 1;

  INSERT INTO equipment_components (equipment_id, name, component_code, serial_number, installed_date, status, is_demo) VALUES
    (v_furnace, 'Primary Electrode', 'CMP-EAF1-EL', 'SN-EL-2023', '2023-06-15', 'operational', true),
    (v_furnace, 'Refractory Lining', 'CMP-EAF1-RL', 'SN-RL-2023', '2023-06-15', 'operational', true),
    (v_mill, 'Rolling Motor A', 'CMP-RMA-MA', 'SN-MA-2023', '2023-03-10', 'operational', true),
    (v_mill, 'Rolling Motor B', 'CMP-RMA-MB', 'SN-MB-2023', '2023-03-10', 'operational', true),
    (v_crane, 'Main Hoist Cable', 'CMP-CRN1-HC', 'SN-HC-2024', '2024-01-20', 'operational', true),
    (v_crane, 'Control Panel', 'CMP-CRN1-CP', 'SN-CP-2024', '2024-01-20', 'operational', true),
    (v_pump, 'Drive Motor', 'CMP-PMP1-DM', 'SN-DM-2023', '2023-09-05', 'operational', true),
    (v_pump, 'Impeller Assembly', 'CMP-PMP1-IA', 'SN-IA-2023', '2023-09-05', 'operational', true);

  INSERT INTO maintenance_procedures (name, type, description, estimated_duration_hours, is_active) VALUES
    ('Furnace Refractory Inspection', 'preventive', 'Visual and ultrasonic inspection of refractory lining integrity', 4.0, true),
    ('Rolling Mill Bearing Lubrication', 'preventive', 'Lubricate all bearings on rolling mill per OEM schedule', 2.5, true),
    ('Crane Cable Tension Check', 'inspection', 'Verify cable tension and inspect for wear', 1.5, true),
    ('Conveyor Belt Alignment', 'corrective', 'Realign conveyor belt and check tracking', 2.0, true),
    ('Motor Vibration Analysis', 'predictive', 'Vibration spectrum analysis on all motors for early fault detection', 3.0, true);

  SELECT id INTO v_wo1 FROM maintenance_work_orders WHERE is_demo ORDER BY created_at LIMIT 1;
  SELECT id INTO v_wo2 FROM maintenance_work_orders WHERE is_demo ORDER BY created_at OFFSET 1 LIMIT 1;

  INSERT INTO maintenance_parts (work_order_id, part_name, quantity, unit_cost, is_demo) VALUES
    (v_wo1, 'Refractory Brick Type A', 50, 25.00, true),
    (v_wo1, 'Mortar Mix', 5, 12.50, true),
    (v_wo2, 'Bearing 6204-2RS', 4, 18.75, true),
    (v_wo2, 'Lithium Grease Tube', 2, 8.00, true),
    (v_wo2, 'Seal Kit', 1, 45.00, true),
    (v_wo1, 'Gasket Set', 1, 15.00, true);

  SELECT id INTO v_dept FROM departments WHERE code = 'PROD' AND is_demo LIMIT 1;
  INSERT INTO risk_assessments (area, hazard_description, likelihood, severity, risk_score, mitigation_plan, assessment_date, next_review_date, is_demo) VALUES
    ('Furnace Area', 'High-temperature exposure near furnace tapping zone', 'medium', 'critical', 75, 'Install heat shielding, enforce PPE zone, add cooling stations', CURRENT_DATE - 15, CURRENT_DATE + 90, true),
    ('Rolling Mill Floor', 'Pinch points on rolling mill rollers', 'medium', 'high', 60, 'Install physical guards, safety training, lockout/tagout procedure', CURRENT_DATE - 10, CURRENT_DATE + 120, true),
    ('Crane Operations', 'Overhead load hazards in crane operating areas', 'low', 'high', 40, 'Mark exclusion zones, add warning lights, require spotter for heavy lifts', CURRENT_DATE - 7, CURRENT_DATE + 60, true),
    ('Conveyor Belt', 'Entanglement risk at conveyor transfer points', 'low', 'medium', 30, 'Install guard rails, emergency stop cables at 10m intervals', CURRENT_DATE - 5, CURRENT_DATE + 90, true);

  SELECT id INTO v_emp1 FROM employees WHERE is_demo ORDER BY full_name LIMIT 1;
  SELECT id INTO v_emp2 FROM employees WHERE is_demo ORDER BY full_name OFFSET 1 LIMIT 1;

  INSERT INTO safety_training_records (employee_id, course_name, trainer, training_date, completion_status, expiry_date, is_demo) VALUES
    (v_emp1, 'Hot Work Safety Certification', 'Safety Office', CURRENT_DATE - 20, 'completed', CURRENT_DATE + 345, true),
    (v_emp1, 'Lockout/Tagout Training', 'Safety Office', CURRENT_DATE - 10, 'completed', CURRENT_DATE + 355, true),
    (v_emp1, 'Emergency Response Procedures', 'Safety Office', CURRENT_DATE - 5, 'completed', CURRENT_DATE + 360, true),
    (v_emp2, 'Confined Space Entry', 'Safety Office', CURRENT_DATE - 15, 'completed', CURRENT_DATE + 350, true),
    (v_emp2, 'Fall Protection Training', 'Safety Office', CURRENT_DATE - 3, 'in_progress', NULL, true),
    (v_emp2, 'Hazardous Materials Handling', 'Safety Office', CURRENT_DATE + 7, 'scheduled', NULL, true);

  FOR i IN 0..29 LOOP
    INSERT INTO water_usage_records (department_id, usage_date, source, intake_volume, discharge_volume, unit, recycling_rate, is_demo)
    VALUES (v_dept, CURRENT_DATE - i, 'Municipal Supply', 450 + (random() * 100), 380 + (random() * 80), 'm3', 0.15 + (random() * 0.1), true);
  END LOOP;

  INSERT INTO system_events (event_type, severity, message, source, metadata) VALUES
    ('system_startup', 'info', 'CHANGLONG INTELLIGENCE platform started', 'system', jsonb_build_object('version', '1.0.0')),
    ('config_change', 'warning', 'Energy target threshold updated for electricity meters', 'admin', jsonb_build_object('entity', 'energy_targets')),
    ('alert', 'critical', 'Low stock alert triggered for bearing inventory', 'warehouse', jsonb_build_object('item', 'BRG-6204')),
    ('maintenance_overdue', 'warning', 'Preventive maintenance overdue for Furnace #1', 'maintenance', jsonb_build_object('equipment', 'EAF-01')),
    ('data_sync', 'info', 'Daily demo data generation completed', 'seed', jsonb_build_object('records_generated', 360));

  SELECT id INTO v_meter FROM energy_meters WHERE energy_type = 'electricity' AND is_demo LIMIT 1;
  INSERT INTO energy_anomalies (meter_id, anomaly_date, detected_value, expected_value, deviation_pct, anomaly_type, description, is_resolved, is_demo) VALUES
    (v_meter, CURRENT_DATE - 5, 1850, 1200, 54.2, 'peak', 'Daily electricity consumption 54% above expected baseline', false, true),
    (v_meter, CURRENT_DATE - 12, 980, 1200, -18.3, 'dip', 'Consumption dropped 18% below expected — possible meter issue', true, true),
    (v_meter, CURRENT_DATE - 18, 2100, 1200, 75.0, 'usage_spike', 'Major spike detected during evening shift', false, true),
    (NULL, CURRENT_DATE - 25, 0, 0, 0, 'meter_fault', 'Meter reported invalid reading quality flag', true, true);
END $$;
