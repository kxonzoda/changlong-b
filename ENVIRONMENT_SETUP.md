# Environment Setup

This guide covers all environment variables, local development setup, and configuration needed to run the CHANGLONG INTELLIGENCE platform.

## Prerequisites

- Node.js 18+ and npm
- A Supabase project (already provisioned for Bolt projects)

## Quick Start

The Supabase project is pre-provisioned and credentials are pre-populated in `.env`. No manual setup is required for the core database or auth.

```bash
# Install dependencies
npm install

# Start the dev server (runs automatically in Bolt)
npm run dev
```

## Environment Variables

### Frontend (`.env`)

These are pre-populated by Bolt and should not be modified:

| Variable | Description | Required |
|----------|-------------|----------|
| `VITE_SUPABASE_URL` | Supabase project URL | Yes (auto) |
| `VITE_SUPABASE_ANON_KEY` | Supabase anon public key | Yes (auto) |
| `SUPABASE_URL` | Same URL (used by edge functions) | Yes (auto) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (edge functions only) | Yes (auto) |
| `SUPABASE_DB_URL` | Direct Postgres connection string | Yes (auto) |

### Edge Function Secrets (Optional)

These are NOT pre-populated. They enable AI-powered features. Without them, the platform works in rule-based mode.

| Variable | Description | Required | How to Set |
|----------|-------------|----------|------------|
| `AI_PROVIDER` | AI provider name (`openai`) | No | Edge function secret |
| `AI_API_KEY` | API key for the AI provider | No | Edge function secret |

**Without AI keys:** All edge functions work in rule-based mode. The `ai-analyst` and `generate-operational-report` functions return statistical summaries instead of LLM-generated narratives. The `source` field in responses will be `"rule-based"`.

**With AI keys:** The `ai-analyst` returns natural language answers via GPT-4o-mini, and `generate-operational-report` produces a narrative executive summary. The `source` field will be `"openai-llm"`.

## Supabase Configuration

### supabase/config.toml

The project's Supabase configuration lives at `supabase/config.toml`. It defines the edge functions and their JWT verification settings:

```toml
[functions.ai-analyst]
verify_jwt = true
entrypoint = "./functions/ai-analyst/index.ts"

[functions.energy-analysis]
verify_jwt = true
entrypoint = "./functions/energy-analysis/index.ts"

[functions.production-insights]
verify_jwt = true
entrypoint = "./functions/production-insights/index.ts"

[functions.equipment-anomaly-analysis]
verify_jwt = true
entrypoint = "./functions/equipment-anomaly-analysis/index.ts"

[functions.generate-operational-report]
verify_jwt = true
entrypoint = "./functions/generate-operational-report/index.ts"
```

All functions have `verify_jwt = true` — they require a valid authenticated session to call. No public/webhook functions exist in this project.

## Project Structure

```
project/
├── .env                              # Environment variables (pre-populated)
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.js
├── supabase/
│   ├── config.toml                   # Edge function configuration
│   ├── functions/
│   │   ├── ai-analyst/index.ts
│   │   ├── energy-analysis/index.ts
│   │   ├── production-insights/index.ts
│   │   ├── equipment-anomaly-analysis/index.ts
│   │   └── generate-operational-report/index.ts
│   └── migrations/
│       ├── 0001_core_organization_and_rls.sql
│       ├── 0002_production_energy_equipment.sql
│       ├── 0003_maintenance_safety_warehouse.sql
│       ├── 0004_demo_seed_data.sql
│       ├── 0005_security_fixes.sql
│       ├── 0006_quality_control_domain.sql
│       ├── 0007_environmental_workforce_domains.sql
│       ├── 0008_supplementary_tables.sql
│       ├── 0009_demo_seed_extended.sql
│       └── 0010_revoke_inventory_movement_public_execute.sql
├── src/
│   ├── lib/supabase.ts               # Supabase client singleton
│   ├── types/database.ts             # All TypeScript interfaces
│   ├── services/                     # API service layer
│   ├── context/                       # React auth context
│   ├── components/                    # Reusable UI components
│   └── pages/                        # Login + Dashboard pages
└── *.md                              # Documentation files
```

## Database Migrations

Migrations are applied via the `mcp__supabase__apply_migration` MCP tool — not by writing SQL files to disk. The migration files in `supabase/migrations/` are a record of what was applied.

Migration order (sequential):

| # | Migration | Description |
|---|----------|-------------|
| 0001 | core_organization_and_rls | Departments, profiles, shifts, employees, user_role enum, trigger functions |
| 0002 | production_energy_equipment | Production lines, batches, records, energy meters/readings, equipment, telemetry |
| 0003 | maintenance_safety_warehouse | Work orders, schedules, warehouse, inventory movements, safety, notifications, audit |
| 0004 | demo_seed_data | 30 days of demo data (production, energy, telemetry, maintenance, safety) |
| 0005 | security_fixes | Locked search_path on functions, revoked EXECUTE from anon |
| 0006 | quality_control_domain | Quality standards, inspections, measurements, defects |
| 0007 | environmental_workforce_domains | Environmental readings, emissions, waste, attendance, qualifications, training |
| 0008 | supplementary_tables | Production events, equipment status history, safety inspections/observations, energy targets/costs, suppliers, purchase requests, warehouse locations, raw materials, notification preferences |
| 0009 | demo_seed_extended | Demo data for quality, environmental, workforce, suppliers, purchasing |
| 0010 | revoke_inventory_movement_public_execute | Restricted EXECUTE on inventory function to authenticated only |

See [MIGRATION_AND_DEPLOYMENT.md](MIGRATION_AND_DEPLOYMENT.md) for details on applying new migrations.

## Authentication

The platform uses Supabase email/password authentication. Email confirmation is OFF — users can sign in immediately after signup.

### Default Signup Role

New users are created with the `viewer` role by the `handle_new_user` trigger. Admins can upgrade roles via direct database access.

### Demo Accounts

The demo seed data includes employee records but NOT auth accounts. To test with different roles:

1. Sign up with any email/password — you'll get `viewer` role by default.
2. To test with elevated roles, manually update the profile:
   ```sql
   UPDATE profiles SET role = 'admin' WHERE email = 'your-email@example.com';
   ```

## Verification Checklist

After setup, verify everything works:

1. **Frontend loads** — the login page appears at the dev server URL.
2. **Signup works** — create an account; you're redirected to the dashboard.
3. **Dashboard shows data** — KPI cards display non-zero values (demo data is pre-seeded).
4. **All 9 tabs work** — click through Overview, Production, Energy, Equipment, Maintenance, Quality, Safety, Warehouse, Environment.
5. **Charts render** — Recharts visualizations display production and energy trends.
6. **Edge functions respond** — call any edge function from the dashboard or via fetch.

If any tab shows no data:
- Check that all 10 migrations have been applied (via `mcp__supabase__list_migrations`).
- Verify RLS policies are correct (via `mcp__supabase__get_security_posture`).
- Ensure the `is_demo` demo data was seeded (migrations 0004 and 0009).

## Troubleshooting

### "Permission denied for table X"
The table is missing a GRANT for the `authenticated` role. Check the migration that created the table.

### Empty table in the app but data exists in the database
RLS is blocking the read. The `anon`/`authenticated` role needs a SELECT policy. Use `mcp__supabase__get_security_posture` to check.

### Edge function returns 401
The JWT is invalid or expired. Ensure the frontend passes the current session's `access_token` in the Authorization header.

### Edge function returns no AI narrative
`AI_PROVIDER` and `AI_API_KEY` secrets are not configured. The function falls back to rule-based mode — this is expected behavior, not an error.
