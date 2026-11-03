# Database Schema — CHANGLONG INTELLIGENCE

## Tables by Domain

### A. Organization & Identity

#### departments
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, default gen_random_uuid() |
| name | text | NOT NULL, UNIQUE |
| code | text | NOT NULL, UNIQUE |
| description | text | |
| is_active | boolean | NOT NULL, default true |
| is_demo | boolean | NOT NULL, default false |
| created_at | timestamptz | default now() |
| updated_at | timestamptz | default now() |

#### profiles
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, FK auth.users(id) ON DELETE CASCADE |
| full_name | text | |
| email | text | |
| phone | text | |
| department_id | uuid | FK departments(id) ON DELETE SET NULL |
| role | user_role | NOT NULL, default 'viewer' |
| language | text | NOT NULL, default 'en' |
| is_active | boolean | NOT NULL, default true |
| created_at, updated_at | timestamptz | |

#### shifts
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| name | text | NOT NULL |
| start_time | time | NOT NULL |
| end_time | time | NOT NULL |
| description | text | |
| is_active | boolean | default true |
| is_demo | boolean | default false |

#### employees
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| employee_number | text | NOT NULL, UNIQUE |
| full_name | text | NOT NULL |
| department_id | uuid | FK departments |
| position | text | |
| shift_id | uuid | FK shifts |
| hire_date | date | |
| status | employee_status | default 'active' |
| is_demo | boolean | default false |

### B. Production

#### production_lines
`id, name, code (UNIQUE), department_id (FK), is_active, is_demo, timestamps`

#### production_batches
`id, batch_number (UNIQUE), heat_number, steel_grade, production_line_id (FK), status (batch_status), start_time, end_time, input_weight_kg, output_weight_kg, rejected_weight_kg, is_demo, timestamps`

#### production_records
`id, batch_id (FK), production_line_id (FK), shift_id (FK), record_date, steel_grade, output_weight_kg, rejected_weight_kg, target_weight_kg, operator_id (FK profiles), notes, is_demo, timestamps`

#### production_targets
`id, production_line_id (FK), target_date, target_weight_kg, is_demo, timestamps — UNIQUE(production_line_id, target_date)`

### C. Energy

#### energy_meters
`id, meter_code (UNIQUE), name, energy_type (enum), department_id (FK), equipment_id, unit, is_active, is_demo, timestamps`

#### energy_readings
`id, meter_id (FK), reading_time, value (numeric 14,3), unit, quality (reading_quality), is_demo, created_at`

#### energy_consumption_daily
`id, meter_id (FK), consumption_date, total_value, unit, is_demo, created_at — UNIQUE(meter_id, consumption_date)`

### D. Equipment

#### equipment_categories
`id, name, code (UNIQUE), description, timestamps`

#### equipment
`id, equipment_code (UNIQUE), name, category_id (FK), department_id (FK), production_line_id (FK), status (equipment_status), health_score (CHECK 0-100), operating_hours, is_demo, timestamps`

#### equipment_telemetry
`id, equipment_id (FK), reading_time, metric, value, unit, quality, is_demo, created_at`

### E. Maintenance

#### maintenance_work_orders
`id, work_order_number (UNIQUE), equipment_id (FK), type (maintenance_type), priority (priority_level), status (work_order_status), assigned_to (FK profiles), description, scheduled_date, completed_date, downtime_hours, cost, is_demo, timestamps`

#### maintenance_schedules
`id, equipment_id (FK), frequency_days (CHECK >0), next_due_date, procedure, is_active, is_demo, timestamps`

### F. Warehouse

#### warehouse_categories
`id, name, code (UNIQUE), description, timestamps`

#### warehouse_items
`id, item_code (UNIQUE), name, category_id (FK), unit, current_stock, min_stock, max_stock, unit_cost, is_demo, timestamps`

#### inventory_movements
`id, item_id (FK), movement_type (enum), quantity, reference, performed_by (FK profiles), is_demo, created_at`

#### suppliers
`id, name, code (UNIQUE), contact_name, contact_phone, contact_email, address, is_active, is_demo, timestamps`

#### purchase_requests
`id, request_number (UNIQUE), item_id (FK), supplier_id (FK), quantity, unit, status, requested_by (FK profiles), is_demo, timestamps`

#### warehouse_locations
`id, name, code (UNIQUE), description, is_active, timestamps`

#### raw_material_consumption
`id, production_line_id (FK), material_type, consumption_date, quantity, unit, is_demo, created_at`

### G. Quality Control

#### quality_standards
`id, name, steel_grade, parameter, min_value, max_value, unit, is_active, timestamps`

#### quality_inspections
`id, inspection_number (UNIQUE), batch_id (FK), steel_grade, inspector_id (FK employees), inspection_date, result (quality_result), notes, is_demo, timestamps`

#### quality_measurements
`id, inspection_id (FK), parameter, value, unit, min_value, max_value, result (quality_result), is_demo, created_at`

#### quality_defects
`id, inspection_id (FK), defect_type, severity (defect_severity), description, count, is_demo, created_at`

### H. Safety

#### safety_incidents
`id, incident_number (UNIQUE), title, description, severity (incident_severity), status (incident_status), department_id (FK), reported_by (FK profiles), incident_date, resolution_date, is_demo, timestamps`

#### safety_inspections
`id, inspection_number, area, inspector_id (FK employees), inspection_date, result, findings, is_demo, created_at`

#### safety_observations
`id, observer_id (FK employees), observation_date, category, description, action_taken, is_demo, created_at`

#### corrective_actions
`id, work_order_id (FK), incident_id (FK safety_incidents), description, completed_date, is_demo, created_at`

### I. Environmental

#### environmental_readings
`id, reading_type (environmental_reading_type), reading_time, value, unit, department_id (FK), equipment_id (FK), quality (reading_quality), is_demo, created_at`

#### emission_records
`id, emission_type (emission_type), emission_date, value, unit, source_type (emission_source), department_id (FK), is_demo, created_at`

#### waste_records
`id, waste_type, waste_date, quantity, unit, disposal_method, department_id (FK), is_demo, created_at`

#### environmental_targets
`id, target_type, target_date, target_value, unit, is_demo, created_at`

### J. Workforce

#### attendance_records
`id, employee_id (FK), record_date, status (attendance_status), hours_worked, is_demo, created_at`

#### qualifications
`id, employee_id (FK), name, issued_date, expiry_date, issuer, is_demo, created_at`

#### training_records
`id, employee_id (FK), course_name, completion_date, status (training_status), is_demo, created_at`

### K. Notifications & Audit

#### notifications
`id, user_id (FK profiles), title, message, severity (notification_severity), category, is_read, created_at`

#### notification_preferences
`id, user_id (FK profiles), category, severity (notification_severity), enabled, is_demo, created_at`

#### audit_logs
`id, user_id (FK profiles), action, entity_type, entity_id, old_values (jsonb), new_values (jsonb), ip_address, created_at`

### L. Supplementary (from migration 0008)

#### production_events
`id, production_line_id (FK), batch_id (FK), event_type, event_time, duration_minutes, description, is_demo, created_at`

#### equipment_status_history
`id, equipment_id (FK), status (equipment_status), start_time, end_time, duration_hours, reason, is_demo, created_at`

#### energy_targets
`id, energy_type, target_date, target_value, unit, is_demo, created_at`

#### energy_cost_records
`id, energy_type, cost_date, unit_price, total_cost, is_demo, created_at`

## Database Functions

### handle_new_user()
- Trigger on auth.users AFTER INSERT — auto-creates a profile row.
- SECURITY DEFINER, search_path = public, EXECUTE revoked from anon/authenticated.

### set_updated_at()
- Trigger on all tables with updated_at — sets `updated_at = now()` on UPDATE.
- search_path = public.

### record_inventory_movement(p_item_id, p_movement_type, p_quantity, p_reference, p_performed_by, p_is_demo)
- SECURITY DEFINER, search_path = public.
- Atomically adjusts warehouse_items.current_stock and logs an inventory_movements row.
- Prevents negative stock (raises exception on insufficient stock).
- EXECUTE granted to authenticated, service_role only.

## Enum Types

- `user_role`: admin, plant_director, manager, production_manager, engineer, energy_manager, maintenance_manager, safety_officer, warehouse_manager, operator, viewer
- `employee_status`: active, on_leave, inactive
- `batch_status`: planned, in_progress, completed, on_hold, cancelled
- `energy_type`: electricity, natural_gas, water, steam, compressed_air
- `reading_quality`: good, suspect, estimated, invalid
- `equipment_status`: operational, under_maintenance, idle, fault, decommissioned
- `maintenance_type`: preventive, corrective, predictive, inspection
- `priority_level`: low, medium, high, critical
- `work_order_status`: open, in_progress, completed, cancelled, overdue
- `movement_type`: incoming, outgoing, adjustment
- `incident_severity`: minor, moderate, serious, critical
- `incident_status`: reported, investigating, resolved, closed
- `notification_severity`: info, warning, critical
- `quality_result`: pass, fail, conditional
- `defect_severity`: minor, major, critical
- `environmental_reading_type`: air_quality, water_quality, noise, dust
- `emission_type`: co2, sox, nox, pm
- `emission_source`: measured, estimated
- `attendance_status`: present, absent, late, leave
- `training_status`: completed, in_progress, scheduled
