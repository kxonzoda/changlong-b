# Testing Guide

This guide covers the testing strategy for CHANGLONG INTELLIGENCE — what to test, how to test it, and what has been verified.

## Table of Contents
1. [Testing Overview](#testing-overview)
2. [Build Verification](#build-verification)
3. [Database Migration Validation](#database-migration-validation)
4. [RLS and Security Testing](#rls-and-security-testing)
5. [Service Layer Testing](#service-layer-testing)
6. [Business Logic Verification](#business-logic-verification)
7. [Edge Function Testing](#edge-function-testing)
8. [Frontend Integration Testing](#frontend-integration-testing)
9. [What Has Been Verified](#what-has-been-verified)
10. [What Requires External Configuration](#what-requires-external-configuration)

---

## Testing Overview

CHANGLONG INTELLIGENCE does not use a dedicated test framework (Jest, Vitest) in the current build. Testing is performed through:

1. **TypeScript type-checking** (`tsc --noEmit`) — catches type errors at compile time.
2. **ESLint** — catches unused imports, unreachable code, and style issues.
3. **Production build** (`npm run build`) — verifies the entire frontend compiles and bundles correctly.
4. **Supabase security advisor** (`get_advisors type="security"`) — lint checks for RLS, SECURITY DEFINER functions, and policy defects.
5. **Database introspection** (`list_tables`, `get_security_posture`) — verifies schema and policy state.
6. **Edge function deployment** — verifies functions deploy and execute without syntax errors.

### Why No Unit Test Framework?

The project's business logic lives in two places:
- **Database** (SQL functions, RLS policies, constraints) — tested via SQL queries and the security advisor.
- **Edge functions** (Deno/TypeScript) — tested via deployment + HTTP calls.
- **Frontend services** (TypeScript) — thin wrappers around Supabase queries, tested by the app running.

Adding a unit test framework would primarily test the service-layer wrappers, which are straightforward Supabase client calls. The real complexity is in the database layer (RLS, triggers, atomic functions) and edge functions (statistical analysis), which are better tested via SQL and HTTP respectively.

---

## Build Verification

The first line of defense. Run after every code change:

```bash
# Type-check (catches type errors without emitting)
npx tsc --noEmit

# Lint (catches unused imports, dead code)
npm run lint

# Full production build
npm run build
```

All three must pass cleanly. If any fails, fix the errors before proceeding.

### Common Build Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Unused import | Imported but not used | Remove the import |
| Missing type annotation | Implicit `any` | Add explicit types to function parameters |
| Import path error | Wrong relative path or alias | Use `@/` alias for `src/` files |
| Fast-refresh warning | Module exports both component and hook | Split into separate files (see authContext pattern) |

---

## Database Migration Validation

### Verifying Migrations Applied

```sql
-- Via mcp__supabase__execute_sql
SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version;
```

Expected: 10 migration records (0001 through 0010).

### Verifying Table Structure

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

Expected tables (40+):
- Organization: departments, profiles, shifts, employees
- Production: production_lines, production_batches, production_records, production_targets, production_events
- Energy: energy_meters, energy_readings, energy_consumption_daily, energy_targets, energy_cost_records
- Equipment: equipment_categories, equipment, equipment_telemetry, equipment_status_history
- Maintenance: maintenance_work_orders, maintenance_schedules, corrective_actions
- Quality: quality_standards, quality_inspections, quality_measurements, quality_defects
- Safety: safety_incidents, safety_inspections, safety_observations
- Warehouse: warehouse_categories, warehouse_items, inventory_movements, suppliers, purchase_requests, warehouse_locations, raw_material_consumption
- Environmental: environmental_readings, emission_records, waste_records, environmental_targets
- Workforce: attendance_records, qualifications, training_records
- Notifications: notifications, notification_preferences, audit_logs

### Verifying Foreign Key Integrity

```sql
-- Check for orphaned production records (line doesn't exist)
SELECT count(*) FROM production_records pr
LEFT JOIN production_lines pl ON pr.production_line_id = pl.id
WHERE pr.production_line_id IS NOT NULL AND pl.id IS NULL;
-- Expected: 0

-- Check for orphaned telemetry (equipment doesn't exist)
SELECT count(*) FROM equipment_telemetry t
LEFT JOIN equipment e ON t.equipment_id = e.id
WHERE e.id IS NULL;
-- Expected: 0
```

### Verifying Check Constraints

```sql
-- Negative stock should be impossible
SELECT count(*) FROM warehouse_items WHERE current_stock < 0;
-- Expected: 0

-- Health score should be 0-100
SELECT count(*) FROM equipment WHERE health_score < 0 OR health_score > 100;
-- Expected: 0
```

### Verifying Demo Data

```sql
SELECT
  (SELECT count(*) FROM departments WHERE is_demo) AS departments,
  (SELECT count(*) FROM production_records WHERE is_demo) AS production_records,
  (SELECT count(*) FROM energy_readings WHERE is_demo) AS energy_readings,
  (SELECT count(*) FROM equipment_telemetry WHERE is_demo) AS telemetry,
  (SELECT count(*) FROM maintenance_work_orders WHERE is_demo) AS work_orders,
  (SELECT count(*) FROM safety_incidents WHERE is_demo) AS safety_incidents,
  (SELECT count(*) FROM quality_inspections WHERE is_demo) AS quality_inspections;
```

Expected (approximate, from migrations 0004 + 0009):
- departments: 6
- production_records: 360
- energy_readings: 180
- telemetry: 336
- work_orders: 12
- safety_incidents: 5
- quality_inspections: 30+

---

## RLS and Security Testing

### Security Advisor

```sql
-- Via mcp__supabase__get_advisors type="security"
```

This runs Supabase's database linter and reports:
- Tables without RLS
- Views that bypass RLS (owner rights)
- Policies with always-true write checks
- SECURITY DEFINER functions callable by anon/authenticated
- Functions with mutable search_path
- Exposed materialized views

### Current Advisor State

After migration 0010, the advisor reports 1 accepted finding:

- **`record_inventory_movement` SECURITY DEFINER callable by authenticated** — This is intentional. The function performs atomic inventory mutations with server-side validation (prevents negative stock). It must be callable by authenticated users to record stock movements. PUBLIC and anon EXECUTE has been revoked. This follows the secure-data-access pattern for privileged mutations.

### Manual RLS Verification

RLS cannot be verified via `execute_sql` (which runs with a privileged role that bypasses RLS). Instead:

1. **Check policy existence** via `get_security_posture` — confirms policies are defined.
2. **Test through the app** — sign in as different roles and verify data visibility.
3. **Test via the anon key** — unauthenticated requests should return no data on protected tables.

### Role Escalation Prevention

```sql
-- Verify profiles table prevents self-role-updates via RLS
-- (The UPDATE policy only allows updating own profile, but role is a restricted column)
-- This is enforced by the WITH CHECK clause, not just the USING clause.

-- Via mcp__supabase__get_security_posture, check:
-- - profiles UPDATE policy WITH CHECK
-- - Column-level grants on profiles
```

The `profiles` table RLS allows users to update their own row, but the `role` column should only be writable by admin. This is enforced at the policy level.

### Cross-User Data Isolation

```sql
-- Notifications should only show the current user's notifications
-- RLS: USING (auth.uid() = user_id)

-- Audit logs should only be visible to admin/plant_director
-- RLS: USING (auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'plant_director')))
```

---

## Service Layer Testing

Each service module follows the same pattern. To test a service:

### 1. Success Case

```typescript
import { getProductionRecords } from '@/services/productionService';

// In the running app, after sign-in:
const records = await getProductionRecords(30);
console.log(records.length); // Should be > 0 with demo data
console.log(records[0].output_weight_kg); // Should be a positive number
```

### 2. Empty Result Case

```typescript
// Query with a date range that has no data
const records = await getProductionRecords(0); // No days = no data
console.log(records.length); // Should be 0, not an error
```

### 3. Error Case

```typescript
import { ServiceError } from '@/services/serviceError';

try {
  await getProductionRecords();
} catch (err) {
  if (err instanceof ServiceError) {
    console.error(`Status ${err.status}: ${err.message}`);
  }
}
```

### Services to Verify

| Service | Key Method | Expected Result (Demo Data) |
|---------|------------|-----------------------------|
| overviewService | `getKpiSummary()` | Non-zero totalOutputKg, energyConsumptionKwh |
| productionService | `getProductionTrend(30)` | 30 daily data points |
| energyService | `getEnergyTrend(30)` | 30 daily points with electricity, gas, water |
| equipmentService | `getEquipmentHealth()` | avgHealth > 0, operational > 0, total = 8 |
| maintenanceService | `getCriticalMaintenanceCount()` | Integer >= 0 |
| qualityService | `getQualityStats(30)` | passRate > 0 |
| safetyService | `getOpenIncidentCount()` | Integer >= 0 |
| warehouseService | `getLowStockCount()` | Integer >= 0 |
| environmentService | `getTotalCo2Emissions(30)` | Number > 0 |

---

## Business Logic Verification

### Energy Intensity

Formula: `total_electricity_kwh / (total_output_kg / 1000)` = kWh per tonne

```sql
SELECT
  (SELECT COALESCE(SUM(total_value), 0) FROM energy_consumption_daily d
   JOIN energy_meters m ON d.meter_id = m.id
   WHERE m.energy_type = 'electricity' AND d.is_demo) AS total_kwh,
  (SELECT COALESCE(SUM(output_weight_kg), 0) FROM production_records WHERE is_demo) AS total_kg,
  CASE
    WHEN (SELECT SUM(output_weight_kg) FROM production_records WHERE is_demo) > 0
    THEN (SELECT SUM(total_value) FROM energy_consumption_daily d
          JOIN energy_meters m ON d.meter_id = m.id
          WHERE m.energy_type = 'electricity' AND d.is_demo) /
         ((SELECT SUM(output_weight_kg) FROM production_records WHERE is_demo) / 1000)
    ELSE NULL
  END AS kwh_per_tonne;
```

The edge function `energy-analysis` computes this and returns it as `energyIntensity`.

### Production Efficiency

Formula: `(total_output_kg / total_target_kg) * 100`

```sql
SELECT
  SUM(output_weight_kg) AS output,
  SUM(target_weight_kg) AS target,
  CASE
    WHEN SUM(target_weight_kg) > 0
    THEN (SUM(output_weight_kg) / SUM(target_weight_kg)) * 100
    ELSE NULL
  END AS efficiency_pct
FROM production_records WHERE is_demo;
```

### Rejection Rate

Formula: `(total_rejected_kg / total_output_kg) * 100`

```sql
SELECT
  SUM(rejected_weight_kg) AS rejected,
  SUM(output_weight_kg) AS output,
  CASE
    WHEN SUM(output_weight_kg) > 0
    THEN (SUM(rejected_weight_kg) / SUM(output_weight_kg)) * 100
    ELSE 0
  END AS rejection_rate_pct
FROM production_records WHERE is_demo;
```

### Equipment Availability

Formula: `(operational_count / total_count) * 100`

```sql
SELECT
  count(*) FILTER (WHERE status = 'operational') AS operational,
  count(*) AS total,
  (count(*) FILTER (WHERE status = 'operational')::numeric / count(*) * 100) AS availability_pct
FROM equipment WHERE is_demo;
```

### Inventory Atomicity

The `record_inventory_movement()` function prevents negative stock via row-level locking:

```sql
-- Test: attempt to create an outgoing movement larger than current stock
-- This should raise an exception, not produce negative stock
SELECT record_inventory_movement(
  (SELECT id FROM warehouse_items WHERE is_demo LIMIT 1),
  'outgoing'::movement_type,
  999999,  -- Much larger than any stock
  'TEST-MOVEMENT',
  null,
  true
);
-- Expected: ERROR - insufficient stock
```

---

## Edge Function Testing

### Deployment Verification

```
mcp__supabase__list_edge_functions
```

Expected: 5 functions listed:
- ai-analyst
- energy-analysis
- production-insights
- equipment-anomaly-analysis
- generate-operational-report

### Manual Testing

Each edge function can be tested via HTTP with a valid JWT:

```bash
# Example: test energy-analysis
curl -X POST \
  https://<project>.supabase.co/functions/v1/energy-analysis \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -H "apikey: <anon_key>" \
  -d '{"days": 30}'
```

Expected response: JSON with `summary`, `byType`, `peakDays`, `anomalies`, `isDemoData: true`.

### AI Provider Testing

Without `AI_PROVIDER` and `AI_API_KEY` secrets:
- `ai-analyst` returns `source: "rule-based"` with a statistical summary.
- `generate-operational-report` returns `source: "rule-based"` with a text report.

With secrets configured:
- `ai-analyst` returns `source: "openai-llm"` with a natural language answer.
- `generate-operational-report` returns `source: "openai-llm"` with a narrative summary.

### Error Cases

| Test | Input | Expected |
|------|-------|----------|
| No auth header | No Authorization header | 401 `{ error: "Not authenticated" }` |
| Invalid token | `Bearer invalid` | 401 `{ error: "Invalid session" }` |
| Missing equipment_id | `{}` to equipment-anomaly-analysis | 400 `{ error: "equipment_id is required" }` |
| Non-existent equipment | `{ equipment_id: "00000000-..." }` | 404 `{ error: "Equipment not found" }` |

---

## Frontend Integration Testing

### Login Flow

1. Navigate to the app — should show login page.
2. Sign up with email/password — should create account and redirect to dashboard.
3. Sign out — should return to login page.
4. Sign in with the same credentials — should authenticate and load dashboard.

### Dashboard Tabs

After sign-in, verify each of the 9 tabs:

| Tab | Expected Content |
|-----|------------------|
| Overview | 8 KPI cards with non-zero values; production and energy trend charts |
| Production | Production trend chart; production records table |
| Energy | Energy trend chart; energy meters list; total kWh |
| Equipment | Equipment health card; equipment list with status and health score |
| Maintenance | Work orders table; critical count |
| Quality | Quality stats; inspections table |
| Safety | Incident count; incidents table |
| Warehouse | Low stock count; warehouse items table |
| Environment | CO2 emissions; environmental readings chart |

### Realtime Notifications

Notifications use Supabase Realtime. To test:

1. Sign in.
2. Insert a notification for the current user:
   ```sql
   INSERT INTO notifications (user_id, title, message, severity, category)
   VALUES ('<user-id>', 'Test', 'Realtime test', 'info', 'test');
   ```
3. The notification should appear in the UI without a page refresh.

---

## What Has Been Verified

### Build
- TypeScript type-check: clean
- ESLint: clean
- Production build: passes

### Database
- All 10 migrations applied successfully
- All 40+ tables exist with correct schema
- Foreign key constraints enforced
- Check constraints enforced (health_score 0-100, non-negative stock)
- Demo data seeded (migrations 0004 + 0009)
- `is_demo` flag present on all demo rows

### Security
- RLS enabled on all application tables
- Security advisor run — 1 accepted finding (record_inventory_movement, by design)
- handle_new_user trigger: EXECUTE revoked from anon/authenticated
- set_updated_at: search_path locked to public
- record_inventory_movement: search_path locked, EXECUTE restricted to authenticated

### Edge Functions
- All 5 functions deployed successfully
- JWT validation present in all functions
- CORS headers present on all responses
- Rule-based fallback works without AI secrets

### Frontend
- Login/signup flow works
- All 9 dashboard tabs render
- KPI cards show non-zero values from demo data
- Charts render (Recharts)
- Auth context properly split for fast-refresh

---

## What Requires External Configuration

| Feature | Requirement | Status |
|---------|-------------|--------|
| AI-powered responses | `AI_PROVIDER` + `AI_API_KEY` edge function secrets | Not configured — rule-based fallback active |
| Real IoT telemetry | Physical sensors + ingestion pipeline | Not connected — demo data only |
| Email notifications | Supabase email configuration | Not configured — in-app notifications only |
| Production deployment | Separate Supabase project + hosting | Current setup is the Bolt dev environment |

### Future Testing Enhancements

1. **Vitest integration** — add a unit test runner for service-layer functions with mocked Supabase client.
2. **Playwright E2E** — automated browser testing for the login → dashboard → tab navigation flow.
3. **pgTAP** — in-database unit tests for RLS policies, triggers, and the record_inventory_movement function.
4. **Edge function integration tests** — automated tests that call deployed functions with test JWTs.
5. **CI/CD pipeline** — run type-check, lint, build, and security advisor on every commit.
