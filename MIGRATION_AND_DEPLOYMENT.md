# Migration and Deployment Guide

This guide covers the database migration workflow, edge function deployment, and the full deployment process for CHANGLONG INTELLIGENCE.

## Table of Contents
1. [Migration System](#migration-system)
2. [Migration Inventory](#migration-inventory)
3. [Applying Migrations](#applying-migrations)
4. [Writing New Migrations](#writing-new-migrations)
5. [Edge Function Deployment](#edge-function-deployment)
6. [Frontend Build](#frontend-build)
7. [Environment Separation](#environment-separation)
8. [Demo Data Cleanup](#demo-data-cleanup)
9. [Rollback Considerations](#rollback-considerations)

---

## Migration System

All database schema changes are applied via the `mcp__supabase__apply_migration` MCP tool. This tool:

1. Wraps the SQL in a transaction.
2. Statically validates PL/pgSQL functions with `plpgsql_check` before committing.
3. Records the migration in the `supabase_migrations.schema_migrations` table.
4. Returns success/failure with the full error message on failure.

**Never** use the Supabase CLI (`npx supabase migration`, `supabase db`) — it is not supported in this environment. **Never** run raw DDL via `execute_sql` — use `apply_migration` for all schema changes.

### Key Rules

- Migrations must be **idempotent** (safe to re-run) because a timeout does not mean the SQL didn't commit — the response may simply have been lost. Use `IF NOT EXISTS`, `DROP POLICY IF EXISTS` before `CREATE POLICY`, etc.
- **No transaction control statements** (`BEGIN`, `COMMIT`, `ROLLBACK`) — `apply_migration` wraps the migration in a transaction already. `DO $$ ... END $$` blocks are allowed.
- **Never** `DROP` columns, change column types, or rename tables — these lose user data. Additive changes only (`ADD COLUMN`, `CREATE TABLE IF NOT EXISTS`, new policies, new indexes).
- Each migration starts with a detailed markdown comment block explaining all changes.
- If a migration appears to fail, **fix and re-apply with the same filename** — do not rename it with `_retry`, which creates duplicate migration records.

---

## Migration Inventory

All 10 migrations are applied and verified:

| # | Filename | Date | Description |
|---|----------|------|-------------|
| 0001 | `20261030161355_0001_core_organization_and_rls.sql` | 2026-10-30 | Core organization: departments, profiles (auto-created via trigger), shifts, employees, user_role enum, set_updated_at trigger |
| 0002 | `20261030161442_0002_production_energy_equipment.sql` | 2026-10-30 | Production lines, batches, records, targets; energy meters, readings, daily consumption; equipment categories, equipment, telemetry |
| 0003 | `20261030161530_0003_maintenance_safety_warehouse.sql` | 2026-10-30 | Maintenance work orders, schedules; warehouse categories, items, inventory_movements + record_inventory_movement() SECURITY DEFINER function; safety incidents; notifications; audit_logs |
| 0004 | `20261030161815_0004_demo_seed_data.sql` | 2026-10-30 | 30 days of demo data: 6 departments, 3 shifts, 8 equipment, 6 energy meters, 360 production records, 180 energy readings, 336 telemetry points, 12 work orders, 5 safety incidents, 10 warehouse items |
| 0005 | `20261030162404_0005_security_fixes.sql` | 2026-10-30 | Fixed set_updated_at and handle_new_user search_path (locked to public), revoked EXECUTE on handle_new_user from anon/authenticated |
| 0006 | `20261030164240_0006_quality_control_domain.sql` | 2026-10-30 | Quality standards, inspections, measurements, defects |
| 0007 | `20261030164314_0007_environmental_workforce_domains.sql` | 2026-10-30 | Environmental readings, emission records, waste records, environmental targets; attendance records, qualifications, training records |
| 0008 | `20261030164407_0008_supplementary_tables.sql` | 2026-10-30 | Production events, equipment status history, safety inspections, safety observations, corrective actions, energy targets, energy cost records, suppliers, purchase requests, warehouse locations, raw material consumption, notification preferences |
| 0009 | `20261030164508_0009_demo_seed_extended.sql` | 2026-10-30 | Demo data for quality, environmental, workforce, suppliers, purchasing, energy targets/costs |
| 0010 | `20261030165050_0010_revoke_inventory_movement_public_execute.sql` | 2026-10-30 | Restricted EXECUTE on record_inventory_movement to authenticated only (revoked from PUBLIC, anon) |

### Migration Timeline

```
0001 ──► 0002 ──► 0003 ──► 0004 (demo seed)
                                    │
0005 (security fixes) ◄────────────┘
                                    │
0006 ──► 0007 ──► 0008 ──► 0009 (extended demo seed)
                                    │
0010 (security fix) ◄───────────────┘
```

---

## Applying Migrations

To apply a new migration:

1. Write the SQL with a detailed markdown comment header.
2. Call `mcp__supabase__apply_migration` with `filename` (snake_case) and `content` (the SQL).
3. The tool commits the transaction and records the migration.
4. On timeout: the SQL likely committed but the response was lost. Re-apply with the SAME filename — idempotent SQL will no-op.

### Verification

After applying migrations, verify:

```sql
-- List all migrations
SELECT * FROM supabase_migrations.schema_migrations ORDER BY version;

-- Check table count
SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';

-- Run security advisor
-- Via: mcp__supabase__get_advisors type="security"
```

---

## Writing New Migrations

### Template

```sql
/*
# <Descriptive Title>

1. New Tables
- `table_name` — description
  - `column_name` (type, constraints) — description
2. Modified Tables
- `existing_table`: added column `new_col` (type) — description
3. Security
- Enabled RLS on `table_name`.
- Granted SELECT to `authenticated`.
- Policies: select_own, insert_own, update_own, delete_own (scoped to auth.uid()).
4. Indexes
- Added index on `table_name(column)` for query performance.
5. Notes
- <Any important context for future maintainers>
*/

-- Table creation
CREATE TABLE IF NOT EXISTS table_name (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON table_name TO authenticated;

DROP POLICY IF EXISTS "select_own_table_name" ON table_name;
CREATE POLICY "select_own_table_name" ON table_name FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_table_name" ON table_name;
CREATE POLICY "insert_own_table_name" ON table_name FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_table_name" ON table_name;
CREATE POLICY "update_own_table_name" ON table_name FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_table_name" ON table_name;
CREATE POLICY "delete_own_table_name" ON table_name FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- Index
CREATE INDEX IF NOT EXISTS idx_table_name_user_id ON table_name(user_id);

-- Updated_at trigger
CREATE TRIGGER set_updated_at_table_name
  BEFORE UPDATE ON table_name
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

### Naming Convention

```
<YYYYMMDDHHMMSS>_<number>_<snake_case_description>.sql
```

Example: `20261030170000_0011_add_equipment_components.sql`

The number must be sequential and unique. Use the current UTC timestamp for the prefix.

---

## Edge Function Deployment

Edge functions are deployed via the `mcp__supabase__deploy_edge_functions` MCP tool. This tool:

1. Reads source files from `supabase/functions/<slug>/index.ts` on disk.
2. Auto-detects which functions changed since the last deploy (tracked in `supabase/functions-deploy-state.json`).
3. Deploys all changed functions in a single call.
4. You do NOT pass a slug — the tool detects changes automatically.

### Pre-Deployment Checklist

Before calling `deploy_edge_functions`:

1. **Write the source file** to `supabase/functions/<slug>/index.ts`.
2. **Add a config table** in `supabase/config.toml`:
   ```toml
   [functions.<slug>]
   verify_jwt = true
   entrypoint = "./functions/<slug>/index.ts"
   ```
3. **Check existing functions** via `mcp__supabase__list_edge_functions` to see what's already deployed.
4. For existing functions, read the current code from `supabase/functions/<slug>/index.ts` before updating.

### Deployment Process

```
1. Write/update supabase/functions/<slug>/index.ts
2. Add [functions.<slug>] table to supabase/config.toml
3. Call mcp__supabase__deploy_edge_functions
4. Tool deploys all changed functions in one call
5. Verify via mcp__supabase__list_edge_functions
```

### Currently Deployed Functions

| Function | JWT | Status |
|----------|-----|--------|
| `ai-analyst` | Required | Deployed |
| `energy-analysis` | Required | Deployed |
| `production-insights` | Required | Deployed |
| `equipment-anomaly-analysis` | Required | Deployed |
| `generate-operational-report` | Required | Deployed |

### Edge Function Secrets

To check what secrets are configured:

```
mcp__supabase__list_edge_function_secrets
```

Currently needed secrets:
- `AI_PROVIDER` (optional) — enables AI-powered responses
- `AI_API_KEY` (optional) — API key for the AI provider

Without these, all functions work in rule-based mode. See [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md) for details.

### Deleting Edge Functions

Use `mcp__supabase__delete_edge_function` with the project ID and slug. This removes the deployed function AND the local `supabase/functions/<slug>/` directory. Only call this when the function should be permanently removed — never to force a clean redeploy.

---

## Frontend Build

The frontend is a Vite + React 18 + TypeScript application.

```bash
# Install dependencies
npm install

# Build for production
npm run build

# Type-check
npx tsc --noEmit

# Lint
npm run lint
```

The build output goes to `dist/`. In the Bolt environment, the dev server runs automatically — do not invoke `npm run dev` manually.

### Build Verification

After making changes, always run the build before reporting completion:

```bash
npm run build
```

If the build fails, fix the errors before reporting the task as complete. Common issues:
- Unused imports (ESLint will flag these)
- Missing type annotations
- Import path errors (use `@/` alias for `src/`)

---

## Environment Separation

### Bolt Environment (Development)

- Supabase project is pre-provisioned with credentials in `.env`.
- All 10 migrations are applied.
- Demo data (`is_demo = true`) is seeded across all tables.
- Edge functions are deployed.
- AI secrets are NOT configured — functions run in rule-based mode.

### Production Deployment

For production deployment outside Bolt:

1. Create a new Supabase project.
2. Apply all 10 migrations in order via `apply_migration` or the Supabase SQL editor.
3. Configure edge function secrets (`AI_PROVIDER`, `AI_API_KEY`) if AI features are desired.
4. Set frontend environment variables (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`).
5. Build the frontend: `npm run build`.
6. Deploy the `dist/` folder to your hosting provider.
7. Do NOT run the demo seed migrations (0004, 0009) against production — they insert simulated data.

### Demo Data Identification

All demo records have `is_demo = true`. This flag is present on every table that contains demo data. To identify demo data:

```sql
SELECT count(*) FROM production_records WHERE is_demo = true;
SELECT count(*) FROM equipment WHERE is_demo = true;
-- etc.
```

---

## Demo Data Cleanup

To remove all demo data from a database (safe for production):

```sql
-- Delete in reverse dependency order to avoid FK violations
DELETE FROM inventory_movements WHERE is_demo = true;
DELETE FROM quality_measurements WHERE is_demo = true;
DELETE FROM quality_defects WHERE is_demo = true;
DELETE FROM quality_inspections WHERE is_demo = true;
DELETE FROM equipment_telemetry WHERE is_demo = true;
DELETE FROM equipment_status_history WHERE is_demo = true;
DELETE FROM production_events WHERE is_demo = true;
DELETE FROM production_records WHERE is_demo = true;
DELETE FROM production_batches WHERE is_demo = true;
DELETE FROM energy_readings WHERE is_demo = true;
DELETE FROM energy_consumption_daily WHERE is_demo = true;
DELETE FROM environmental_readings WHERE is_demo = true;
DELETE FROM emission_records WHERE is_demo = true;
DELETE FROM waste_records WHERE is_demo = true;
DELETE FROM attendance_records WHERE is_demo = true;
DELETE FROM training_records WHERE is_demo = true;
DELETE FROM maintenance_work_orders WHERE is_demo = true;
DELETE FROM safety_incidents WHERE is_demo = true;
DELETE FROM safety_inspections WHERE is_demo = true;
DELETE FROM safety_observations WHERE is_demo = true;
DELETE FROM corrective_actions WHERE is_demo = true;
DELETE FROM purchase_requests WHERE is_demo = true;
DELETE FROM warehouse_items WHERE is_demo = true;
DELETE FROM equipment WHERE is_demo = true;
DELETE FROM energy_meters WHERE is_demo = true;
DELETE FROM production_lines WHERE is_demo = true;
DELETE FROM employees WHERE is_demo = true;
DELETE FROM shifts WHERE is_demo = true;
DELETE FROM departments WHERE is_demo = true;
DELETE FROM suppliers WHERE is_demo = true;
```

**Never** delete rows where `is_demo = false` — those are real production data. Always include the `WHERE is_demo = true` clause.

---

## Rollback Considerations

PostgreSQL migrations are **forward-only** in this project. There is no automated rollback system. This is by design:

1. **Data safety** — rolling back a migration (dropping a table, removing a column) can destroy user data.
2. **Additive changes** — all migrations add new tables, columns, or policies. They do not modify existing structures destructively.
3. **Idempotent re-application** — if a migration fails, fix the SQL and re-apply with the same filename.

### If a Migration Goes Wrong

1. **Timeout** — the SQL likely committed. Re-apply with the same filename; idempotent SQL will no-op on what already exists.
2. **Syntax error** — the migration was rolled back by the transaction. Fix the SQL and re-apply.
3. **Wrong data inserted** — use `execute_sql` with a targeted `DELETE` to remove the bad rows. Do not drop the table.
4. **Bad policy** — `DROP POLICY IF EXISTS` and re-create. Policies support `IF EXISTS` on drop.

### What NOT to Do

- Never `DROP TABLE` to "start over" — this loses all data.
- Never `DROP COLUMN` — use a follow-up migration to mark it unused instead.
- Never `ALTER COLUMN TYPE` — this can silently corrupt data. Add a new column and migrate data instead.
- Never rename tables or columns — add a view with the new name instead.
