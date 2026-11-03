# Industrial Data Model

CHANGLONG INTELLIGENCE models a metallurgical/steel manufacturing plant across 11 operational domains. The schema is designed for real-time telemetry, historical analytics, and AI-driven insights.

## Domains

1. [Organization](#1-organization)
2. [Production](#2-production)
3. [Energy](#3-energy)
4. [Equipment](#4-equipment)
5. [Maintenance](#5-maintenance)
6. [Quality Control](#6-quality-control)
7. [Safety](#7-safety)
8. [Warehouse](#8-warehouse)
9. [Environmental](#9-environmental)
10. [Workforce](#10-workforce)
11. [Notifications & Audit](#11-notifications--audit)

---

## 1. Organization

Core organizational structure — departments, user profiles, shifts, and employees.

### departments
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | Department name |
| code | text UNIQUE | Short code (e.g., PROD, MAINT) |
| description | text | |
| is_active | boolean | Soft delete |
| is_demo | boolean | Demo data flag |
| created_at, updated_at | timestamptz | |

### profiles
Linked 1:1 to `auth.users` via a trigger (`handle_new_user`). Auto-created on signup with default role `viewer`.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK, FK → auth.users | |
| full_name | text | |
| email | text | |
| phone | text | |
| department_id | uuid FK → departments | |
| role | user_role enum | One of 11 roles |
| language | text | Default 'en' |
| is_active | boolean | |
| created_at, updated_at | timestamptz | |

### shifts
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | e.g., "Morning Shift" |
| start_time | time | |
| end_time | time | |
| description | text | |
| is_active | boolean | |
| is_demo | boolean | |

### employees
Plant personnel records (separate from auth profiles — represents all workers, not just system users).

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| employee_number | text UNIQUE | HR employee ID |
| full_name | text | |
| department_id | uuid FK | |
| position | text | Job title |
| shift_id | uuid FK | |
| hire_date | date | |
| status | employee_status enum | active, on_leave, inactive |
| is_demo | boolean | |

---

## 2. Production

Production lines, batches, daily records, targets, and events.

### production_lines
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | e.g., "Hot Rolling Line 1" |
| code | text UNIQUE | |
| department_id | uuid FK | |
| is_active, is_demo | boolean | |

### production_batches
Represents a heat/ladle of steel — the core production unit in metallurgy.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| batch_number | text UNIQUE | |
| heat_number | text | Furnace heat number |
| steel_grade | text | e.g., "Q235B", "SS400" |
| production_line_id | uuid FK | |
| status | batch_status enum | planned, in_progress, completed, on_hold, cancelled |
| start_time, end_time | timestamptz | |
| input_weight_kg | numeric | Raw material input |
| output_weight_kg | numeric | Finished output |
| rejected_weight_kg | numeric | Scrap/rejected |
| is_demo | boolean | |

### production_records
Daily aggregated production output per line/shift.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| batch_id | uuid FK | Optional link to batch |
| production_line_id | uuid FK | |
| shift_id | uuid FK | |
| record_date | date | |
| steel_grade | text | |
| output_weight_kg | numeric | Daily output |
| rejected_weight_kg | numeric | |
| target_weight_kg | numeric | Daily target |
| operator_id | uuid FK → employees | |
| notes | text | |
| is_demo | boolean | |

### production_targets
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| production_line_id | uuid FK | |
| target_date | date | |
| target_weight_kg | numeric | |
| is_demo | boolean | |

### production_events
Production events (downtime, grade change, delay, etc.).

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| production_line_id | uuid FK | |
| batch_id | uuid FK | |
| event_type | text | downtime, grade_change, delay, startup, shutdown |
| event_time | timestamptz | |
| duration_minutes | numeric | |
| description | text | |
| is_demo | boolean | |

---

## 3. Energy

Energy meters, raw readings, daily consumption aggregation, targets, and costs.

### energy_meters
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| meter_code | text UNIQUE | |
| name | text | |
| energy_type | energy_type enum | electricity, natural_gas, water, steam, compressed_air |
| department_id | uuid FK | |
| equipment_id | uuid FK → equipment | |
| unit | text | kWh, m³, kg, etc. |
| is_active, is_demo | boolean | |

### energy_readings
Raw meter readings (high-frequency).

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| meter_id | uuid FK | |
| reading_time | timestamptz | |
| value | numeric | |
| unit | text | |
| quality | reading_quality enum | good, suspect, estimated, invalid |
| is_demo | boolean | |

### energy_consumption_daily
Pre-aggregated daily consumption per meter for fast dashboard queries.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| meter_id | uuid FK | |
| consumption_date | date | |
| total_value | numeric | Sum of readings for the day |
| unit | text | |
| is_demo | boolean | |

### energy_targets
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| energy_type | energy_type enum | |
| target_date | date | |
| target_value | numeric | |
| unit | text | |
| is_demo | boolean | |

### energy_cost_records
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| energy_type | energy_type enum | |
| cost_date | date | |
| unit_price | numeric | Price per unit |
| total_cost | numeric | |
| is_demo | boolean | |

---

## 4. Equipment

Equipment categories, units, real-time telemetry, and status history.

### equipment_categories
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | e.g., "Furnace", "Rolling Mill", "Crane" |
| code | text UNIQUE | |
| description | text | |

### equipment
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| equipment_code | text UNIQUE | |
| name | text | |
| category_id | uuid FK | |
| department_id | uuid FK | |
| production_line_id | uuid FK | |
| status | equipment_status enum | operational, under_maintenance, idle, fault, decommissioned |
| health_score | integer | 0–100, computed from telemetry |
| operating_hours | numeric | Cumulative |
| is_demo | boolean | |

### equipment_telemetry
IoT sensor readings — temperature, vibration, pressure, etc.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| equipment_id | uuid FK | |
| reading_time | timestamptz | |
| metric | text | e.g., "temperature", "vibration_mm_s", "pressure_bar" |
| value | numeric | |
| unit | text | |
| quality | reading_quality enum | |
| is_demo | boolean | |

### equipment_status_history
Tracks equipment status transitions for uptime/availability calculations.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| equipment_id | uuid FK | |
| status | equipment_status enum | |
| start_time | timestamptz | |
| end_time | timestamptz | Nullable — null means ongoing |
| duration_hours | numeric | Computed |
| reason | text | |
| is_demo | boolean | |

---

## 5. Maintenance

Work orders, schedules, and corrective actions.

### maintenance_work_orders
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| work_order_number | text UNIQUE | |
| equipment_id | uuid FK | |
| type | maintenance_type enum | preventive, corrective, predictive, inspection |
| priority | priority_level enum | low, medium, high, critical |
| status | work_order_status enum | open, in_progress, completed, cancelled, overdue |
| assigned_to | uuid FK → employees | |
| description | text | |
| scheduled_date, completed_date | date | |
| downtime_hours | numeric | |
| cost | numeric | |
| is_demo | boolean | |

### maintenance_schedules
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| equipment_id | uuid FK | |
| type | maintenance_type enum | |
| frequency_days | integer | Days between scheduled maintenance |
| next_date | date | |
| is_active, is_demo | boolean | |

### corrective_actions
Actions taken to resolve maintenance issues or safety incidents.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| work_order_id | uuid FK | |
| incident_id | uuid FK → safety_incidents | |
| description | text | |
| completed_date | date | |
| is_demo | boolean | |

---

## 6. Quality Control

Standards, inspections, measurements, and defects — specific to metallurgy.

### quality_standards
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | Standard name |
| steel_grade | text | e.g., "Q235B" |
| parameter | text | e.g., "carbon_content", "yield_strength" |
| min_value, max_value | numeric | Acceptable range |
| unit | text | |
| is_active | boolean | |

### quality_inspections
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| inspection_number | text UNIQUE | |
| batch_id | uuid FK | |
| steel_grade | text | |
| inspector_id | uuid FK → employees | |
| inspection_date | date | |
| result | quality_result enum | pass, fail, conditional |
| notes | text | |
| is_demo | boolean | |

### quality_measurements
Individual parameter measurements within an inspection.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| inspection_id | uuid FK | |
| parameter | text | |
| value | numeric | Measured value |
| unit | text | |
| min_value, max_value | numeric | Spec range |
| result | quality_result enum | pass/fail/conditional for this measurement |
| is_demo | boolean | |

### quality_defects
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| inspection_id | uuid FK | |
| defect_type | text | e.g., "surface_crack", "inclusion", "dimension_deviation" |
| severity | defect_severity enum | minor, major, critical |
| description | text | |
| count | integer | Number of occurrences |
| is_demo | boolean | |

---

## 7. Safety

Incidents, inspections, and observations.

### safety_incidents
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| incident_number | text UNIQUE | |
| title | text | |
| description | text | |
| severity | incident_severity enum | minor, moderate, serious, critical |
| status | incident_status enum | reported, investigating, resolved, closed |
| department_id | uuid FK | |
| reported_by | uuid FK → employees | |
| incident_date | date | |
| resolution_date | date | |
| is_demo | boolean | |

### safety_inspections
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| inspection_number | text | |
| area | text | |
| inspector_id | uuid FK → employees | |
| inspection_date | date | |
| result | text | pass, fail, conditional |
| findings | text | |
| is_demo | boolean | |

### safety_observations
Proactive safety observations (near-misses, hazard reports).

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| observer_id | uuid FK → employees | |
| observation_date | date | |
| category | text | near_miss, hazard, unsafe_act, unsafe_condition |
| description | text | |
| action_taken | text | |
| is_demo | boolean | |

---

## 8. Warehouse

Categories, items, inventory movements, suppliers, purchase requests, and locations.

### warehouse_categories
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | e.g., "Spare Parts", "Raw Materials" |
| code | text UNIQUE | |
| description | text | |

### warehouse_items
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| item_code | text UNIQUE | |
| name | text | |
| category_id | uuid FK | |
| unit | text | pcs, kg, m, etc. |
| current_stock | numeric | Live stock level |
| min_stock, max_stock | numeric | Reorder thresholds |
| unit_cost | numeric | |
| is_demo | boolean | |

### inventory_movements
Tracks every stock change — incoming, outgoing, adjustments.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| item_id | uuid FK | |
| movement_type | movement_type enum | incoming, outgoing, adjustment |
| quantity | numeric | Positive for incoming, negative for outgoing |
| reference | text | PO number, work order, etc. |
| performed_by | uuid FK → employees | |
| is_demo | boolean | |

Movements are created via the `record_inventory_movement()` SECURITY DEFINER function, which atomically validates and updates `current_stock` — prevents negative stock via row-level locking.

### suppliers
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | |
| code | text UNIQUE | |
| contact_name, contact_phone, contact_email | text | |
| address | text | |
| is_active, is_demo | boolean | |

### purchase_requests
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| request_number | text UNIQUE | |
| item_id | uuid FK | |
| supplier_id | uuid FK | |
| quantity | numeric | |
| unit | text | |
| status | text | pending, approved, ordered, received, cancelled |
| requested_by | uuid FK → employees | |
| is_demo | boolean | |

### warehouse_locations
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| name | text | e.g., "A-1", "B-3" |
| code | text UNIQUE | |
| description | text | |
| is_active | boolean | |

### raw_material_consumption
Tracks raw material input to production.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| production_line_id | uuid FK | |
| material_type | text | iron_ore, scrap, coal, etc. |
| consumption_date | date | |
| quantity | numeric | |
| unit | text | |
| is_demo | boolean | |

---

## 9. Environmental

Environmental readings, emissions, waste, and targets — for regulatory compliance.

### environmental_readings
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| reading_type | environmental_reading_type enum | air_quality, water_quality, noise, dust |
| reading_time | timestamptz | |
| value | numeric | |
| unit | text | |
| department_id | uuid FK | |
| equipment_id | uuid FK | |
| quality | reading_quality enum | |
| is_demo | boolean | |

### emission_records
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| emission_type | emission_type enum | co2, sox, nox, pm |
| emission_date | date | |
| value | numeric | |
| unit | text | |
| source_type | emission_source enum | measured, estimated |
| department_id | uuid FK | |
| is_demo | boolean | |

### waste_records
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| waste_type | text | slag, dust, water_waste, oil_waste |
| waste_date | date | |
| quantity | numeric | |
| unit | text | |
| disposal_method | text | recycled, landfilled, treated, sold |
| department_id | uuid FK | |
| is_demo | boolean | |

### environmental_targets
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| target_type | text | emission, waste, consumption |
| target_date | date | |
| target_value | numeric | |
| unit | text | |
| is_demo | boolean | |

---

## 10. Workforce

Attendance, qualifications, and training records.

### attendance_records
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| employee_id | uuid FK | |
| record_date | date | |
| status | attendance_status enum | present, absent, late, leave |
| hours_worked | numeric | |
| is_demo | boolean | |

### qualifications
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| employee_id | uuid FK | |
| name | text | Certification/qualification name |
| issued_date | date | |
| expiry_date | date | |
| issuer | text | |
| is_demo | boolean | |

### training_records
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| employee_id | uuid FK | |
| course_name | text | |
| completion_date | date | |
| status | training_status enum | completed, in_progress, scheduled |
| is_demo | boolean | |

---

## 11. Notifications & Audit

User notifications, preferences, and audit logs.

### notifications
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid FK → auth.users | Owner |
| title | text | |
| message | text | |
| severity | notification_severity enum | info, warning, critical |
| category | text | production, maintenance, safety, etc. |
| is_read | boolean | |
| created_at | timestamptz | |

RLS: users can only see and manage their own notifications.

### notification_preferences
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid FK | |
| category | text | |
| severity | notification_severity enum | |
| enabled | boolean | |
| is_demo | boolean | |

### audit_logs
| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid | Who performed the action |
| action | text | create, update, delete, login, etc. |
| entity_type | text | Table name |
| entity_id | uuid | Row ID |
| old_values | jsonb | |
| new_values | jsonb | |
| ip_address | text | |
| created_at | timestamptz | |

RLS: only admin and plant_director can read audit logs.

---

## Enum Types

| Enum | Values |
|------|--------|
| user_role | admin, plant_director, manager, production_manager, engineer, energy_manager, maintenance_manager, safety_officer, warehouse_manager, operator, viewer |
| employee_status | active, on_leave, inactive |
| batch_status | planned, in_progress, completed, on_hold, cancelled |
| energy_type | electricity, natural_gas, water, steam, compressed_air |
| reading_quality | good, suspect, estimated, invalid |
| equipment_status | operational, under_maintenance, idle, fault, decommissioned |
| maintenance_type | preventive, corrective, predictive, inspection |
| priority_level | low, medium, high, critical |
| work_order_status | open, in_progress, completed, cancelled, overdue |
| movement_type | incoming, outgoing, adjustment |
| incident_severity | minor, moderate, serious, critical |
| incident_status | reported, investigating, resolved, closed |
| notification_severity | info, warning, critical |
| quality_result | pass, fail, conditional |
| defect_severity | minor, major, critical |
| environmental_reading_type | air_quality, water_quality, noise, dust |
| emission_type | co2, sox, nox, pm |
| emission_source | measured, estimated |
| attendance_status | present, absent, late, leave |
| training_status | completed, in_progress, scheduled |

## Database Functions

### set_updated_at()
Trigger function — automatically updates `updated_at` on row modification. Applied to every table with an `updated_at` column.

### handle_new_user()
Trigger function — creates a `profiles` row when a new `auth.users` row is inserted. Sets default role to `viewer`. Executable only by the database, not by anon/authenticated roles.

### record_inventory_movement()
`SECURITY DEFINER` function — atomically records an inventory movement and updates `current_stock` on the `warehouse_items` table. Prevents negative stock via row-level locking and validation. Callable by `authenticated` users (intentional privileged mutation pattern).

## Demo Data Strategy

All demo data rows have `is_demo = true`. This allows safe cleanup:

```sql
DELETE FROM production_records WHERE is_demo = true;
DELETE FROM energy_readings WHERE is_demo = true;
-- etc.
```

The demo seed (migrations 0004 and 0009) includes:
- 6 departments, 3 shifts, 8 employees
- 8 equipment units across 3 categories
- 6 energy meters (electricity, gas, water, steam, compressed air)
- 30 days of production records, energy readings, telemetry, environmental readings
- 12 maintenance work orders
- 5 safety incidents
- Quality inspections with measurements and defects
- Emission and waste records
- Suppliers, purchase requests, warehouse locations
