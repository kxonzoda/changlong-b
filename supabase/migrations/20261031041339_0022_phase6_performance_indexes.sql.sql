/*
# Phase 6 — Performance Indexes

## Purpose

Add missing database indexes to improve query performance for:
1. Foreign key columns without indexes (39 total) — critical for JOIN performance
2. High-traffic status/date columns used in WHERE clauses and ORDER BY
3. Composite indexes for common query patterns

## Changes

### Foreign Key Indexes (39 indexes)
All unindexed FK columns get a B-tree index. These are essential for:
- JOIN performance when joining child to parent tables
- DELETE cascading (Postgres needs to scan child tables)
- Query filtering by FK columns

### Filter/Sort Indexes (key high-traffic columns)
- Status columns on work orders, production batches, incidents, corrective actions
- Date/time columns on time-series tables (energy_readings, equipment_telemetry, environmental_readings)
- Result column on quality_inspections
- Severity on environmental_alerts and safety_incidents

### Composite Indexes (5 indexes)
- equipment_telemetry(equipment_id, reading_time DESC) — most common telemetry query
- energy_readings(meter_id, reading_time DESC) — meter time-range queries
- production_records(batch_id, record_date DESC) — batch production history
- maintenance_work_orders(equipment_id, status) — equipment maintenance status
- audit_logs(user_id, created_at DESC) — user activity history

## Impact
- All indexes use IF NOT EXISTS for idempotency
- No data changes, no schema changes — pure performance improvement
- Safe to add at any time
*/

-- ============================================================
-- 1. Foreign Key Indexes (39 indexes)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_corrective_actions_assigned_to ON corrective_actions(assigned_to);
CREATE INDEX IF NOT EXISTS idx_emission_records_department_id ON emission_records(department_id);
CREATE INDEX IF NOT EXISTS idx_employee_shifts_shift_id ON employee_shifts(shift_id);
CREATE INDEX IF NOT EXISTS idx_employees_department_id ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_shift_id ON employees(shift_id);
CREATE INDEX IF NOT EXISTS idx_energy_cost_records_meter_id ON energy_cost_records(meter_id);
CREATE INDEX IF NOT EXISTS idx_environmental_alerts_department_id ON environmental_alerts(department_id);
CREATE INDEX IF NOT EXISTS idx_environmental_readings_department_id ON environmental_readings(department_id);
CREATE INDEX IF NOT EXISTS idx_environmental_readings_equipment_id ON environmental_readings(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_category_id ON equipment(category_id);
CREATE INDEX IF NOT EXISTS idx_equipment_production_line_id ON equipment(production_line_id);
CREATE INDEX IF NOT EXISTS idx_equipment_downtime_work_order_id ON equipment_downtime(work_order_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_performed_by ON inventory_movements(performed_by);
CREATE INDEX IF NOT EXISTS idx_maintenance_history_equipment_id ON maintenance_history(equipment_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_parts_warehouse_item_id ON maintenance_parts(warehouse_item_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_procedures_equipment_category_id ON maintenance_procedures(equipment_category_id);
CREATE INDEX IF NOT EXISTS idx_production_records_batch_id ON production_records(batch_id);
CREATE INDEX IF NOT EXISTS idx_production_records_operator_id ON production_records(operator_id);
CREATE INDEX IF NOT EXISTS idx_production_records_shift_id ON production_records(shift_id);
CREATE INDEX IF NOT EXISTS idx_production_shifts_operator_id ON production_shifts(operator_id);
CREATE INDEX IF NOT EXISTS idx_profiles_department_id ON profiles(department_id);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_requested_by ON purchase_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_supplier_id ON purchase_requests(supplier_id);
CREATE INDEX IF NOT EXISTS idx_qualifications_employee_id ON qualifications(employee_id);
CREATE INDEX IF NOT EXISTS idx_quality_batches_inspector_id ON quality_batches(inspector_id);
CREATE INDEX IF NOT EXISTS idx_quality_defects_inspection_id ON quality_defects(inspection_id);
CREATE INDEX IF NOT EXISTS idx_quality_inspections_inspector_id ON quality_inspections(inspector_id);
CREATE INDEX IF NOT EXISTS idx_risk_assessments_assessor_id ON risk_assessments(assessor_id);
CREATE INDEX IF NOT EXISTS idx_safety_incidents_reported_by ON safety_incidents(reported_by);
CREATE INDEX IF NOT EXISTS idx_safety_inspections_department_id ON safety_inspections(department_id);
CREATE INDEX IF NOT EXISTS idx_safety_inspections_inspector_id ON safety_inspections(inspector_id);
CREATE INDEX IF NOT EXISTS idx_safety_observations_department_id ON safety_observations(department_id);
CREATE INDEX IF NOT EXISTS idx_safety_observations_observer_id ON safety_observations(observer_id);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_from_location_id ON stock_transactions(from_location_id);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_performed_by ON stock_transactions(performed_by);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_to_location_id ON stock_transactions(to_location_id);
CREATE INDEX IF NOT EXISTS idx_waste_records_department_id ON waste_records(department_id);
CREATE INDEX IF NOT EXISTS idx_workforce_assignments_department_id ON workforce_assignments(department_id);
CREATE INDEX IF NOT EXISTS idx_workforce_assignments_production_line_id ON workforce_assignments(production_line_id);

-- ============================================================
-- 2. Status/Filter Indexes on High-Traffic Tables
-- ============================================================

-- Production
CREATE INDEX IF NOT EXISTS idx_production_batches_status ON production_batches(status);
CREATE INDEX IF NOT EXISTS idx_production_batches_production_line_id ON production_batches(production_line_id);
CREATE INDEX IF NOT EXISTS idx_production_records_record_date ON production_records(record_date);

-- Maintenance work orders
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_status ON maintenance_work_orders(status);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_priority ON maintenance_work_orders(priority);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_scheduled_date ON maintenance_work_orders(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_equipment_id ON maintenance_work_orders(equipment_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_assigned_to ON maintenance_work_orders(assigned_to);

-- Energy
CREATE INDEX IF NOT EXISTS idx_energy_readings_meter_id ON energy_readings(meter_id);

-- Equipment telemetry (time-series, high-volume)
CREATE INDEX IF NOT EXISTS idx_equipment_telemetry_equipment_id ON equipment_telemetry(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_status_history_equipment_id ON equipment_status_history(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_events_equipment_id ON equipment_events(equipment_id);

-- Quality
CREATE INDEX IF NOT EXISTS idx_quality_inspections_result ON quality_inspections(result);
CREATE INDEX IF NOT EXISTS idx_quality_inspections_batch_id ON quality_inspections(batch_id);

-- Safety
CREATE INDEX IF NOT EXISTS idx_safety_incidents_status ON safety_incidents(status);
CREATE INDEX IF NOT EXISTS idx_safety_incidents_severity ON safety_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_status ON corrective_actions(status);

-- Warehouse
CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON purchase_requests(status);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_item_id ON stock_transactions(item_id);

-- Environmental
CREATE INDEX IF NOT EXISTS idx_environmental_readings_reading_time ON environmental_readings(reading_time);
CREATE INDEX IF NOT EXISTS idx_environmental_alerts_severity ON environmental_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_emission_records_emission_date ON emission_records(emission_date);
CREATE INDEX IF NOT EXISTS idx_waste_records_waste_date ON waste_records(waste_date);

-- Audit logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_type_entity_id ON audit_logs(entity_type, entity_id);

-- ============================================================
-- 3. Composite Indexes for Common Query Patterns
-- ============================================================

-- Equipment telemetry: filter by equipment + time range (most common query)
CREATE INDEX IF NOT EXISTS idx_equipment_telemetry_equipment_id_reading_time
  ON equipment_telemetry(equipment_id, reading_time DESC);

-- Energy readings: filter by meter + time range
CREATE INDEX IF NOT EXISTS idx_energy_readings_meter_id_reading_time
  ON energy_readings(meter_id, reading_time DESC);

-- Production records: filter by batch + date
CREATE INDEX IF NOT EXISTS idx_production_records_batch_id_record_date
  ON production_records(batch_id, record_date DESC);

-- Maintenance work orders: filter by equipment + status
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_equipment_id_status
  ON maintenance_work_orders(equipment_id, status);

-- Audit logs: filter by user + time
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id_created_at
  ON audit_logs(user_id, created_at DESC);
