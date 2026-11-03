# Backend Architecture — CHANGLONG INTELLIGENCE

## Overview

CHANGLONG INTELLIGENCE is an industrial intelligence and digital operations platform for a metallurgical and steel manufacturing plant. The backend is built entirely on Supabase (PostgreSQL, Auth, Row Level Security, Edge Functions, and Realtime) with a TypeScript/React frontend.

## Architecture

```
Frontend (React + TypeScript + Vite)
  |
  ├── Supabase Client (anon key only, authenticated sessions)
  ├── Service Layer (src/services/) — typed data access
  ├── Auth Context (session + profile + role)
  |
  └── Supabase Backend
        ├── PostgreSQL (normalized schema, RLS, triggers, functions)
        ├── Auth (email/password, profile auto-creation)
        ├── Edge Functions (ai-analyst, energy-analysis, production-insights,
        │                 equipment-anomaly-analysis, generate-operational-report,
        │                 iot-ingestion)
        └── Realtime (notifications)
```

## Database Migrations (ordered)

| # | Migration | Description |
|---|-----------|-------------|
| 0001 | Core Organization & RLS | departments, profiles, shifts, employees, role enum, auto-profile trigger |
| 0002 | Production, Energy, Equipment | production_lines, batches, records, targets, energy_meters, readings, equipment, telemetry |
| 0003 | Maintenance, Safety, Warehouse | work orders, schedules, warehouse items, inventory movements (atomic), safety incidents, notifications, audit logs |
| 0004 | Demo Seed Data | Realistic 30-day demo data for a steel plant (all marked is_demo=true) |
| 0005 | Security Fixes | Function search_path locks, EXECUTE permission revocations |
| 0006 | Quality Control Domain | quality_standards, quality_inspections, quality_measurements, quality_defects |
| 0007 | Environmental & Workforce | environmental_readings, emission_records, waste_records, environmental_targets; attendance_records, qualifications, training_records |
| 0008 | Supplementary Tables | production_events, equipment_status_history, safety_inspections/observations, corrective_actions, energy_targets/cost_records, suppliers, purchase_requests, warehouse_locations, raw_material_consumption, notification_preferences |
| 0009 | Extended Demo Seed | Demo data for quality, environmental, workforce, suppliers, purchasing, energy targets/costs |
| 0010 | Security Fix | Restricted EXECUTE on record_inventory_movement to authenticated only |
| 0011 | Extended Tables & Analytics | equipment_components, maintenance_procedures/parts, risk_assessments, safety_training_records, water_usage_records, system_events, energy_anomalies; MTBF/MTTR functions; audit trigger function |
| 0012 | RLS Fix for New Tables | SELECT policies on 5 tables lacking them; revoked audit_trigger_fn EXECUTE from PUBLIC/anon/authenticated |
| 0013 | Demo Seed for Extended Tables | 8 components, 5 procedures, 6 parts, 4 risk assessments, 6 training records, 30 days water usage, 5 system events, 4 energy anomalies |
| 0014 | Final Spec Completion Tables | equipment_events, equipment_operating_hours, maintenance_history, quality_parameters, quality_batches, laboratory_results, stock_transactions, workforce_assignments, employee_shifts, environmental_alerts, energy_sources, production_shifts |
| 0015 | Demo Seed for Final Tables | 4 energy sources, 6 quality parameters, 5 batch qualities, 6 lab results, 9 shift summaries, 6 equipment events, 56 operating hours records, 3 maintenance histories, 6 stock transactions, 3 environmental alerts, 6 workforce assignments, 6 employee shifts |
| 0016 | RLS Fix + Equipment Downtime | SELECT policies for 10 previously-locked tables from 0014; equipment_downtime table; maintenance completion rate function; demo downtime seed |

## Security Model

- **RLS enabled on every table** — no exceptions.
- **Roles**: admin, plant_director, manager, production_manager, engineer, energy_manager, maintenance_manager, safety_officer, warehouse_manager, operator, viewer.
- **Users cannot modify their own role** — role is set in `profiles` via admin/service_role only.
- **Profiles auto-created** on signup via `handle_new_user()` trigger (SECURITY DEFINER, EXECUTE revoked from anon/authenticated).
- **Safety incidents** restricted to admins, plant_directors, managers, safety_officers.
- **Employee records** restricted to admins, plant_directors, managers.
- **Audit logs** read-only for admins and plant_directors.
- **Notifications** owner-scoped via `auth.uid() = user_id`.
- **SECURITY DEFINER functions** have locked `search_path = public` and explicit EXECUTE grants.

## Edge Functions

| Function | Purpose | Auth |
|----------|---------|------|
| `ai-analyst` | Natural-language operational Q&A with provider abstraction | JWT required |
| `energy-analysis` | Energy intensity, CO2 estimates, peak/anomaly detection | JWT required |
| `production-insights` | Shift performance, target achievement, rejection analysis | JWT required |
| `equipment-anomaly-analysis` | Z-score anomaly detection, risk assessment, recommendations | JWT required |
| `generate-operational-report` | Comprehensive operational report with optional AI narrative | JWT required |
| `iot-ingestion` | Industrial IoT telemetry & energy reading ingestion with validation | JWT required |

All edge functions use service_role internally, validate the user's JWT, and include mandatory CORS headers. AI-capable functions gracefully degrade to rule-based statistical summaries when no AI provider is configured. The `iot-ingestion` function validates device IDs, timestamps, and metric allowlists before writing to the database. See [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md) and [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for details.

## Demo Data

All demo records have `is_demo = true`. The seeds (migrations 0004 + 0009 + 0013 + 0015) create:
- 6 departments, 3 shifts, 4 production lines, 8 equipment units, 6 energy meters
- 8 employees across departments and shifts
- 30 days of production batches & records (360 records)
- 30 days of energy readings (180 readings + 180 daily aggregations)
- 7 days of hourly equipment telemetry (336 readings)
- 12 maintenance work orders, 5 safety incidents, 10 warehouse items
- Quality inspections with measurements and defects
- 30 days of environmental readings, emission records, waste records
- 8 equipment components, 5 maintenance procedures, 6 maintenance parts, 3 maintenance histories
- 4 risk assessments, 6 safety training records
- 30 days of water usage records
- 5 system events, 4 energy anomalies
- 4 energy sources, 6 quality parameters, 5 quality batches, 6 laboratory results
- 9 production shift summaries (3 lines x 3 shifts)
- 6 equipment events, 56 equipment operating hours records (8 equipment x 7 days)
- 6 stock transactions, 3 environmental alerts
- 6 workforce assignments, 6 employee shifts
- Attendance, qualifications, training records
- Suppliers, purchase requests, warehouse locations
- Energy targets and cost records
- 5 demo notifications for the first user

Demo data is idempotent — re-running the seed cleans and re-inserts safely.

## Database Domains (11)

1. **Organization** — departments, profiles, shifts, employees
2. **Production** — production_lines, batches, records, shifts, targets, events, raw_material_consumption
3. **Energy** — energy_meters, readings, sources, daily consumption, targets, anomalies, costs
4. **Equipment** — categories, equipment, components, telemetry, status history, operating hours, events
5. **Maintenance** — work orders, schedules, procedures, parts, history, corrective actions, equipment downtime
6. **Quality Control** — standards, inspections, measurements, parameters, defects, batches, laboratory results
7. **Safety** — incidents, inspections, observations, corrective actions, risk assessments, training records
8. **Warehouse** — categories, items, locations, movements, stock transactions, suppliers, purchase requests, raw materials
9. **Environmental** — readings, emissions, water usage, waste, targets, alerts
10. **Workforce** — employees, workforce assignments, employee shifts, attendance, qualifications, training
11. **Notifications & Audit** — notifications, preferences, audit logs, system events

## Database Functions

- `set_updated_at()` — trigger function for updated_at on all tables
- `handle_new_user()` — auto-creates profile on signup (SECURITY DEFINER, EXECUTE revoked)
- `record_inventory_movement()` — atomic inventory mutation, prevents negative stock (SECURITY DEFINER)
- `get_equipment_mtbf(p_equipment_id, p_days)` — Mean Time Between Failures calculation
- `get_equipment_mttr(p_equipment_id, p_days)` — Mean Time To Repair calculation
- `get_maintenance_completion_rate(p_days)` — Completion rate, overdue count for work orders in date range (SECURITY DEFINER)
- `log_audit_event(p_user_id, p_action, p_entity_type, p_entity_id, p_details)` — insert audit log entry (SECURITY DEFINER)
- `audit_trigger_fn()` — generic audit trigger for UPDATE/DELETE on critical tables (not callable via RPC)
- Audit triggers active on: safety_incidents, maintenance_work_orders, warehouse_items
